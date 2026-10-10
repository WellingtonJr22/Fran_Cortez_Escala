create or replace function public.delete_employee(p_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.require_admin();
  -- Exclusao logica: preserva escalas e auditoria historicas.
  update public.employees
  set active = false
  where id = p_id;
  update public.memberships
  set group_id = null
  where employee_id = p_id;
end;
$$;
revoke execute on function public.delete_employee(uuid) from public, anon, authenticated;
grant execute on function public.delete_employee(uuid) to authenticated;
