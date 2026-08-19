-- Schema curado do motor multi-tenant do e-kko. church -- parte 7/10.
--
-- "Nossos Conteudos": Treinamentos e materiais anexados aos videos do
-- YouTube (os videos em si nao sao persistidos aqui, vem ao vivo da
-- API -- so' o vinculo com o material anexado fica no banco).
--
-- video_youtube_id fica com unique GLOBAL (nao por tenant) de proposito:
-- o service Dart faz upsert com onConflict: 'video_youtube_id' (coluna
-- unica), e IDs de video do YouTube ja' sao globalmente unicos na
-- pratica -- nao ha' problema real em manter assim.
--
-- Rode depois do 06_cuidado_pastoral.sql.

create table public.treinamentos (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants (id),
  titulo text not null,
  descricao text,
  url_video text,
  criado_em timestamptz not null default now()
);

create table public.video_materiais (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants (id),
  video_youtube_id text not null unique,
  material_url text not null,
  nome_arquivo text,
  criado_por uuid references public.profiles (id),
  criado_em timestamptz not null default now()
);

-- treinamentos ---------------------------------------------------------

alter table public.treinamentos enable row level security;
create trigger trg_definir_tenant_id before insert on public.treinamentos
  for each row execute function public.definir_tenant_id();

create policy "treinamentos_select" on public.treinamentos for select using (
  tenant_id = public.current_tenant_id() and auth.uid() is not null
);
create policy "treinamentos_insert" on public.treinamentos for insert with check (
  tenant_id = public.current_tenant_id() and public.is_admin()
);
create policy "treinamentos_update" on public.treinamentos for update using (
  tenant_id = public.current_tenant_id() and public.is_admin()
);
create policy "treinamentos_delete" on public.treinamentos for delete using (
  tenant_id = public.current_tenant_id() and public.is_admin()
);

-- video_materiais --------------------------------------------------------

alter table public.video_materiais enable row level security;
create trigger trg_definir_tenant_id before insert on public.video_materiais
  for each row execute function public.definir_tenant_id();

create policy "video_materiais_select" on public.video_materiais for select using (
  tenant_id = public.current_tenant_id() and auth.uid() is not null
);
create policy "video_materiais_insert" on public.video_materiais for insert with check (
  tenant_id = public.current_tenant_id() and public.is_admin()
);
create policy "video_materiais_update" on public.video_materiais for update using (
  tenant_id = public.current_tenant_id() and public.is_admin()
);
create policy "video_materiais_delete" on public.video_materiais for delete using (
  tenant_id = public.current_tenant_id() and public.is_admin()
);
