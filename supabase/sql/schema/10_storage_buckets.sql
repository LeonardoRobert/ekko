-- Schema curado do motor multi-tenant do e-kko. church -- parte 10/10.
--
-- Buckets de Storage usados pelo app. A protecao real de QUEM PODE VER
-- cada outdoor/material/evento fica na RLS das tabelas correspondentes
-- (08, 07, 03) -- aqui e' so' a permissao de leitura/escrita do arquivo
-- em si, igual ao padrao ja usado na Shallom: buckets publicos (a URL
-- funciona sem token), escrita liberada pra qualquer autenticado,
-- exceto `avatars`, onde cada pessoa so' mexe na propria pasta.
--
-- Rode depois do 09_filhos.sql -- ultimo arquivo do schema base.

insert into storage.buckets (id, name, public)
values
  ('outdoors', 'outdoors', true),
  ('materiais-conteudo', 'materiais-conteudo', true),
  ('eventos-fotos', 'eventos-fotos', true),
  ('avatars', 'avatars', true)
on conflict (id) do nothing;

-- outdoors ------------------------------------------------------------
create policy "outdoors_bucket_select" on storage.objects for select using (bucket_id = 'outdoors');
create policy "outdoors_bucket_insert" on storage.objects for insert with check (bucket_id = 'outdoors' and auth.uid() is not null);
create policy "outdoors_bucket_update" on storage.objects for update using (bucket_id = 'outdoors' and auth.uid() is not null);
create policy "outdoors_bucket_delete" on storage.objects for delete using (bucket_id = 'outdoors' and auth.uid() is not null);

-- materiais-conteudo ----------------------------------------------------
create policy "materiais_bucket_select" on storage.objects for select using (bucket_id = 'materiais-conteudo');
create policy "materiais_bucket_insert" on storage.objects for insert with check (bucket_id = 'materiais-conteudo' and auth.uid() is not null);
create policy "materiais_bucket_update" on storage.objects for update using (bucket_id = 'materiais-conteudo' and auth.uid() is not null);
create policy "materiais_bucket_delete" on storage.objects for delete using (bucket_id = 'materiais-conteudo' and auth.uid() is not null);

-- eventos-fotos ---------------------------------------------------------
create policy "eventos_fotos_bucket_select" on storage.objects for select using (bucket_id = 'eventos-fotos');
create policy "eventos_fotos_bucket_insert" on storage.objects for insert with check (bucket_id = 'eventos-fotos' and auth.uid() is not null);
create policy "eventos_fotos_bucket_update" on storage.objects for update using (bucket_id = 'eventos-fotos' and auth.uid() is not null);
create policy "eventos_fotos_bucket_delete" on storage.objects for delete using (bucket_id = 'eventos-fotos' and auth.uid() is not null);

-- avatars -- cada pessoa so' mexe na propria pasta ($userId/foto.ext) ----
create policy "avatars_bucket_select" on storage.objects for select using (bucket_id = 'avatars');
create policy "avatars_bucket_insert" on storage.objects for insert with check (
  bucket_id = 'avatars' and auth.uid()::text = (storage.foldername(name))[1]
);
create policy "avatars_bucket_update" on storage.objects for update using (
  bucket_id = 'avatars' and auth.uid()::text = (storage.foldername(name))[1]
);
create policy "avatars_bucket_delete" on storage.objects for delete using (
  bucket_id = 'avatars' and auth.uid()::text = (storage.foldername(name))[1]
);
