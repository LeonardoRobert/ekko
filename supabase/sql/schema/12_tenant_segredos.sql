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
