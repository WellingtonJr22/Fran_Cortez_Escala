create table if not exists public.vacations (
  id uuid primary key default gen_random_uuid(),
  employee_id uuid not null references public.employees(id),
  start_date date not null,
  end_date date not null,
  reason text not null default 'Férias',
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  check (end_date >= start_date)
);
alter table public.vacations enable row level security;
drop policy if exists admin_read on public.vacations;
create policy admin_read on public.vacations for select to authenticated using (public.is_admin());
revoke all on public.vacations from anon, authenticated;
grant select on public.vacations to authenticated;
create or replace function public.save_vacation(p_employee_id uuid,p_start date,p_end date,p_reason text default 'Férias')
returns uuid language plpgsql security definer set search_path = '' as $$
declare result uuid;
begin
  perform public.require_admin();
  insert into public.vacations(employee_id,start_date,end_date,reason,created_by)
  values(p_employee_id,p_start,p_end,coalesce(nullif(trim(p_reason),''),'Férias'),auth.uid()) returning id into result;
  return result;
end; $$;
revoke execute on function public.save_vacation(uuid,date,date,text) from public,anon,authenticated;
grant execute on function public.save_vacation(uuid,date,date,text) to authenticated;

-- Exemplo inicial: duas metades da equipe em janeiro de 2027.
insert into public.vacations(employee_id,start_date,end_date,reason,created_by)
select id, date '2027-01-01', date '2027-01-15', 'Férias - primeira quinzena', null
from public.employees
where id in ('10000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000003','10000000-0000-0000-0000-000000000004','10000000-0000-0000-0000-000000000005','10000000-0000-0000-0000-000000000006','10000000-0000-0000-0000-000000000007','10000000-0000-0000-0000-000000000008','10000000-0000-0000-0000-000000000009','10000000-0000-0000-0000-000000000010','10000000-0000-0000-0000-000000000011','10000000-0000-0000-0000-000000000012')
and not exists(select 1 from public.vacations v where v.employee_id=employees.id and v.start_date=date '2027-01-01' and v.end_date=date '2027-01-15');
insert into public.vacations(employee_id,start_date,end_date,reason,created_by)
select id, date '2027-01-16', date '2027-01-31', 'Férias - segunda quinzena', null
from public.employees
where id in ('10000000-0000-0000-0000-000000000013','10000000-0000-0000-0000-000000000014','10000000-0000-0000-0000-000000000015','10000000-0000-0000-0000-000000000016','10000000-0000-0000-0000-000000000017','10000000-0000-0000-0000-000000000018','10000000-0000-0000-0000-000000000019','10000000-0000-0000-0000-000000000020','10000000-0000-0000-0000-000000000021','10000000-0000-0000-0000-000000000022','10000000-0000-0000-0000-000000000023','10000000-0000-0000-0000-000000000024','10000000-0000-0000-0000-000000000025')
and not exists(select 1 from public.vacations v where v.employee_id=employees.id and v.start_date=date '2027-01-16' and v.end_date=date '2027-01-31');
