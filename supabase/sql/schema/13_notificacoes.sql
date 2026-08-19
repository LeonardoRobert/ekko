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
