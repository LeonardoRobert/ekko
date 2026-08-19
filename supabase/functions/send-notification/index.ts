// Edge Function: send-notification
//
// Recebe {tenant_id, profile_ids, titulo, corpo}, busca as credenciais
// OneSignal daquela igreja em tenant_segredos (nunca client-side -- a
// REST API key da OneSignal e' secreta) e manda o push via API da
// OneSignal, mirando os usuarios por external_user_id (= profiles.id,
// ver NotificationService.loginUser() no app -- OneSignal.login(userId)).
//
// So' e' chamada de dentro do banco (trigger via pg_net, ver
// supabase/sql/schema/13_notificacoes.sql), nunca direto do app --
// confere um segredo compartilhado no header Authorization (nao e' o
// JWT de usuario nenhum).
//
// DEPLOY MANUAL (sem Supabase CLI nesta maquina):
//   Dashboard -> Edge Functions -> Deploy a new function -> nome
//   "send-notification" -> cola o conteudo deste arquivo.
//   Depois, em Edge Functions -> send-notification -> Secrets, define
//   NOTIFICACAO_SEGREDO com o MESMO valor que voce colocar na funcao
//   notificacao_segredo() do banco (13_notificacoes.sql).

import { serve } from "https://deno.land/std@0.192.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const NOTIFICACAO_SEGREDO = Deno.env.get("NOTIFICACAO_SEGREDO") ?? "";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

serve(async (req: Request) => {
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Método não permitido." }), { status: 405 });
  }

  const auth = req.headers.get("Authorization") ?? "";
  if (!NOTIFICACAO_SEGREDO || auth !== `Bearer ${NOTIFICACAO_SEGREDO}`) {
    return new Response(JSON.stringify({ error: "Não autorizado." }), { status: 401 });
  }

  let corpoRequisicao: { tenant_id?: string; profile_ids?: string[]; titulo?: string; corpo?: string };
  try {
    corpoRequisicao = await req.json();
  } catch {
    return new Response(JSON.stringify({ error: "JSON inválido." }), { status: 400 });
  }

  const { tenant_id, profile_ids, titulo, corpo } = corpoRequisicao;
  if (!tenant_id || !Array.isArray(profile_ids) || profile_ids.length === 0 || !titulo) {
    return new Response(JSON.stringify({ error: "Parâmetros inválidos." }), { status: 400 });
  }

  const supabaseAdmin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

  const { data: segredo, error } = await supabaseAdmin
    .from("tenant_segredos")
    .select("onesignal_app_id, onesignal_rest_api_key")
    .eq("tenant_id", tenant_id)
    .maybeSingle();

  if (error) {
    return new Response(JSON.stringify({ error: "Erro ao buscar credenciais do tenant." }), { status: 500 });
  }

  if (!segredo?.onesignal_app_id || !segredo?.onesignal_rest_api_key) {
    // Igreja ainda sem OneSignal configurado -- nao e' erro, so' nao
    // manda nada (evita que toda igreja nova quebre o fluxo de criar
    // evento so' porque ainda nao tem push configurado).
    return new Response(JSON.stringify({ ignorado: true, motivo: "tenant sem OneSignal configurado" }), { status: 200 });
  }

  const respostaOneSignal = await fetch("https://onesignal.com/api/v1/notifications", {
    method: "POST",
    headers: {
      "Content-Type": "application/json; charset=utf-8",
      "Authorization": `Basic ${segredo.onesignal_rest_api_key}`,
    },
    body: JSON.stringify({
      app_id: segredo.onesignal_app_id,
      include_external_user_ids: profile_ids,
      headings: { en: titulo, pt: titulo },
      contents: { en: corpo ?? "", pt: corpo ?? "" },
    }),
  });

  const resultado = await respostaOneSignal.json();
  return new Response(JSON.stringify(resultado), {
    status: respostaOneSignal.ok ? 200 : 502,
    headers: { "Content-Type": "application/json" },
  });
});
