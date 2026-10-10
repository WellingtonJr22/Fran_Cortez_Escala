-- Corrige nomes que foram gravados com dupla codificacao.
-- U& garante caracteres Unicode no PostgreSQL independentemente do clipboard.
update public.employees set name = U&'Vit\00f3ria' where id = '10000000-0000-0000-0000-000000000005';
update public.employees set name = U&'Ana Lu\00edsa' where id = '10000000-0000-0000-0000-000000000007';
update public.employees set name = U&'\00c9rica' where id = '10000000-0000-0000-0000-000000000008';
update public.employees set name = U&'Priscila' where id = '10000000-0000-0000-0000-000000000022';
update public.employees set name = U&'Katiele' where id = '10000000-0000-0000-0000-000000000024';

-- Repara tambem os nomes que podem ter sido colados em grupos/cargos.
update public.groups set name = U&'Revezamento - Grupo A' where id = '00000000-0000-0000-0000-0000000000a1';
update public.groups set name = U&'Revezamento - Grupo B' where id = '00000000-0000-0000-0000-0000000000b1';
update public.groups set name = U&'Equipe das 14h' where id = '00000000-0000-0000-0000-000000000014';
update public.groups set name = U&'Nail Design' where id = '00000000-0000-0000-0000-0000000000d1';
update public.groups set name = U&'Cabeleireiros' where id = '00000000-0000-0000-0000-0000000000cb';
