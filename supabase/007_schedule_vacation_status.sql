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
   if to_char(d,'YYYY-MM-DD')<>kv.key or date_trunc('month',d)::date<>p_month or kv.value not in ('T','F','V','pending') or kv.value is null then raise exception 'Data ou indicador invalido'; end if;
   if kv.value='pending' then pending_count:=pending_count+1; end if;
   if kv.value='T' and extract(dow from d)=0 then sunday_count:=sunday_count+1; end if;
  end loop;
 end loop;
 if p_status='confirmed' and (cardinality(seen)=0 or pending_count>0) then raise exception 'Resolva os dias a confirmar antes de confirmar a escala'; end if;
 if p_status='confirmed' and sunday_count>0 and not p_ack_conflicts then raise exception 'Confirme explicitamente o trabalho aos domingos'; end if;
 insert into public.schedules(month,status,mode,rows,updated_by) values(p_month,p_status,p_mode,p_rows,auth.uid()) on conflict(month) do update set status=excluded.status,mode=excluded.mode,rows=excluded.rows,version=public.schedules.version+1,needs_review=false,updated_at=now(),updated_by=auth.uid() returning * into saved;
 return saved;
end; $$;

