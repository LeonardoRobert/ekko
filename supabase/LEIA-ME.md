# SQL: schema curado vs. referência bruta

## `sql/schema/` — rode isto num projeto Supabase NOVO

Schema limpo e curado do motor multi-tenant, com `tenant_id` + RLS em
toda tabela. Arquivos numerados (`01_profiles.sql`, `02_...`, ...) —
cole e rode **na ordem**, no SQL Editor do projeto novo. `00_tenants.sql`
(na raiz de `sql/`, fora da pasta `schema/`) precisa rodar antes de tudo,
é o único arquivo curado que já existia antes desse schema.

## `sql/` (raiz, os outros ~50 arquivos) — referência bruta, não rodar direto

O resto dos arquivos em `sql/` é uma cópia **bruta, sem filtro**, das
migrations já rodadas no Supabase de produção da Shallom (`awake_app`).
Servem só como referência histórica de como cada tabela/policy foi
desenhada lá — nunca aponte o `ekko_app` pro Supabase da Shallom.

Importante:
- Tem arquivo aqui que é específico do sistema antigo "Escala Awake"
  (`areas_servico`/`escalas`/`inscricoes`), check-in por QR Code, e Metas
  mensais — tudo isso **saiu** do motor genérico (ver
  `C:\Users\leona\.claude\plans\vivid-snacking-mist.md`) e **não** foi
  portado pro `sql/schema/`. Não rode esses arquivos.
- Vários arquivos são correções incrementais em cima de outros (nomes
  tipo `RECUPERACAO_parteX`, `2026_*`) — não são um schema limpo e
  ordenado, é o histórico real de como o banco da Shallom foi evoluindo.
- O `sql/schema/` já fez essa curadoria (juntando `CREATE TABLE` +
  `ALTER TABLE` + `CREATE POLICY` mais recentes de cada tabela, tirando
  o que é específico da Shallom/QA) — normalmente não há mais motivo pra
  ler os arquivos brutos, exceto pra investigar uma decisão antiga de
  RLS/schema que o `sql/schema/` não cobre.
