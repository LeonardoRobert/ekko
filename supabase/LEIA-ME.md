# SQL de referência (não rodar direto)

Os arquivos em `sql/` são uma cópia **bruta, sem filtro**, das migrations
já rodadas no Supabase de produção da Shallom (`awake_app`). Servem só
como referência de schema/RLS pra montar o banco do `ekko_app` num
**projeto Supabase novo e separado** — nunca aponte esse app pro Supabase
da Shallom.

Importante:
- Tem arquivo aqui que é específico do sistema antigo "Escala Awake"
  (`areas_servico`/`escalas`/`inscricoes`), check-in por QR Code, e Metas
  mensais — tudo isso **saiu** do motor genérico (ver
  `C:\Users\leona\.claude\plans\vivid-snacking-mist.md`). Não rode esses
  arquivos aqui.
- Vários arquivos são correções incrementais em cima de outros (nomes
  tipo `RECUPERACAO_parteX`, `2026_*`) — não são um schema limpo e
  ordenado, é o histórico real de como o banco da Shallom foi evoluindo.
- Antes de rodar qualquer coisa num projeto novo, cure a lista a dedo:
  mantenha o que cria/altera tabelas genéricas (eventos, escalas_servico,
  contribuicoes, profiles, outdoors, visitantes_primeira_vez, mensagens,
  questionarios, video_materiais, treinamentos, storage buckets) e ignore
  o que menciona shift/checkin/metas/areas_servico/inscricoes.
- Este projeto ainda não tem schema próprio criado -- essa curadoria é
  trabalho de uma fase futura (junto com a tabela `tenants` e RLS
  multi-tenant), não desta rodada de scaffold.
