-- Schema curado do motor multi-tenant do e-kko. church -- parte 6/10.
--
-- Cuidado pastoral: pedidos de oracao, testemunhos, questionario de
-- novo servo, visitantes de Primeira Vez.
--
-- `pode_registrar_primeira_vez()` substitui o antigo
-- `esta_na_escala_primeira_vez()` da Shallom (que dependia do sistema
-- Escala Awake removido). Agora e' configuravel por tenant: cada igreja
-- escolhe, em `tenants.ministerio_primeira_vez`, qual ministerio de
-- Escala de Servico (ex: 'recepcao') habilita a pessoa escalada NAQUELE
-- DIA a registrar visitantes. Enquanto o tenant nao configurar essa
-- coluna, so' admin pode registrar.
--
-- Rode depois do 05_contribuicoes.sql.

alter table public.tenants add column if not exists ministerio_primeira_vez text;

create table public.pedidos_oracao (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants (id),
  profile_id uuid not null references public.profiles (id),
  anonimo boolean not null default false,
  texto text not null,
  lido boolean not null default false,
  criado_em timestamptz not null default now()
);

create table public.testemunhos (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants (id),
  profile_id uuid not null references public.profiles (id),
  anonimo boolean not null default false,
  texto text not null,
  lido boolean not null default false,
  criado_em timestamptz not null default now()
);

create table public.questionarios_novo_servo (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants (id),
  profile_id uuid not null references public.profiles (id),
  respostas jsonb not null default '{}'::jsonb,
  lido boolean not null default false,
  criado_em timestamptz not null default now()
);

create table public.visitantes_primeira_vez (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants (id),
  registrado_por uuid references public.profiles (id),
  dados jsonb not null default '{}'::jsonb,
  lido boolean not null default false,
  acompanhado_por uuid references public.profiles (id) on delete set null,
  primeiro_retorno date,
  segundo_retorno date,
  virou_membro boolean not null default false,
  criado_em timestamptz not null default now()
);

-- pedidos_oracao ---------------------------------------------------------

alter table public.pedidos_oracao enable row level security;
create trigger trg_definir_tenant_id before insert on public.pedidos_oracao
  for each row execute function public.definir_tenant_id();

create policy "pedidos_oracao_select" on public.pedidos_oracao for select using (
  tenant_id = public.current_tenant_id() and (profile_id = auth.uid() or public.is_admin())
);
create policy "pedidos_oracao_insert" on public.pedidos_oracao for insert with check (
  tenant_id = public.current_tenant_id() and profile_id = auth.uid()
);
create policy "pedidos_oracao_update" on public.pedidos_oracao for update using (
  tenant_id = public.current_tenant_id() and public.is_admin()
);
create policy "pedidos_oracao_delete" on public.pedidos_oracao for delete using (
  tenant_id = public.current_tenant_id() and public.is_admin()
);

-- testemunhos --------------------------------------------------------------

alter table public.testemunhos enable row level security;
create trigger trg_definir_tenant_id before insert on public.testemunhos
  for each row execute function public.definir_tenant_id();

create policy "testemunhos_select" on public.testemunhos for select using (
  tenant_id = public.current_tenant_id() and (profile_id = auth.uid() or public.is_admin())
);
create policy "testemunhos_insert" on public.testemunhos for insert with check (
  tenant_id = public.current_tenant_id() and profile_id = auth.uid()
);
create policy "testemunhos_update" on public.testemunhos for update using (
  tenant_id = public.current_tenant_id() and public.is_admin()
);
create policy "testemunhos_delete" on public.testemunhos for delete using (
  tenant_id = public.current_tenant_id() and public.is_admin()
);

-- questionarios_novo_servo --------------------------------------------------

alter table public.questionarios_novo_servo enable row level security;
create trigger trg_definir_tenant_id before insert on public.questionarios_novo_servo
  for each row execute function public.definir_tenant_id();

create policy "questionarios_novo_servo_select" on public.questionarios_novo_servo for select using (
  tenant_id = public.current_tenant_id() and (profile_id = auth.uid() or public.is_admin())
);
create policy "questionarios_novo_servo_insert" on public.questionarios_novo_servo for insert with check (
  tenant_id = public.current_tenant_id() and profile_id = auth.uid()
);
create policy "questionarios_novo_servo_update" on public.questionarios_novo_servo for update using (
  tenant_id = public.current_tenant_id() and public.is_admin()
);
create policy "questionarios_novo_servo_delete" on public.questionarios_novo_servo for delete using (
  tenant_id = public.current_tenant_id() and public.is_admin()
);

-- visitantes_primeira_vez ---------------------------------------------------

create or replace function public.pode_registrar_primeira_vez() returns boolean
language sql security definer stable set search_path = public as $$
  select public.is_admin() or exists (
    select 1
    from public.tenants t
    join public.escalas_servico es on es.tenant_id = t.id and es.ministerio = t.ministerio_primeira_vez
    join public.escala_servico_posicoes p on p.escala_id = es.id
    where t.id = public.current_tenant_id()
      and t.ministerio_primeira_vez is not null
      and es.data_ocorrencia = current_date
      and (p.profile_id = auth.uid() or p.profile_id_2 = auth.uid())
  );
$$;

alter table public.visitantes_primeira_vez enable row level security;
create trigger trg_definir_tenant_id before insert on public.visitantes_primeira_vez
  for each row execute function public.definir_tenant_id();

create policy "visitantes_pv_select" on public.visitantes_primeira_vez for select using (
  tenant_id = public.current_tenant_id() and (
    registrado_por = auth.uid()
    or public.is_admin()
    or exists (
      select 1 from public.tenants t
      where t.id = visitantes_primeira_vez.tenant_id
        and t.ministerio_primeira_vez is not null
        and public.is_lider_ministerio(t.ministerio_primeira_vez)
    )
  )
);
create policy "visitantes_pv_insert" on public.visitantes_primeira_vez for insert with check (
  tenant_id = public.current_tenant_id() and public.pode_registrar_primeira_vez()
);
create policy "visitantes_pv_update" on public.visitantes_primeira_vez for update using (
  tenant_id = public.current_tenant_id() and (
    public.is_admin()
    or exists (
      select 1 from public.tenants t
      where t.id = visitantes_primeira_vez.tenant_id
        and t.ministerio_primeira_vez is not null
        and public.is_lider_ministerio(t.ministerio_primeira_vez)
    )
  )
);
create policy "visitantes_pv_delete" on public.visitantes_primeira_vez for delete using (
  tenant_id = public.current_tenant_id() and public.is_admin()
);
