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
