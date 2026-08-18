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
