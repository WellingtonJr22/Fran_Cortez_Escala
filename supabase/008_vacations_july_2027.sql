-- Ferias de julho de 2027: duas metades da equipe.
begin;
insert into public.vacations(employee_id,start_date,end_date,reason,created_by)
select id, date '2027-07-01', date '2027-07-15', 'Ferias - primeira quinzena', null
from public.employees
where id between '10000000-0000-0000-0000-000000000001' and '10000000-0000-0000-0000-000000000012'
and not exists (select 1 from public.vacations v where v.employee_id=employees.id and v.start_date=date '2027-07-01' and v.end_date=date '2027-07-15');
insert into public.vacations(employee_id,start_date,end_date,reason,created_by)
select id, date '2027-07-16', date '2027-07-31', 'Ferias - segunda quinzena', null
from public.employees
where id between '10000000-0000-0000-0000-000000000013' and '10000000-0000-0000-0000-000000000025'
and not exists (select 1 from public.vacations v where v.employee_id=employees.id and v.start_date=date '2027-07-16' and v.end_date=date '2027-07-31');
commit;
