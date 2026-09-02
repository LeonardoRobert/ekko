# e-kko. church — Contexto do projeto

Este arquivo é lido automaticamente pelo Claude Code toda vez que este
projeto é aberto. Ele existe pra você (Claude Code) entender o projeto
inteiro ANTES de mexer em qualquer coisa — sem precisar que o Leo (dono
do projeto) explique tudo de novo.

## 🚨 Regra mais importante de todas

**Faça SOMENTE o que foi pedido, e nada além disso.**

- Se o Leo pedir uma correção pequena, mude só o necessário — não
  aproveite pra "melhorar", refatorar, reorganizar imports, trocar
  nomes de variável, ou mexer em qualquer outro trecho fora do pedido.
- Nunca reescreva um arquivo inteiro quando um edit cirúrgico resolve.
- Se perceber algo que parece bug ou melhoria óbvia **fora** do que foi
  pedido, avise o Leo e pergunte antes — não corrija por conta própria.
- Antes de editar um arquivo, leia o conteúdo atual dele primeiro.
- Depois de editar, confirme que chaves/parênteses fecham certo, e rode
  `flutter analyze` antes de considerar terminado.
- Commit/push só quando o Leo pedir ou quando fizer sentido óbvio pelo
  padrão já estabelecido nas conversas anteriores (ver histórico do
  `git log` deste repo pra ver o tom dos commits já feitos).

## O que é este projeto

**e-kko. church** é o primeiro produto vertical da **e-kko**, uma
empresa de tecnologia que o Leo está começando ("para servir quem
serve") — uma plataforma que produtiza o que ele já construiu de
verdade e em produção pra Comunidade Batista Shallom (repo separado,
`awake_app`, veja abaixo) e vende configurado pra outras igrejas.

Leo é **sócio único, com pouco orçamento no início**. Toda decisão de
arquitetura aqui foi tomada otimizando por: **escalar rápido, custo
baixo, manutenção fácil** — nessa ordem de prioridade. Não sugira nada
que exija investimento alto ou equipe maior sem ele pedir.

### Relação com o `awake_app` (Shallom)

Este projeto **nasceu de uma cópia adaptada** do `awake_app`
(`c:\Users\leona\Downloads\awake_app\awake_app`, se existir nesta
máquina) — o app real da Comunidade Batista Shallom, em produção. É um
repositório git **completamente separado**, numa pasta separada.

- **Nunca edite nada dentro de `awake_app`** a partir desta sessão —
  ele é um app de produção real, de outra pessoa/contexto (a igreja),
  e mexer nele por engano quebra algo que está no ar de verdade.
- Pode ler o `awake_app` como referência (ele tem soluções já
  testadas: Pix/EMV/CRC16, parsing de data sem fuso, padrões de RLS)
  se precisar entender como algo funcionava lá antes de portar aqui.
- O plano original do scaffold (o que foi copiado, o que foi removido,
  por quê) está em `C:\Users\leona\.claude\plans\vivid-snacking-mist.md`
  — esse caminho é do usuário (fora deste repo), deve continuar
  acessível de qualquer projeto nesta máquina.

### Novidades do `awake_app` desde 19/08 (sincronizado em 24/08)

A sessão do `awake_app` continuou recebendo pedidos reais da igreja
depois do scaffold deste projeto ter sido cortado dele. Nada disso foi
portado pra cá automaticamente — é só um resumo do que mudou lá, pra
avaliar caso a caso se vale trazer pro motor genérico depois. Também
não modifiquei nada abaixo, é puramente informativo.

**Padrões genéricos que podem valer a pena portar pro motor:**

- **Contagem manual de presença** (`contagem_manual_eventos` +
  `ajustar_contagem_evento`/`definir_contagem_evento`, e uma tela
  "Contador de evento" no app: escolhe o evento de hoje, mexe num
  número local com +/-, manda tudo de uma vez só num botão "Enviar").
  Resolve o caso de eventos grandes/gerais (tipo um culto de
  celebração) onde não dá pra escanear QR Code de todo mundo, mas
  ainda se quer um número de presença pro painel. Ideia genuinamente
  reaproveitável pra qualquer igreja cliente, não é específico da
  Shallom.
- **"Não contabilizado" em vez de apagar ocorrência** (atualização de
  24/08): no painel da Shallom, o botão que antes apagava uma
  ocorrência de evento (`excluir_ocorrencia_evento`) virou um toggle
  "Não contabilizado" — o evento continua na lista (visualmente meio
  apagado, com um badge cinza), mas sai do total/média do dashboard.
  Mesma coluna `nao_contabilizado` (boolean) na tabela de contagem
  serve pra isso, e uma função nova (`definir_nao_contabilizado_evento`)
  cuida do toggle, checando `is_admin()`. Vale mais a pena que apagar
  de verdade porque preserva histórico (ex: evento cancelado de última
  hora, mas que ainda aconteceu parcialmente) sem sumir com o registro.
- **Retry automático em erro `PGRST303` ("JWT issued at future")** —
  `awake_app/lib/core/cliente_http_retentativa_sessao.dart`: um
  `http.Client` customizado passado no `Supabase.initialize(httpClient:
  ...)` que detecta esse erro (relógio da infra do Supabase
  dessincronizado, comum logo após o projeto acordar de hibernação),
  renova a sessão e repete a requisição sozinho. Corta a necessidade da
  pessoa fechar/abrir o app manualmente. Vale portar pro `main.dart`
  deste projeto quando o app estiver rodando de verdade contra o
  Supabase da e-kko.
- **Editar/Apagar em listas administrativas do painel** — padrão
  consolidado no `gestao.html` da Shallom (modal compartilhado
  `#fundo-modal`/`#caixa-modal`, botões `.link-acao`/`.link-acao-perigo`
  inline em cada linha) pra Visitantes e pros eventos das novas abas
  Awake/Shallom. Referência de UI pronta pro `docs/painel.html` daqui
  quando ele precisar de telas de lista com edição inline.

**Armadilhas genéricas aprendidas (aplicam a qualquer projeto
Supabase/PostgREST, não só à Shallom):**

- **Embed ambíguo do PostgREST**: se uma tabela tem MAIS DE UMA foreign
  key pra `profiles` (ex: `user_id` e `feito_por`, ou `registrado_por` e
  `acompanhado_por`), um `select('*, profiles(nome)')` sem qualificar
  passa a ser rejeitado assim que a segunda FK é criada — precisa
  `profiles!nome_da_fk(nome)`. Isso já quebrou 2 telas na Shallom
  silenciosamente (o erro era escondido por um fallback de "lista
  vazia"). Neste projeto, `profile_id`/`criado_por`/`atualizado_por`
  já aparecem em várias tabelas do schema — vale conferir se algum
  `select` com embed pra `profiles` vai ter esse problema conforme mais
  FKs forem adicionadas.
- **SQL Editor do Supabase tem um "assistente" que às vezes cola um
  bloco `ALTER TABLE ... ENABLE ROW LEVEL SECURITY` sozinho** dentro de
  uma função `plpgsql`, confundindo variável declarada (`v_algumacoisa`)
  com tabela nova — quebra o fechamento do delimitador `$$`. Usar
  `$func$` (ou qualquer delimitador que não seja `$$`) evita o problema
  por completo. Vale adotar como padrão em todo SQL novo deste projeto.
- **Múltiplas definições da mesma função/policy em arquivos SQL soltos
  causam regressão silenciosa** — se o arquivo antigo for colado de
  novo por engano, `create or replace` apaga a correção mais nova sem
  aviso nenhum. Esse projeto já tem a defesa estrutural certa pra isso
  (schema numerado em `supabase/sql/schema/`, fonte única de verdade,
  ver `supabase/LEIA-ME.md`) — a experiência da Shallom só confirma que
  vale manter essa disciplina á risca conforme o schema for evoluindo
  (nunca ter um `2026_algo.sql` solto redefinindo algo que já está no
  schema numerado).
- **Cuidado com "hoje"/"ontem" calculado no fuso errado.** Um teste
  automatizado da Shallom (CI roda em UTC) calculava "ontem" no fuso do
  servidor, enquanto a função do banco calculava "hoje" em
  `America/Sao_Paulo` — dava falso positivo numa janela de ~3h por dia.
  Aqui isso é mais sério ainda: sendo multi-tenant de verdade, futuras
  igrejas clientes podem estar em fusos diferentes — vale já nascer
  pensando em "hoje" como algo configurável por tenant (ou pelo menos
  documentado/explícito), não hardcoded num fuso só.

**Específico da Shallom/Awake, não portar:** líder poder escalar
manualmente um membro que não se inscreveu sozinho (sistema Escala
Awake, que já não existe aqui), aba "Awake" do gestão com check-in
individual por QR Code (idem), reformatação do texto de WhatsApp da
Escala de Serviço (`*Escala Semanal da X*` com marcadores em negrito —
cosmético, específico da voz da Shallom, mas fácil de copiar se algum
tenant pedir algo parecido).

## Arquitetura — decisões já fechadas (não re-discutir do zero)

- **Um único código-fonte multi-tenant**, NÃO Flutter flavors. Cada
  igreja cliente é uma linha na tabela `tenants` (cores, logo, módulos
  ativos), resolvida por um slug definido em tempo de build
  (`--dart-define=TENANT_SLUG=nomedaigreja`, ver `lib/core/env.dart`).
- **Um projeto Supabase só**, compartilhado entre todas as igrejas —
  não um projeto por cliente. Isolamento de dado é via `tenant_id` +
  RLS (ainda não implementado nas tabelas de dado, só na tabela
  `tenants` em si — ver "Estado atual" abaixo).
- **Módulos ligados/desligados por config** (`tenant.modulosAtivos`,
  lido em runtime), não por variante de build.
- **Apesar do código ser um só, cada igreja ainda tem um BUILD/app
  dedicado** (ícone e nome próprios) — porque a Apple (guideline 4.2.6)
  proíbe uma conta de desenvolvedor só publicando N apps quase
  idênticos ("template apps"). Reconciliação: mesmo código-fonte,
  compilado uma vez por igreja (`TENANT_SLUG` diferente por build),
  cada uma com sua própria conta de desenvolvedor (Google Play US$25
  único, Apple US$99/ano — **custo repassado na mensalidade da
  igreja**, não é custo do Leo). Leo entra como colaborador/admin na
  conta de cada cliente pra publicar.
- **Identidade visual da e-kko** (preto/branco + amarelo-limão
  `#E2FF0C` + roxo `#6A03FF`; Helvetica Now Display + IBM Plex Serif
  itálico + Monoist mono; tagline "para servir quem serve") é **só do
  painel de controle** que o Leo vai usar pra gerenciar as igrejas —
  **NUNCA** aplique essa identidade dentro do app que uma igreja usa.
  Cada app gerado usa a marca daquela igreja (nome, cores, logo
  próprios, vindos da tabela `tenants`), a e-kko fica invisível pro
  fiel final.
- **Onboarding de igreja nova, Fase 0: manual.** Leo cadastra a igreja
  direto (insert na tabela `tenants` + upload de assets) — SEM
  wizard/gerador automático. Só vale automatizar esse fluxo quando o
  volume de clientes justificar (não construa isso agora, mesmo que
  pareça óbvio — decisão explícita, já discutida).

## O que foi removido do `awake_app` original (não trazer de volta)

O `awake_app` tem um sistema de voluntariado antigo específico do
ministério Awake que **não faz parte do motor genérico**:

- "Escala Awake" (tabelas `areas_servico`/`escalas`/`inscricoes`,
  diferente da Escala de Serviço genérica que ficou)
- Check-in por QR Code (achar isso escondido é comum — rotas tipo
  `/checkin`/`/meu-qrcode` são STRINGS pro go_router, então referência
  morta a elas não aparece no `flutter analyze`; se for procurar
  resíduo, faça `grep` pelo literal também, não só por nome de
  classe/arquivo)
- Metas mensais (gamificação/troféus)

Se for consultar o `awake_app` (repo separado) como referência de algo
que falta aqui, mencionando essas três coisas, **não porte pra cá**.

## O que ficou (motor genérico, reaproveitado)

Calendário completo (com Outdoors — banners rotativos), Escala de
Serviço genérica (Diáconos/Louvor/Dança/Mídia/Multimídia/Coral — e
Recepção pode entrar do mesmo jeito, é só mais um valor no catálogo),
Financeiro/Pix, cuidado pastoral (pedidos de oração, testemunhos,
visitantes/Primeira Vez, questionário de novo servo), Nossos Conteúdos
(vídeos + materiais anexados), Filhos (cadastro de crianças dos
membros), Treinamentos.

### Formulário de Primeira Vez — generalizado

O antigo `esta_na_escala_primeira_vez()` (que dependia do sistema Escala
Awake removido) foi substituído por `pode_registrar_primeira_vez()`
(`supabase/sql/schema/06_cuidado_pastoral.sql`): configurável por
tenant via `tenants.ministerio_primeira_vez` (nullable) — a pessoa
escalada **hoje** naquele ministério de Escala de Serviço genérica pode
registrar visitante. Enquanto um tenant não configurar essa coluna, só
admin registra. Nenhuma tela/admin ainda mexe nesse campo — hoje só dá
pra configurar via SQL direto (`update tenants set
ministerio_primeira_vez = '...'`).

## Estado atual (2026-08-19)

`flutter analyze` limpo (zero erros) em todos os commits até agora:

1. **Scaffold inicial** — copiado do `awake_app`, removendo o sistema
   Escala Awake/check-in/metas (models, services, providers, telas,
   rotas correspondentes).
2. **Tenant + tema dinâmico** — tabela `tenants` criada.
   `TenantModel`/`TenantService`/`tenantAtualProvider` carregam a
   igreja do build (via `Env.tenantSlug`) ANTES de montar o app de
   verdade — `main.dart` tem estados de loading/erro próprios pra isso.
   `AppTheme` trocou `ehAwake: bool` por `corPrimaria/corDestaque: Color`
   vindos do tenant. `home_shell.dart`: as abas do meio (Calendário/
   Conteúdos/Contribua) são montadas a partir de `tenant.modulosAtivos`.
3. **Schema multi-tenant completo, validado de ponta a ponta.** Existe
   um projeto Supabase real (não é mais placeholder) com
   `supabase/sql/schema/` (00→10, ou `completo.sql` pra rodar tudo de
   uma vez, na época) aplicado: `tenant_id` + RLS em toda tabela de domínio
   (preenchido sozinho via trigger `definir_tenant_id()`, services Dart
   não precisam mandar `tenant_id`). Cadastro completo testado no app
   rodando (`flutter run -d chrome`) contra esse projeto — perfil e
   vínculo de ministério gravados com `tenant_id` correto. Decisões de
   genericidade tomadas nessa rodada (não re-discutir):
   - **2 papéis** (`membro`/`admin`), sem `admin_financeiro` separado.
   - **Sem enum fixo** em `ministerio`/`escopo`/`tipo` de evento — cada
     igreja configura os próprios (a Shallom trava em valores fixos
     tipo `ebd`/`awake`/`coral`, isso é convenção dela, não do motor).
   - **Sem `categoria` (Genesis/Next/One) nem `grupo_casais` calculados
     automaticamente** — eram lógica específica da Shallom/Awake;
     viraram campos de texto livre sem trigger.
   - **Visibilidade de eventos/outdoors por escopo simplificada**:
     `igreja`=todo mundo do tenant, `lideranca`=qualquer líder, outro
     escopo=quem está no `profile_ministerios` daquele nome. As regras
     antigas por idade/gênero/estado civil da Shallom não foram
     portadas (colunas ficam no schema pra compatibilidade, sem uso).
   - **Acesso anônimo (site público de igreja)** já preparado via
     header `x-tenant-slug` (`tenant_id_anonimo()`), fail-closed —
     ainda sem consumidor (isso é o *site* público de cada igreja, uma
     página diferente do painel de controle abaixo).
   - Ver `C:\Users\leona\.claude\plans\twinkling-questing-barto.md` pro
     plano completo dessa rodada.
4. **Painel de controle v1 + `solicitar_papel_lider` + notificação de
   evento novo.** Ver seções próprias abaixo (Painel de controle,
   `solicitar_papel_lider`, Notificações push) — schema agora vai até
   `13_notificacoes.sql`.

## Painel de controle (identidade e-kko)

`docs/painel.html` — HTML/JS puro, sem build, publicado via GitHub
Pages (`docs/` na branch `master` — este repo não tem branch `main`).
Login via Supabase Auth, gate de acesso por `is_admin_ekko()` (lista
fixa de e-mail no SQL, Fase 0 — ver `supabase/sql/schema/11_admin_ekko.sql`).
Lista as igrejas e edita cores/logo/módulos ativos/
`ministerio_primeira_vez`/código de líder/credenciais OneSignal de cada
uma. **Cadastro de igreja nova continua manual via SQL** (Fase 0,
decisão já tomada) — o painel edita, não cria.

### Segredos por tenant

`tenant_segredos` (`supabase/sql/schema/12_tenant_segredos.sql`) —
tabela **sem nenhuma policy de leitura pra anon/authenticated**, só
`is_admin_ekko()` (via painel) ou funções `security definer` mexem
nela. Guarda `codigo_lider` (um código único por igreja, que a
liderança compartilha — ver campo em `signup_screen.dart`) e as
credenciais OneSignal (`onesignal_app_id`/`onesignal_rest_api_key`) de
cada tenant. Nunca colocar segredo na tabela `tenants` — ela é pública
(`select using (true)`, pra tela de login ler cor/logo sem estar
autenticado).

## `solicitar_papel_lider` — implementado

`supabase/sql/schema/12_tenant_segredos.sql` — confere o código contra
`tenant_segredos.codigo_lider` do próprio tenant do usuário e promove a
`lider` no `profile_ministerios`. Mesma assinatura que
`auth_service.dart` já chamava (a RPC só estava sem corpo desde o
scaffold inicial).

## Notificações push — parcial

`supabase/sql/schema/13_notificacoes.sql` +
`supabase/functions/send-notification/index.ts`. **Implementado**:
notificação de evento novo (`trg_notificar_novo_evento`), audiência
calculada com a mesma regra genérica de visibilidade da RLS de eventos.
**NÃO implementado ainda**: lembretes agendados (24h/3h antes de
evento/escala via `pg_cron`) — decisão deliberada de não empilhar mais
infra em cima de algo que ainda não foi visto funcionando de verdade
nesta máquina (sem CLI do Supabase pra dar deploy, sem OneSignal
configurado, sem teste real de envio).

**Bloqueios manuais** (o Leo precisa fazer, não dá por código):
1. Publicar a Edge Function (Dashboard → Edge Functions → colar
   `index.ts`) — não tem Supabase CLI nesta máquina.
2. Trocar o segredo hardcoded em `notificacao_segredo()` (SQL) por um
   valor de verdade, e configurar o mesmo valor como secret
   `NOTIFICACAO_SEGREDO` da Edge Function.
3. Criar um app OneSignal por igreja e preencher as credenciais pelo
   painel.
4. Confirmar que a extensão `pg_net` habilitou certo (o `create
   extension` pode falhar por permissão dependendo do projeto).

## Automação bancária (PagBank) — continua pausada

Ver seção de credenciais no topo deste arquivo — **não reative sem
pedido explícito**, mesmo que outro pedido pareça abranger "tudo".

## Próximos passos

1. Bloqueios manuais de notificações push (lista acima).
2. Lembretes agendados (pg_cron), só depois de validar que a
   notificação de evento novo está funcionando de ponta a ponta.
3. Ícone/assets do app ainda são os da Shallom
   (`shallom_icon_square.png` etc, ver comentário no `pubspec.yaml`) —
   placeholder até existir um jeito de cada tenant subir o próprio
   logo.
4. `profiles.qr_code_id` — resíduo do check-in por QR Code removido,
   mantido só pra não quebrar `ProfileModel.fromMap` (lê esse campo
   como obrigatório). Limpar coluna + campo Dart juntos, se um dia
   fizer sentido.

## Convenções de código (herdadas do `awake_app`, mantidas aqui)

- Idioma: tudo em português (variáveis, classes, comentários, strings
  de UI).
- Nomenclatura de banco: snake_case (Postgres) ↔ camelCase (Dart), via
  `fromMap`/`toInsertMap`.
- RLS é a fonte de verdade de permissão — telas escondem botão, mas a
  proteção real é a policy do banco.
- `dart:async`/`http`/Riverpod/go_router/Supabase — mesmos pacotes e
  padrões do `awake_app`; ver `pubspec.yaml` deste repo pra lista
  exata (alguns pacotes específicos do sistema removido, como
  `mobile_scanner`, foram tirados; `qr_flutter` ficou — é usado pelo
  Pix, não só pelo check-in que saiu).
