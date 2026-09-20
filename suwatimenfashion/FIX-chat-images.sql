-- အဆင့် ၁ — Bucket ဖန်တီးခြင်း (Dashboard ကနေ):
-- Supabase Dashboard → Storage → "New bucket" → Name: chat-images → Public bucket: ON → Save

-- အဆင့် ၂ — ဒီ SQL ကို SQL Editor မှာ Run ပါ:
alter table chat_messages add column if not exists image_url text;

drop policy if exists "Users can upload chat images" on storage.objects;
create policy "Users can upload chat images" on storage.objects for insert
  with check (bucket_id = 'chat-images' and auth.uid() is not null);

drop policy if exists "Public can view chat images" on storage.objects;
create policy "Public can view chat images" on storage.objects for select
  using (bucket_id = 'chat-images');
