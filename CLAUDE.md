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
   uma vez) aplicado: `tenant_id` + RLS em toda tabela de domínio
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
   - **Acesso anônimo (site público) já preparado** via header
     `x-tenant-slug` (`tenant_id_anonimo()`), fail-closed sem consumidor
     ainda (painel/site público é o próximo passo, ver abaixo).
   - Ver `C:\Users\leona\.claude\plans\twinkling-questing-barto.md` pro
     plano completo dessa rodada.

### O que NÃO existe ainda (bloqueios reais, não esquecimento)

- **`solicitar_papel_lider(codigo, ministerio)`** — RPC chamada por
  `auth_service.dart`, mas o corpo dela nunca foi encontrado em nenhum
  arquivo de referência copiado da Shallom (só existia no `schema.sql`
  original dela, que não foi trazido pra cá). Vai dar erro de função
  inexistente se alguém tentar "virar líder por código" hoje.
- **Notificações push** (triggers, Edge Function `send-notification`,
  OneSignal) — não foram portadas, subsistema separado pra quando o Leo
  pedir.
- **Automação bancária (PagBank)** — continua pausada de propósito (ver
  seção de credenciais acima), não faz parte do schema novo.
- Painel de controle (com a identidade e-kko) — não existe, nem
  esboço. Vai ser HTML/JS simples tipo o `gestao.html` do `awake_app`
  (mesmo padrão: sem build, hospedagem grátis), Fase 0 sem wizard. É
  esse painel que vai, no futuro, editar `tenants.ministerio_primeira_vez`
  e mandar o header `x-tenant-slug` pro acesso anônimo funcionar.
- Ícone/assets do app ainda são literalmente os arquivos da Shallom
  (`shallom_icon_square.png` etc, ver comentário no `pubspec.yaml`) —
  placeholder até existir um jeito de cada tenant subir o próprio logo.
- `profiles.qr_code_id` continua no schema (só pra não quebrar
  `ProfileModel.fromMap`, que ainda lê esse campo como obrigatório) —
  resíduo do check-in por QR Code removido, sem uso real em tela nenhuma
  nova. Se um dia limpar, precisa tirar dos dois lados junto (coluna +
  campo Dart).

## Próximos passos

1. **Painel de controle (identidade e-kko)** — próximo bloco de
   trabalho real. HTML/JS simples (sem build), cadastro manual de
   tenant (Fase 0, sem wizard).
2. Quando fizer sentido: desenhar `solicitar_papel_lider` do zero,
   portar notificações push, e dar uma UI pro admin configurar
   `tenants.ministerio_primeira_vez` (hoje só via SQL direto).

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
