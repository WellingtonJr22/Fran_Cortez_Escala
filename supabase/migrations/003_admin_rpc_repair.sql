-- Corrige a função usada pela tela Configurações.
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
