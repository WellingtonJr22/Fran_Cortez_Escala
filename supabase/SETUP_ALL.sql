-- Execute no SQL Editor de um projeto Supabase novo.
begin;
create table public.admins (user_id uuid primary key references auth.users(id), role text not null check(role in ('admin','super_admin')));
create function public.is_admin() returns boolean language sql stable security definer set search_path = '' as $$ select exists(select 1 from public.admins where user_id=auth.uid() and role in ('admin','super_admin')); $$;
create table public.groups (id uuid primary key default gen_random_uuid(), name text not null, color text not null default '#e8e4da' check(color ~ '^#[0-9a-fA-F]{6}$'));
create table public.employees (id uuid primary key default gen_random_uuid(), name text not null check(length(trim(name))>0), role text not null default '', group_id uuid references public.groups, active boolean not null default true);
create table public.memberships (id uuid primary key default gen_random_uuid(), employee_id uuid not null references public.employees, group_id uuid references public.groups, effective_from date not null, unique(employee_id,effective_from));
create table public.rules (id uuid primary key default gen_random_uuid(), employee_id uuid references public.employees, group_id uuid references public.groups, kind text not null check(kind in ('fixed','alternating')), weekdays integer[] not null, anchor_date date not null, effective_from date not null, check((employee_id is null) <> (group_id is null)), check(cardinality(weekdays)>0 and weekdays <@ array[1,2,3,4,5,6]));
create unique index rules_employee_date on public.rules(employee_id,effective_from) where employee_id is not null;
create unique index rules_group_date on public.rules(group_id,effective_from) where group_id is not null;
create table public.exceptions (id uuid primary key default gen_random_uuid(), employee_id uuid not null references public.employees, date date not null, status text not null check(status in ('T','F','pending')), reason text not null check(length(trim(reason))>0), unique(employee_id,date));
create table public.schedules (id uuid primary key default gen_random_uuid(), month date not null unique check(extract(day from month)=1), status text not null check(status in ('draft','confirmed')), mode text not null check(mode in ('manual','automatic')), rows jsonb not null, version integer not null default 1, needs_review boolean not null default false, updated_at timestamptz not null default now(), updated_by uuid not null references auth.users);
create table public.audit_log (id bigint generated always as identity primary key, table_name text not null, record_id text not null, operation text not null, actor uuid references auth.users, occurred_at timestamptz not null default now(), old_values jsonb, new_values jsonb);
create function public.record_audit() returns trigger language plpgsql security definer set search_path='' as $$
begin
 insert into public.audit_log(table_name,record_id,operation,actor,old_values,new_values) values(tg_table_name,coalesce(to_jsonb(new)->>'id',to_jsonb(old)->>'id',to_jsonb(new)->>'user_id',to_jsonb(old)->>'user_id'),tg_op,auth.uid(),case when tg_op<>'INSERT' then to_jsonb(old) end,case when tg_op<>'DELETE' then to_jsonb(new) end);
 return coalesce(new,old);
end; $$;
do $$ declare t text; begin
 foreach t in array array['admins','groups','employees','memberships','rules','exceptions','schedules'] loop
 execute format('create trigger audit_change after insert or update or delete on public.%I for each row execute function public.record_audit()',t);
 end loop;
 foreach t in array array['admins','groups','employees','memberships','rules','exceptions','schedules','audit_log'] loop
 execute format('alter table public.%I enable row level security',t);
 execute format('create policy admin_read on public.%I for select to authenticated using(public.is_admin())',t);
 execute format('revoke all on public.%I from anon, authenticated',t);
 execute format('grant select on public.%I to authenticated',t);
 end loop;
end $$;
-- Only controlled RPCs may write. Authenticated users cannot self-promote or edit audit.
create function public.require_admin() returns void language plpgsql security definer set search_path='' as $$ begin if not public.is_admin() then raise exception 'Acesso restrito a administradores'; end if; end $$;
create function public.mark_review(p_from date) returns void language sql security definer set search_path='' as $$ update public.schedules set needs_review=true,version=version+1,updated_at=now(),updated_by=auth.uid() where status='confirmed' and month >= date_trunc('month',p_from)::date; $$;
create function public.save_schedule(p_month date,p_status text,p_mode text,p_rows jsonb,p_expected_version integer,p_replace boolean default false,p_ack_conflicts boolean default false) returns public.schedules language plpgsql security definer set search_path='' as $$
declare existing public.schedules; saved public.schedules; r jsonb; kv record; d date; seen text[] := '{}'; days integer; pending_count integer:=0; sunday_count integer:=0;
begin
 perform public.require_admin();
 if extract(day from p_month)<>1 or p_status not in ('draft','confirmed') or p_mode not in ('manual','automatic') then raise exception 'Dados de escala invalidos'; end if;
 perform pg_advisory_xact_lock(hashtext('schedule:'||p_month::text));
 select * into existing from public.schedules where month=p_month for update;
 if existing.id is not null and (p_expected_version is distinct from existing.version) then raise exception 'A escala mudou. Recarregue antes de salvar.'; end if;
 if existing.id is null and p_expected_version<>0 then raise exception 'Versao invalida'; end if;
 if existing.status='confirmed' and not p_replace then raise exception 'Substituicao de escala confirmada exige confirmacao explicita'; end if;
 if jsonb_typeof(p_rows)<>'array' then raise exception 'Tabela invalida'; end if;
 days := extract(day from (p_month+interval '1 month - 1 day'));
 for r in select value from jsonb_array_elements(p_rows) loop
  if r->>'id'=any(seen) then raise exception 'Profissional duplicado'; end if;
  seen:=array_append(seen,r->>'id');
  if not exists(select 1 from public.employees where id=(r->>'id')::uuid) or coalesce(length(r->>'name'),0)=0 or r->>'group' is null or coalesce(r->>'color','') !~ '^#[0-9a-fA-F]{6}$' or jsonb_typeof(r->'cells') is distinct from 'object' then raise exception 'Profissional ou celulas invalidas'; end if;
  if (select count(*) from jsonb_object_keys(r->'cells'))<>days then raise exception 'Todas as datas do mes devem estar presentes'; end if;
  for kv in select * from jsonb_each_text(r->'cells') loop
   d:=kv.key::date;
   if to_char(d,'YYYY-MM-DD')<>kv.key or date_trunc('month',d)::date<>p_month or kv.value not in ('T','F','pending') or kv.value is null then raise exception 'Data ou indicador invalido'; end if;
   if kv.value='pending' then pending_count:=pending_count+1; end if;
   if kv.value='T' and extract(dow from d)=0 then sunday_count:=sunday_count+1; end if;
  end loop;
 end loop;
 if p_status='confirmed' and (cardinality(seen)=0 or pending_count>0) then raise exception 'Resolva os dias a confirmar antes de confirmar a escala'; end if;
 if p_status='confirmed' and sunday_count>0 and not p_ack_conflicts then raise exception 'Confirme explicitamente o trabalho aos domingos'; end if;
 insert into public.schedules(month,status,mode,rows,updated_by) values(p_month,p_status,p_mode,p_rows,auth.uid()) on conflict(month) do update set status=excluded.status,mode=excluded.mode,rows=excluded.rows,version=public.schedules.version+1,needs_review=false,updated_at=now(),updated_by=auth.uid() returning * into saved;
 return saved;
end; $$;
create function public.save_group(p_name text,p_color text) returns uuid language plpgsql security definer set search_path='' as $$ declare result uuid; begin perform public.require_admin(); insert into public.groups(name,color) values(p_name,p_color) returning id into result; return result; end; $$;
create function public.save_employee(p_id uuid,p_name text,p_role text,p_group_id uuid,p_active boolean,p_from date) returns uuid language plpgsql security definer set search_path='' as $$
declare result uuid;
begin
 perform public.require_admin();
 if p_from is null or p_from < (now() at time zone 'America/Sao_Paulo')::date then raise exception 'A vigencia deve ser hoje ou futura'; end if;
 if p_id is null then insert into public.employees(name,role,group_id,active) values(p_name,p_role,p_group_id,p_active) returning id into result;
 else update public.employees set name=p_name,role=p_role,group_id=p_group_id,active=p_active where id=p_id returning id into result; if result is null then raise exception 'Funcionario inexistente'; end if; end if;
 insert into public.memberships(employee_id,group_id,effective_from) values(result,p_group_id,p_from) on conflict(employee_id,effective_from) do update set group_id=excluded.group_id;
 perform public.mark_review(p_from); return result;
end; $$;
create function public.save_rule(p_employee_id uuid,p_group_id uuid,p_kind text,p_weekdays integer[],p_anchor date,p_from date) returns void language plpgsql security definer set search_path='' as $$
begin
 perform public.require_admin();
 if p_from is null or p_from < (now() at time zone 'America/Sao_Paulo')::date then raise exception 'A vigencia deve ser hoje ou futura'; end if;
 perform pg_advisory_xact_lock(hashtext('rule:'||coalesce(p_employee_id,p_group_id)::text));
 delete from public.rules where effective_from=p_from and (employee_id=p_employee_id or group_id=p_group_id);
 insert into public.rules(employee_id,group_id,kind,weekdays,anchor_date,effective_from) values(p_employee_id,p_group_id,p_kind,p_weekdays,p_anchor,p_from);
 perform public.mark_review(p_from);
end; $$;
-- Transferencias e trocas: um unico RPC / transacao para todas as celulas.
create function public.save_exceptions(p_changes jsonb,p_reason text) returns void language plpgsql security definer set search_path='' as $$
declare c jsonb;
begin
 perform public.require_admin();
 if jsonb_typeof(p_changes)<>'array' or jsonb_array_length(p_changes)=0 then raise exception 'Selecione as datas'; end if;
 for c in select value from jsonb_array_elements(p_changes) loop
  if (c->>'date')::date < (now() at time zone 'America/Sao_Paulo')::date then raise exception 'Excecoes historicas nao podem ser alteradas'; end if;
  insert into public.exceptions(employee_id,date,status,reason) values((c->>'employee_id')::uuid,(c->>'date')::date,c->>'status',p_reason) on conflict(employee_id,date) do update set status=excluded.status,reason=excluded.reason;
  perform public.mark_review((c->>'date')::date);
 end loop;
end; $$;
revoke execute on all functions in schema public from public,anon,authenticated;
grant execute on function public.is_admin() to authenticated;
grant execute on function public.save_schedule(date,text,text,jsonb,integer,boolean,boolean), public.save_group(text,text), public.save_employee(uuid,text,text,uuid,boolean,date), public.save_rule(uuid,uuid,text,integer[],date,date), public.save_exceptions(jsonb,text) to authenticated;
commit;


-- DiretÃ³rio seguro de administradores para a Ã¡rea ConfiguraÃ§Ãµes.
create or replace function public.list_admins()
returns table(user_id uuid, email text, role text, created_at timestamptz)
language sql security definer set search_path = '' as $$
  select a.user_id, u.email::text, a.role, u.created_at
  from public.admins a join auth.users u on u.id=a.user_id
  where exists (select 1 from public.admins me where me.user_id=auth.uid() and me.role='super_admin')
  order by u.created_at;
$$;
create or replace function public.set_admin_role(p_user_id uuid,p_role text)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if not exists(select 1 from public.admins where user_id=auth.uid() and role='super_admin') then raise exception 'Apenas Super Admin pode alterar acessos'; end if;
  if p_role not in ('admin','super_admin') then raise exception 'Perfil invÃ¡lido'; end if;
  insert into public.admins(user_id,role) values(p_user_id,p_role) on conflict(user_id) do update set role=excluded.role;
end; $$;
revoke execute on function public.list_admins() from public,anon,authenticated;
revoke execute on function public.set_admin_role(uuid,text) from public,anon,authenticated;
grant execute on function public.list_admins(), public.set_admin_role(uuid,text) to authenticated;

create or replace function public.delete_employee(p_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
begin
  perform public.require_admin();
  update public.employees set active=false where id=p_id;
  update public.memberships set group_id=null where employee_id=p_id;
end; $$;
revoke execute on function public.delete_employee(uuid) from public,anon,authenticated;
grant execute on function public.delete_employee(uuid) to authenticated;


-- Corrige a funÃ§Ã£o usada pela tela ConfiguraÃ§Ãµes.
create or replace function public.list_admins()
returns table(user_id uuid, email text, role text, created_at timestamptz)
language sql security definer set search_path = '' as $$
  select a.user_id, u.email::text, a.role, u.created_at
  from public.admins as a
  join auth.users as u on u.id = a.user_id
  where exists (
    select 1 from public.admins as me
    where me.user_id = auth.uid() and me.role = 'super_admin'
  )
  order by u.created_at;
$$;
revoke execute on function public.list_admins() from public, anon, authenticated;
grant execute on function public.list_admins() to authenticated;
notify pgrst, 'reload schema';

