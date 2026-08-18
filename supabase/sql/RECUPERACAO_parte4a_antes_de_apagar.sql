-- Roda ISSO ANTES de apagar qualquer usuario em Authentication > Users.
--
-- 1) Guarda id antigo + nome dos 4 usuarios reais numa tabela
--    temporaria -- vai ser usada depois pra reconectar tudo.
create table if not exists public.profiles_backup_incidente (
  id_antigo uuid primary key,
  nome text not null
);

insert into public.profiles_backup_incidente (id_antigo, nome)
select id, nome from public.profiles where not eh_conta_teste
on conflict (id_antigo) do nothing;

select * from public.profiles_backup_incidente;

-- 2) Destrava as FKs que impedem apagar o usuario (senao o Supabase
--    falha com "Database error deleting user" ao tentar cascatear).
--    As linhas em si NAO sao apagadas -- so ficam "soltas" (com um
--    profile_id que nao existe mais) ate a parte 4b reconectar.
alter table public.profile_ministerios drop constraint if exists profile_ministerios_profile_id_fkey;
alter table public.escala_servico_posicoes drop constraint if exists escala_servico_posicoes_profile_id_fkey;
alter table public.escala_servico_posicoes drop constraint if exists escala_servico_posicoes_profile_id_2_fkey;
alter table public.escala_servico_casais drop constraint if exists escala_servico_casais_profile_id_a_fkey;
alter table public.escala_servico_casais drop constraint if exists escala_servico_casais_profile_id_b_fkey;
alter table public.escala_servico_casais drop constraint if exists escala_servico_casais_criado_por_fkey;
alter table public.escalas_servico drop constraint if exists escalas_servico_criado_por_fkey;
alter table public.contribuicoes drop constraint if exists contribuicoes_profile_id_fkey;
alter table public.contribuicoes drop constraint if exists contribuicoes_lancado_por_fkey;
alter table public.pedidos_oracao drop constraint if exists pedidos_oracao_profile_id_fkey;
alter table public.testemunhos drop constraint if exists testemunhos_profile_id_fkey;
alter table public.filhos drop constraint if exists filhos_responsavel_id_fkey;
alter table public.visitantes_primeira_vez drop constraint if exists visitantes_primeira_vez_registrado_por_fkey;
alter table public.transacoes_bancarias drop constraint if exists transacoes_bancarias_profile_id_fkey;
alter table public.presencas_eventos drop constraint if exists presencas_eventos_user_id_fkey;
alter table public.presencas_eventos drop constraint if exists presencas_eventos_feito_por_fkey;

select 'Pode apagar os usuarios agora em Authentication > Users.' as status;
