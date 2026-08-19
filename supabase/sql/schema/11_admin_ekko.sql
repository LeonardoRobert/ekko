-- Schema curado do motor multi-tenant do e-kko. church -- parte 11.
--
-- Ate' aqui (00-10), `tenants` so tinha select liberado -- nenhuma
-- policy de escrita de proposito (ver comentario em 00_tenants.sql).
-- O painel de controle (docs/painel.html) precisa editar cores/logo/
-- modulos_ativos/ministerio_primeira_vez de uma igreja, entao precisa
-- de alguem que possa escrever ali cruzando a fronteira de tenant --
-- diferente de is_admin(), que so' enxerga o proprio tenant da pessoa.
--
-- Fase 0 (poucos clientes, so' o Leo mexe nisso): lista fixa de e-mail
-- no proprio SQL, sem tabela de admins da e-kko -- so vale criar uma
-- tabela pra isso quando o volume justificar (mesmo racional do
-- onboarding manual de tenant, ver CLAUDE.md).
--
-- Rode depois do 10_storage_buckets.sql.

create or replace function public.is_admin_ekko() returns boolean
language sql stable as $$
  select coalesce(auth.jwt() ->> 'email', '') in (
    'leonardorobertcampos@gmail.com'
  );
$$;

create policy "tenants_update_admin_ekko" on public.tenants for update using (
  public.is_admin_ekko()
) with check (
  public.is_admin_ekko()
);
