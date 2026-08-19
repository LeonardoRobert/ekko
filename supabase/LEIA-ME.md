# Schema do e-kko. church

Todo o SQL do motor multi-tenant está em `sql/schema/`, numerado na ordem
de execução (`00_tenants.sql`, `01_profiles.sql`, ..., `10_storage_buckets.sql`).
Cole e rode **na ordem**, no SQL Editor de um projeto Supabase novo e
vazio — ou use `sql/schema/completo.sql`, que já é os 11 arquivos juntos
numa tacada só (regenere ele manualmente se editar algum arquivo
individual, concatenando na mesma ordem).

Esses arquivos numerados são a **fonte de verdade** deste projeto — já
validados de ponta a ponta (schema aplicado, app rodando, cadastro
completo testado).

## Onde ficou a referência bruta da Shallom

Este projeto nasceu de uma cópia adaptada do `awake_app` (app real da
Comunidade Batista Shallom). Durante a fase de desenho do schema
multi-tenant, uma cópia bruta e não filtrada do histórico de migrations
de produção da Shallom ficou guardada aqui só como referência de
consulta — ela já foi usada pra montar o `sql/schema/` e **foi removida
deste repo** por ser redundante (o `awake_app` continua existindo como
repositório separado em
`C:\Users\leona\Downloads\awake_app\awake_app`, se precisar consultar
algo específico de lá — ex: corpo de RPCs ainda não portadas, como
`solicitar_papel_lider`).

Lembrete: o sistema antigo "Escala Awake" (`areas_servico`/`escalas`/
`inscricoes`), check-in por QR Code, e Metas mensais **não** fazem parte
do motor genérico — não portar isso pro `sql/schema/` se for consultar o
`awake_app`.
