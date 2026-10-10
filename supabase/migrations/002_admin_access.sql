-- Diretório seguro de administradores para a área Configurações.
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
  if p_role not in ('admin','super_admin') then raise exception 'Perfil inválido'; end if;
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
