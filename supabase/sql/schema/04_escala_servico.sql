-- Schema curado do motor multi-tenant do e-kko. church -- parte 4/10.
--
-- Escala de Servico generica (Diaconos, Louvor, Danca, Midia,
-- Multimidia, Coral, Recepcao, etc. -- so' mais um valor de
-- `ministerio`, sem CHECK fixo). `escala_servico_casais` cobre posicoes
-- em casal (ex: Diaconos).
--
-- Rode depois do 03_eventos.sql.

create table public.escalas_servico (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants (id),
  ministerio text not null,
  evento_id uuid references public.eventos (id) on delete cascade,
  data_ocorrencia date not null,
  criado_por uuid references public.profiles (id),
  criado_em timestamptz not null default now(),
  unique (ministerio, evento_id, data_ocorrencia)
);

create table public.escala_servico_posicoes (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants (id),
  escala_id uuid not null references public.escalas_servico (id) on delete cascade,
  funcao text not null,
  profile_id uuid references public.profiles (id),
  profile_id_2 uuid references public.profiles (id), -- posicao em casal (ex: Diaconos)
  ordem int not null default 0,
  criado_em timestamptz not null default now()
);

create table public.escala_servico_funcoes_catalogo (
  tenant_id uuid not null references public.tenants (id),
  ministerio text not null,
  funcao text not null,
  ordem int not null default 0,
  primary key (tenant_id, ministerio, funcao)
);

create table public.escala_servico_casais (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants (id),
  ministerio text not null,
  profile_id_a uuid not null references public.profiles (id) on delete cascade,
  profile_id_b uuid not null references public.profiles (id) on delete cascade,
  criado_por uuid references public.profiles (id),
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now(),
  constraint escala_servico_casais_ordem check (profile_id_a < profile_id_b),
  constraint escala_servico_casais_par_unico unique (ministerio, profile_id_a, profile_id_b)
);

-- escalas_servico ------------------------------------------------------

alter table public.escalas_servico enable row level security;
create trigger trg_definir_tenant_id before insert on public.escalas_servico
  for each row execute function public.definir_tenant_id();

create policy "escalas_servico_select" on public.escalas_servico for select using (
  tenant_id = public.current_tenant_id()
);
create policy "escalas_servico_insert" on public.escalas_servico for insert with check (
  tenant_id = public.current_tenant_id() and public.is_lider_ministerio(ministerio)
);
create policy "escalas_servico_update" on public.escalas_servico for update using (
  tenant_id = public.current_tenant_id() and public.is_lider_ministerio(ministerio)
);
create policy "escalas_servico_delete" on public.escalas_servico for delete using (
  tenant_id = public.current_tenant_id() and public.is_lider_ministerio(ministerio)
);

-- escala_servico_posicoes ----------------------------------------------

alter table public.escala_servico_posicoes enable row level security;
create trigger trg_definir_tenant_id before insert on public.escala_servico_posicoes
  for each row execute function public.definir_tenant_id();

create policy "escala_servico_posicoes_select" on public.escala_servico_posicoes for select using (
  tenant_id = public.current_tenant_id()
);
create policy "escala_servico_posicoes_insert" on public.escala_servico_posicoes for insert with check (
  tenant_id = public.current_tenant_id() and exists (
    select 1 from public.escalas_servico es
    where es.id = escala_servico_posicoes.escala_id and public.is_lider_ministerio(es.ministerio)
  )
);
create policy "escala_servico_posicoes_update" on public.escala_servico_posicoes for update using (
  tenant_id = public.current_tenant_id() and exists (
    select 1 from public.escalas_servico es
    where es.id = escala_servico_posicoes.escala_id and public.is_lider_ministerio(es.ministerio)
  )
);
create policy "escala_servico_posicoes_delete" on public.escala_servico_posicoes for delete using (
  tenant_id = public.current_tenant_id() and exists (
    select 1 from public.escalas_servico es
    where es.id = escala_servico_posicoes.escala_id and public.is_lider_ministerio(es.ministerio)
  )
);

-- escala_servico_funcoes_catalogo ---------------------------------------

alter table public.escala_servico_funcoes_catalogo enable row level security;
create trigger trg_definir_tenant_id before insert on public.escala_servico_funcoes_catalogo
  for each row execute function public.definir_tenant_id();

create policy "escala_servico_funcoes_catalogo_select" on public.escala_servico_funcoes_catalogo for select using (
  tenant_id = public.current_tenant_id()
);
create policy "escala_servico_funcoes_catalogo_insert" on public.escala_servico_funcoes_catalogo for insert with check (
  tenant_id = public.current_tenant_id() and public.is_lider_ministerio(ministerio)
);
create policy "escala_servico_funcoes_catalogo_update" on public.escala_servico_funcoes_catalogo for update using (
  tenant_id = public.current_tenant_id() and public.is_lider_ministerio(ministerio)
);
create policy "escala_servico_funcoes_catalogo_delete" on public.escala_servico_funcoes_catalogo for delete using (
  tenant_id = public.current_tenant_id() and public.is_lider_ministerio(ministerio)
);

-- escala_servico_casais --------------------------------------------------

alter table public.escala_servico_casais enable row level security;
create trigger trg_definir_tenant_id before insert on public.escala_servico_casais
  for each row execute function public.definir_tenant_id();

create policy "escala_servico_casais_select" on public.escala_servico_casais for select using (
  tenant_id = public.current_tenant_id() and public.is_lider_ministerio(ministerio)
);
create policy "escala_servico_casais_insert" on public.escala_servico_casais for insert with check (
  tenant_id = public.current_tenant_id() and public.is_lider_ministerio(ministerio)
);
create policy "escala_servico_casais_update" on public.escala_servico_casais for update using (
  tenant_id = public.current_tenant_id() and public.is_lider_ministerio(ministerio)
);
create policy "escala_servico_casais_delete" on public.escala_servico_casais for delete using (
  tenant_id = public.current_tenant_id() and public.is_lider_ministerio(ministerio)
);
