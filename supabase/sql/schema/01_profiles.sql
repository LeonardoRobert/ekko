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
