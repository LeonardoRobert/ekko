-- Schema completo do motor multi-tenant do e-kko. church
-- Gerado juntando 00_tenants.sql ... 13_notificacoes.sql, nessa ordem.
-- Cole tudo de uma vez no SQL Editor de um projeto Supabase NOVO e vazio, e rode.
--
-- Os arquivos numerados continuam sendo a fonte de verdade pra editar depois --
-- se mudar algo, mude no arquivo individual e regenere este aqui.


-- ============================================================
-- 00_tenants.sql
-- ============================================================
-- Tabela base do motor multi-tenant do e-kko. church.
--
-- Cada build do app pertence a UM tenant so (Env.tenantSlug, definido
-- na hora de compilar -- ver lib/core/env.dart), mas todos os tenants
-- vivem nesse MESMO projeto Supabase. E' essa tabela que o app le na
-- inicializacao (tenant_provider.dart) pra saber cor primaria/destaque,
-- logo e quais modulos aparecem na navegacao.
--
-- Cole no Supabase Dashboard -> SQL Editor do projeto NOVO da e-kko
-- (NUNCA no projeto da Shallom em producao) e rode manualmente.

create table if not exists public.tenants (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  nome text not null,
  cor_primaria text not null,   -- '#RRGGBB', cor de chrome (barras)
  cor_destaque text not null,   -- '#RRGGBB', cor de destaque (botoes/FAB)
  logo_url text,
  -- Catalogo de chaves validas hoje: 'calendario', 'conteudos',
  -- 'financeiro' -- ver _catalogoDeAbas em lib/screens/home/home_shell.dart.
  modulos_ativos text[] not null default '{}',
  ativo boolean not null default true,
  criado_em timestamptz not null default now()
);

alter table public.tenants enable row level security;

-- Leitura liberada geral (inclusive sem login -- a tela de login
-- precisa ler cor/logo do tenant ANTES da pessoa se autenticar).
-- Nao tem dado sensivel aqui, so identidade visual e config publica.
create policy tenants_select on public.tenants
  for select using (true);

-- Escrita: por enquanto so via Service Role (o Leo mexendo direto no
-- SQL Editor / futuro painel de controle) -- nao existe ainda um papel
-- "admin da e-kko" com policy propria, entao NAO cria policy de
-- insert/update/delete aqui de proposito.

-- Exemplo de seed pra testar localmente (ajustar antes de rodar):
-- insert into public.tenants (slug, nome, cor_primaria, cor_destaque, modulos_ativos)
-- values ('demo', 'Igreja Demo', '#0C192E', '#FFD21F', array['calendario','conteudos','financeiro']);

-- ============================================================
-- 01_profiles.sql
-- ============================================================
-- Schema curado do motor multi-tenant do e-kko. church -- parte 1/10.
--
-- Tabelas `profiles` e `profile_ministerios`, mais a trigger que cria o
-- perfil automaticamente no signup (le' o tenant_id que o app manda no
-- metadata do auth.signUp -- ver lib/services/auth_service.dart).
--
-- RLS de profiles/profile_ministerios fica no arquivo 02 (depende das
-- funcoes de papel definidas la').
--
-- Cole no Supabase Dashboard -> SQL Editor do projeto NOVO da e-kko e
-- rode NA ORDEM (01, 02, 03...). Precisa da tabela `tenants` (00) ja
-- criada antes.

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  tenant_id uuid not null references public.tenants (id),
  nome text not null default '',
  telefone text,
  endereco text,
  data_nascimento date,
  tempo_participacao text,
  estado_civil text check (estado_civil is null or estado_civil in ('solteiro','namorando','noivo','casado','outro')),
  sexo text check (sexo is null or sexo in ('masculino','feminino')),
  -- Texto livre de proposito (nao e' enum fixo): cada igreja usa o nome
  -- de grupo que quiser, ou deixa em branco se nao usar essa feature.
  grupo_casais text,
  foto_url text,
  -- Idem: categoria interna (ex: faixa etaria/estado civil de um
  -- ministerio de jovens) e' texto livre, configuravel por igreja, sem
  -- calculo automatico no banco -- isso era logica especifica da
  -- Shallom (Genesis/Next/One), nao faz parte do motor generico.
  categoria text,
  papel text not null default 'membro' check (papel in ('membro','admin')),
  -- Residuo do sistema de check-in por QR Code (removido do motor
  -- generico) -- mantido so' porque ProfileModel.fromMap ainda le' esse
  -- campo como obrigatorio. Nao usado por nenhuma tela nova.
  qr_code_id uuid not null default gen_random_uuid(),
  ativo boolean not null default true,
  tour_visto boolean not null default false,
  valor_dizimo_padrao numeric,
  criado_em timestamptz not null default now()
);

create table public.profile_ministerios (
  profile_id uuid not null references public.profiles (id) on delete cascade,
  tenant_id uuid not null references public.tenants (id),
  -- Texto livre (nao enum fixo): cada igreja cadastra os proprios
  -- ministerios. O catalogo de nomes usados hoje pelo app (Diaconos,
  -- Louvor, Danca, Midia, Multimidia, Coral, etc.) e' so' convencao de
  -- uso, nao restricao de banco.
  ministerio text not null,
  papel text not null default 'membro' check (papel in ('membro','lider')),
  criado_em timestamptz not null default now(),
  primary key (profile_id, ministerio)
);

-- Cria a linha de profiles automaticamente quando alguem se cadastra.
-- O tenant_id vem do metadata passado em auth.signUp(data: {...}) --
-- ver lib/services/auth_service.dart e lib/screens/auth/signup_screen.dart.
-- Se o metadata NAO tiver tenant_id, nao cria profile nenhum (em vez de
-- falhar) -- e' o caso de uma conta criada direto no Dashboard sem
-- passar pelo cadastro do app, ex: o admin da e-kko (ver
-- 11_admin_ekko.sql), que nao pertence a tenant nenhum.
create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  v_tenant_id uuid;
begin
  v_tenant_id := (new.raw_user_meta_data->>'tenant_id')::uuid;
  if v_tenant_id is null then
    return new;
  end if;

  insert into public.profiles (id, tenant_id, nome)
  values (new.id, v_tenant_id, coalesce(new.raw_user_meta_data->>'nome', ''));
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ============================================================
-- 02_funcoes_papel.sql
-- ============================================================
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

-- ============================================================
-- 03_eventos.sql
-- ============================================================
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

-- ============================================================
-- 04_escala_servico.sql
-- ============================================================
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

-- ============================================================
-- 05_contribuicoes.sql
-- ============================================================
-- Schema curado do motor multi-tenant do e-kko. church -- parte 5/10.
--
-- Financeiro/Pix. SEM os campos de importacao bancaria automatica
-- (banco_origem, chave_importacao, lote_importacao_id,
-- motivo_sem_usuario, tentar_casar_transacao()) -- essa automacao
-- (PagBank) esta' pausada de proposito no CLAUDE.md, nao reativar sem
-- o Leo pedir. Se for reativada um dia, essas colunas entram junto.
--
-- Rode depois do 04_escala_servico.sql.

create table public.contribuicoes (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants (id),
  profile_id uuid references public.profiles (id),
  data date not null,
  horario text,
  valor numeric not null,
  meio_pagamento text not null, -- 'pix' | 'dinheiro' | 'cartao' | 'transferencia' | 'boleto' | 'outro'
  observacao text,
  lancado_por uuid references public.profiles (id),
  evento_id uuid references public.eventos (id), -- pagamento de evento ingressado (opcional)
  tipo text not null default 'oferta', -- texto livre, ex: 'dizimo' | 'oferta' | 'outro'
  criado_em timestamptz not null default now()
);

alter table public.contribuicoes enable row level security;

create trigger trg_definir_tenant_id before insert on public.contribuicoes
  for each row execute function public.definir_tenant_id();

create policy "contribuicoes_select" on public.contribuicoes for select using (
  tenant_id = public.current_tenant_id() and (profile_id = auth.uid() or public.is_admin())
);
create policy "contribuicoes_insert" on public.contribuicoes for insert with check (
  tenant_id = public.current_tenant_id() and public.is_admin()
);
create policy "contribuicoes_update" on public.contribuicoes for update using (
  tenant_id = public.current_tenant_id() and public.is_admin()
);
create policy "contribuicoes_delete" on public.contribuicoes for delete using (
  tenant_id = public.current_tenant_id() and public.is_admin()
);

-- Soma quanto uma pessoa ja' pagou de um evento ingressado (tarja de
-- progresso na tela de Inicio). SECURITY INVOKER (padrao) de proposito:
-- passa pela RLS de select normal (so' ve' o proprio valor, a menos que
-- seja admin).
create or replace function public.total_pago_evento(p_profile_id uuid, p_evento_id uuid) returns numeric
language sql stable as $$
  select coalesce(sum(valor), 0) from public.contribuicoes
  where profile_id = p_profile_id and evento_id = p_evento_id;
$$;

-- ============================================================
-- 06_cuidado_pastoral.sql
-- ============================================================
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

-- ============================================================
-- 07_conteudos.sql
-- ============================================================
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

-- ============================================================
-- 08_outdoors.sql
-- ============================================================
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

-- ============================================================
-- 09_filhos.sql
-- ============================================================
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

-- ============================================================
-- 10_storage_buckets.sql
-- ============================================================
-- Schema curado do motor multi-tenant do e-kko. church -- parte 10/10.
--
-- Buckets de Storage usados pelo app. A protecao real de QUEM PODE VER
-- cada outdoor/material/evento fica na RLS das tabelas correspondentes
-- (08, 07, 03) -- aqui e' so' a permissao de leitura/escrita do arquivo
-- em si, igual ao padrao ja usado na Shallom: buckets publicos (a URL
-- funciona sem token), escrita liberada pra qualquer autenticado,
-- exceto `avatars`, onde cada pessoa so' mexe na propria pasta.
--
-- Rode depois do 09_filhos.sql -- ultimo arquivo do schema base.

insert into storage.buckets (id, name, public)
values
  ('outdoors', 'outdoors', true),
  ('materiais-conteudo', 'materiais-conteudo', true),
  ('eventos-fotos', 'eventos-fotos', true),
  ('avatars', 'avatars', true)
on conflict (id) do nothing;

-- outdoors ------------------------------------------------------------
create policy "outdoors_bucket_select" on storage.objects for select using (bucket_id = 'outdoors');
create policy "outdoors_bucket_insert" on storage.objects for insert with check (bucket_id = 'outdoors' and auth.uid() is not null);
create policy "outdoors_bucket_update" on storage.objects for update using (bucket_id = 'outdoors' and auth.uid() is not null);
create policy "outdoors_bucket_delete" on storage.objects for delete using (bucket_id = 'outdoors' and auth.uid() is not null);

-- materiais-conteudo ----------------------------------------------------
create policy "materiais_bucket_select" on storage.objects for select using (bucket_id = 'materiais-conteudo');
create policy "materiais_bucket_insert" on storage.objects for insert with check (bucket_id = 'materiais-conteudo' and auth.uid() is not null);
create policy "materiais_bucket_update" on storage.objects for update using (bucket_id = 'materiais-conteudo' and auth.uid() is not null);
create policy "materiais_bucket_delete" on storage.objects for delete using (bucket_id = 'materiais-conteudo' and auth.uid() is not null);

-- eventos-fotos ---------------------------------------------------------
create policy "eventos_fotos_bucket_select" on storage.objects for select using (bucket_id = 'eventos-fotos');
create policy "eventos_fotos_bucket_insert" on storage.objects for insert with check (bucket_id = 'eventos-fotos' and auth.uid() is not null);
create policy "eventos_fotos_bucket_update" on storage.objects for update using (bucket_id = 'eventos-fotos' and auth.uid() is not null);
create policy "eventos_fotos_bucket_delete" on storage.objects for delete using (bucket_id = 'eventos-fotos' and auth.uid() is not null);

-- avatars -- cada pessoa so' mexe na propria pasta ($userId/foto.ext) ----
create policy "avatars_bucket_select" on storage.objects for select using (bucket_id = 'avatars');
create policy "avatars_bucket_insert" on storage.objects for insert with check (
  bucket_id = 'avatars' and auth.uid()::text = (storage.foldername(name))[1]
);
create policy "avatars_bucket_update" on storage.objects for update using (
  bucket_id = 'avatars' and auth.uid()::text = (storage.foldername(name))[1]
);
create policy "avatars_bucket_delete" on storage.objects for delete using (
  bucket_id = 'avatars' and auth.uid()::text = (storage.foldername(name))[1]
);

-- ============================================================
-- 11_admin_ekko.sql
-- ============================================================
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

-- ============================================================
-- 12_tenant_segredos.sql
-- ============================================================
-- Schema curado do motor multi-tenant do e-kko. church -- parte 12.
--
-- Segredos por tenant (codigo de lider aqui; credenciais de OneSignal
-- entram em 13_notificacoes.sql) NUNCA ficam na tabela `tenants` -- ela
-- e' publica (`select using (true)`, pra tela de login/splash ler
-- cor/logo sem estar autenticado). Uma tabela separada, SEM nenhuma
-- policy de select/insert/update pra anon/authenticated -- so' funcoes
-- SECURITY DEFINER (rodam como dono da tabela, ignoram RLS) ou o admin
-- da e-kko (via policy explicita, usado pelo painel) mexem aqui.
--
-- Rode depois do 11_admin_ekko.sql.

create table public.tenant_segredos (
  tenant_id uuid primary key references public.tenants (id),
  codigo_lider text
);

alter table public.tenant_segredos enable row level security;

create policy "tenant_segredos_admin_ekko" on public.tenant_segredos for all using (
  public.is_admin_ekko()
) with check (
  public.is_admin_ekko()
);

-- Confirma o codigo de lider (compartilhado pela lideranca da igreja,
-- UM SO' por tenant -- ver campo "Código de líder" em
-- lib/screens/auth/signup_screen.dart) e promove quem chamou a lider
-- NAQUELE ministerio. SECURITY DEFINER porque precisa ler
-- tenant_segredos, que ninguem comum tem select.
create or replace function public.solicitar_papel_lider(p_codigo text, p_ministerio text) returns void
language plpgsql security definer set search_path = public as $$
declare
  v_tenant_id uuid := public.current_tenant_id();
  v_codigo_certo text;
begin
  select codigo_lider into v_codigo_certo
  from public.tenant_segredos
  where tenant_id = v_tenant_id;

  if v_codigo_certo is null or v_codigo_certo <> p_codigo then
    raise exception 'Código de líder inválido.';
  end if;

  insert into public.profile_ministerios (profile_id, tenant_id, ministerio, papel)
  values (auth.uid(), v_tenant_id, p_ministerio, 'lider')
  on conflict (profile_id, ministerio) do update set papel = 'lider';
end;
$$;

-- ============================================================
-- 13_notificacoes.sql
-- ============================================================
-- Schema curado do motor multi-tenant do e-kko. church -- parte 13.
--
-- Notificacao push de "novo evento" (OneSignal). Cada igreja tem seu
-- proprio app OneSignal (mesmo racional do App ID por build -- ver
-- CLAUDE.md), entao as credenciais moram em `tenant_segredos`, uma
-- coluna por tenant -- nunca client-side, nunca na tabela `tenants`
-- (que e' publica).
--
-- ESCOPO DESTA RODADA: so' notificacao de evento novo. Lembretes
-- agendados (24h/3h antes de evento/escala via pg_cron) ficam pra
-- depois -- e' infra em cima de algo que ainda ninguem viu funcionar
-- de verdade (sem OneSignal configurado nem Edge Function publicada
-- ainda nesta maquina).
--
-- BLOQUEIOS MANUAIS (o Leo precisa fazer, nao dá por SQL Editor):
-- 1. Publicar a Edge Function -- ver
--    supabase/functions/send-notification/index.ts (Dashboard -> Edge
--    Functions -> Deploy a new function, colar o codigo).
-- 2. Trocar 'TROQUE_ESTE_SEGREDO_ANTES_DE_USAR' abaixo por um valor
--    aleatorio de verdade (ex: gerado com `openssl rand -hex 32`), E
--    configurar o MESMO valor como secret `NOTIFICACAO_SEGREDO` da
--    Edge Function (Dashboard -> Edge Functions -> send-notification
--    -> Secrets). Os dois lados precisam bater.
-- 3. Criar um app OneSignal por igreja e preencher
--    onesignal_app_id/onesignal_rest_api_key de cada tenant (pelo
--    painel, uma vez a Edge Function estiver publicada).
-- 4. `create extension pg_net` abaixo pode falhar por permissao
--    dependendo do plano/projeto -- se falhar, habilita em Dashboard ->
--    Database -> Extensions -> pg_net, manualmente.
--
-- Rode depois do 12_tenant_segredos.sql.

create extension if not exists pg_net;

alter table public.tenant_segredos add column if not exists onesignal_app_id text;
alter table public.tenant_segredos add column if not exists onesignal_rest_api_key text;

create or replace function public.notificacao_segredo() returns text
language sql immutable as $$
  select 'TROQUE_ESTE_SEGREDO_ANTES_DE_USAR'::text;
$$;

-- Mesma regra generica de visibilidade da RLS de eventos
-- (03_eventos.sql): igreja=todo mundo do tenant, lideranca=qualquer
-- lider, outro escopo=membros daquele ministerio.
create or replace function public.audiencia_evento(p_evento_id uuid) returns uuid[]
language sql stable security definer set search_path = public as $$
  select coalesce(array_agg(p.id), '{}')
  from public.eventos e
  join public.profiles p on p.tenant_id = e.tenant_id
  where e.id = p_evento_id
    and (
      e.escopo = 'igreja'
      or (e.escopo = 'lideranca' and exists (
            select 1 from public.profile_ministerios pm
            where pm.profile_id = p.id and pm.papel = 'lider'))
      or exists (
            select 1 from public.profile_ministerios pm
            where pm.profile_id = p.id and pm.ministerio = e.escopo)
    );
$$;

-- Chama a Edge Function via pg_net (assincrono -- nao trava a
-- transacao que criou o evento esperando resposta da OneSignal).
create or replace function public.notificar(p_tenant_id uuid, p_profile_ids uuid[], p_titulo text, p_corpo text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if p_profile_ids is null or array_length(p_profile_ids, 1) is null then
    return;
  end if;

  perform net.http_post(
    url := 'https://yeimskdsftqkbvpafaxe.supabase.co/functions/v1/send-notification',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || public.notificacao_segredo()
    ),
    body := jsonb_build_object(
      'tenant_id', p_tenant_id,
      'profile_ids', to_jsonb(p_profile_ids),
      'titulo', p_titulo,
      'corpo', p_corpo
    )
  );
end;
$$;

create or replace function public.trigger_notificar_novo_evento() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  perform public.notificar(
    new.tenant_id,
    public.audiencia_evento(new.id),
    'Novo evento: ' || new.titulo,
    coalesce(new.descricao, '')
  );
  return new;
end;
$$;

create trigger trg_notificar_novo_evento
  after insert on public.eventos
  for each row execute function public.trigger_notificar_novo_evento();
