-- Schema curado do motor multi-tenant do e-kko. church -- parte 3/10.
--
-- Tabela `eventos` (calendario). `tipo`/`escopo` sao texto livre, sem
-- CHECK de valores fixos -- cada igreja configura os proprios (a
-- Shallom usava ebd/gc/comunhao/... e igreja/homens/mulheres/awake/...,
-- mas isso e' convencao de uso dela, nao regra do motor generico).
--
-- Regra de visibilidade por escopo (generica, decidida com o Leo):
--   'igreja'    -> visivel a todo mundo do tenant
--   'lideranca' -> visivel a qualquer lider (de qualquer ministerio)
--   qualquer outro escopo -> visivel a quem esta' no
--                            profile_ministerios daquele ministerio
-- As regras especificas da Shallom (idade dos filhos p/ 'criancas',
-- estado civil p/ 'casais', publico-alvo por idade/genero em
-- awake/coral) NAO foram portadas -- as colunas ficam no schema (pra
-- bater com EventModel) mas sem uso na RLS por enquanto.
--
-- Rode depois do 02_funcoes_papel.sql.

create table public.eventos (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants (id),
  titulo text not null,
  descricao text,
  data_inicio timestamptz not null,
  data_fim timestamptz,
  local text,
  criado_por uuid references public.profiles (id),
  recorrente boolean not null default false,
  recorrencia_fim date,
  semanas_do_mes int[],
  tipo text not null default 'outro',
  escopo text not null default 'igreja',
  publico_alvo text[],
  publico_genero text[],
  publico_casais text[],
  excecoes timestamptz[] not null default '{}',
  foto_url text,
  foto_story_url text,
  ingressado boolean not null default false,
  valor_total numeric,
  parcelas_sugeridas int,
  metodos_pagamento text[],
  visivel_site_publico boolean not null default false,
  criado_em timestamptz not null default now()
);

alter table public.eventos enable row level security;

create trigger trg_definir_tenant_id before insert on public.eventos
  for each row execute function public.definir_tenant_id();

create policy "eventos_select" on public.eventos for select using (
  tenant_id = public.current_tenant_id() and (
    public.is_admin()
    or escopo = 'igreja'
    or (escopo = 'lideranca' and public.is_lider_de_algum_ministerio())
    or exists (
      select 1 from public.profile_ministerios pm
      where pm.profile_id = auth.uid() and pm.ministerio = eventos.escopo
    )
  )
);

-- Site publico de uma igreja (quando existir) -- ver tenant_id_anonimo()
-- em 02_funcoes_papel.sql. Sem o header 'x-tenant-slug', nao libera nada.
create policy "eventos_select_publico" on public.eventos for select to anon using (
  visivel_site_publico = true and tenant_id = public.tenant_id_anonimo()
);

create policy "eventos_insert" on public.eventos for insert with check (
  tenant_id = public.current_tenant_id() and public.is_lider_ministerio(escopo)
);

create policy "eventos_update" on public.eventos for update using (
  tenant_id = public.current_tenant_id() and public.is_lider_ministerio(escopo)
);

create policy "eventos_delete" on public.eventos for delete using (
  tenant_id = public.current_tenant_id() and public.is_lider_ministerio(escopo)
);

-- Apaga so' UMA ocorrencia de um evento recorrente (adiciona a data no
-- array de excecoes), mantendo as outras semanas da serie. Roda como
-- SECURITY INVOKER (padrao) de proposito -- passa pela RLS de update
-- normal (so' quem e' lider do ministerio do evento pode chamar).
create or replace function public.excluir_ocorrencia_evento(p_evento_id uuid, p_data date) returns void
language sql as $$
  update public.eventos
  set excecoes = array_append(excecoes, p_data::timestamptz)
  where id = p_evento_id;
$$;
