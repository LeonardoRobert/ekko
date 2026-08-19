-- Schema curado do motor multi-tenant do e-kko. church -- parte 9/10.
--
-- Cadastro de filhos dos membros.
--
-- Rode depois do 08_outdoors.sql.

create table public.filhos (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants (id),
  responsavel_id uuid not null references public.profiles (id) on delete cascade,
  nome text not null,
  data_nascimento date,
  criado_em timestamptz not null default now()
);

alter table public.filhos enable row level security;

create trigger trg_definir_tenant_id before insert on public.filhos
  for each row execute function public.definir_tenant_id();

create policy "filhos_select" on public.filhos for select using (
  tenant_id = public.current_tenant_id() and (responsavel_id = auth.uid() or public.is_admin())
);
create policy "filhos_insert" on public.filhos for insert with check (
  tenant_id = public.current_tenant_id() and responsavel_id = auth.uid()
);
create policy "filhos_update" on public.filhos for update using (
  tenant_id = public.current_tenant_id() and responsavel_id = auth.uid()
);
create policy "filhos_delete" on public.filhos for delete using (
  tenant_id = public.current_tenant_id() and responsavel_id = auth.uid()
);
