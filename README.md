# Fran Cortez Salon · Escalas

Aplicação React/Vite para escalas automáticas e manuais, pronta para Vercel e Supabase.

## Primeiro acesso ao Supabase

1. Abra o SQL Editor do projeto `pxnokyhymiiijfwjpzph`.
2. Execute todo o arquivo [`supabase/migrations/001_scheduling.sql`](supabase/migrations/001_scheduling.sql).
3. Crie um usuário em Authentication > Users.
4. Insira esse usuário como administrador no SQL Editor:

```sql
insert into public.admins(user_id, role) values ('UUID_DO_USUARIO', 'super_admin');
```

Depois, rode `npm run dev` ou publique na Vercel. A chave usada em `.env.local` é a chave publicável; ela não substitui a `service_role` e não deve ser usada no SQL ou em funções de servidor.

## Comandos

```bash
npm install
npm run dev
npm test
npm run build
```

Sem as tabelas criadas, o frontend inicia em modo de demonstração com dados locais e avisa que a migração precisa ser executada. Depois que as tabelas existirem e o administrador estiver autenticado, gravações usam RPCs transacionais, RLS e auditoria.
