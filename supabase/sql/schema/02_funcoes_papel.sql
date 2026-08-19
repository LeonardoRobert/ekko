-- Schema curado do motor multi-tenant do e-kko. church -- parte 2/10.
--
-- Funcoes de checagem de papel/tenant reutilizadas pelas RLS de todas as
-- tabelas seguintes, mais a RLS de profiles/profile_ministerios (que
-- depende dessas funcoes, por isso nao ficou no arquivo 01).
--
-- Rode depois do 01_profiles.sql.

-- Tenant do usuario logado (le' da propria linha de profiles dele).
create or replace function public.current_tenant_id() returns uuid
language sql security definer stable set search_path = public as $$
  select tenant_id from public.profiles where id = auth.uid();
$$;

create or replace function public.is_admin() returns boolean
language sql security definer stable set search_path = public as $$
  select exists (select 1 from public.profiles where id = auth.uid() and papel = 'admin');
$$;

create or replace function public.is_lider_ministerio(p_ministerio text) returns boolean
language sql security definer stable set search_path = public as $$
  select public.is_admin() or exists (
    select 1 from public.profile_ministerios
    where profile_id = auth.uid() and ministerio = p_ministerio and papel = 'lider'
  );
$$;

create or replace function public.is_lider_de_algum_ministerio() returns boolean
language sql security definer stable set search_path = public as $$
  select exists (select 1 from public.profile_ministerios where profile_id = auth.uid() and papel = 'lider');
$$;

-- Identificacao de tenant pra requisicoes SEM login (site publico de uma
-- igreja, quando existir -- ver passo 7 do CLAUDE.md). O cliente
-- anonimo precisa mandar um header customizado 'x-tenant-slug' em toda
-- chamada; sem ele, as policies "to anon" nao liberam nada (fail closed
-- de proposito -- nao da' pra usar auth.uid() pra quem nao logou).
create or replace function public.tenant_slug_anonimo() returns text
language sql stable as $$
  select nullif(current_setting('request.headers', true)::json->>'x-tenant-slug', '');
$$;

create or replace function public.tenant_id_anonimo() returns uuid
language sql security definer stable set search_path = public as $$
  select id from public.tenants where slug = public.tenant_slug_anonimo();
$$;

-- Trigger generica: preenche tenant_id sozinho no insert (a partir do
-- tenant do usuario logado), pra services Dart nao precisarem mandar
-- tenant_id em toInsertMap(). Usada BEFORE INSERT em toda tabela de
-- dominio a partir daqui.
create or replace function public.definir_tenant_id() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.tenant_id is null then
    new.tenant_id := public.current_tenant_id();
  end if;
  return new;
end;
$$;

-- RLS de profiles / profile_ministerios ------------------------------

alter table public.profiles enable row level security;

create policy "profiles_select" on public.profiles for select using (
  tenant_id = public.current_tenant_id()
  and (id = auth.uid() or public.is_admin() or public.is_lider_de_algum_ministerio())
);

-- Sem policy de insert: a linha e' criada so' pela trigger
-- handle_new_user (roda como dono da funcao, ignora RLS).

create policy "profiles_update_self" on public.profiles for update
  using (id = auth.uid())
  with check (id = auth.uid() and tenant_id = public.current_tenant_id());

create policy "profiles_update_admin" on public.profiles for update using (
  tenant_id = public.current_tenant_id() and public.is_admin()
);

alter table public.profile_ministerios enable row level security;

create trigger trg_definir_tenant_id before insert on public.profile_ministerios
  for each row execute function public.definir_tenant_id();

create policy "profile_ministerios_select" on public.profile_ministerios for select using (
  tenant_id = public.current_tenant_id()
  and (profile_id = auth.uid() or public.is_admin() or public.is_lider_ministerio(ministerio))
);

create policy "profile_ministerios_insert" on public.profile_ministerios for insert with check (
  tenant_id = public.current_tenant_id() and (profile_id = auth.uid() or public.is_admin())
);

create policy "profile_ministerios_update" on public.profile_ministerios for update using (
  tenant_id = public.current_tenant_id() and public.is_admin()
);

create policy "profile_ministerios_delete" on public.profile_ministerios for delete using (
  tenant_id = public.current_tenant_id() and public.is_admin()
);
