-- Schema curado do motor multi-tenant do e-kko. church -- parte 8/10.
--
-- Outdoors: banners rotativos do calendario. Visibilidade por `escopos`
-- segue a mesma regra generica dos eventos (03_eventos.sql) -- sem as
-- regras especificas da Shallom por idade/genero/estado civil.
--
-- Rode depois do 07_conteudos.sql.

create table public.outdoors (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants (id),
  imagem_url text not null,
  link_url text,
  tipo text not null check (tipo in ('recorrente','temporario','sempre')),
  semana_do_mes int check (semana_do_mes between 1 and 5),
  data_inicio date,
  data_fim date,
  ativo boolean not null default true,
  escopos text[], -- null/vazio = visivel a todo mundo do tenant
  criado_por uuid references public.profiles (id),
  criado_em timestamptz not null default now(),
  constraint outdoors_recorrente_precisa_semana check (tipo <> 'recorrente' or semana_do_mes is not null),
  constraint outdoors_temporario_precisa_periodo check (tipo <> 'temporario' or (data_inicio is not null and data_fim is not null))
);

alter table public.outdoors enable row level security;

create trigger trg_definir_tenant_id before insert on public.outdoors
  for each row execute function public.definir_tenant_id();

create policy "outdoors_select" on public.outdoors for select using (
  tenant_id = public.current_tenant_id() and (
    public.is_admin()
    or (
      ativo and (
        escopos is null or array_length(escopos, 1) is null
        or 'igreja' = any(escopos)
        or ('lideranca' = any(escopos) and public.is_lider_de_algum_ministerio())
        or exists (
          select 1 from public.profile_ministerios pm
          where pm.profile_id = auth.uid() and pm.ministerio = any(outdoors.escopos)
        )
      )
    )
  )
);

-- Site publico de uma igreja (quando existir) -- ver tenant_id_anonimo()
-- em 02_funcoes_papel.sql.
create policy "outdoors_select_publico" on public.outdoors for select to anon using (
  ativo = true and tenant_id = public.tenant_id_anonimo()
  and (escopos is null or array_length(escopos, 1) is null or 'igreja' = any(escopos))
);

create policy "outdoors_insert" on public.outdoors for insert with check (
  tenant_id = public.current_tenant_id() and public.is_admin()
);
create policy "outdoors_update" on public.outdoors for update using (
  tenant_id = public.current_tenant_id() and public.is_admin()
);
create policy "outdoors_delete" on public.outdoors for delete using (
  tenant_id = public.current_tenant_id() and public.is_admin()
);
