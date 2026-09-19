-- ဒီ SQL ကို Supabase Dashboard > SQL Editor မှာ Paste လုပ်ပြီး "Run" နှိပ်ပါ
-- (Storage > New bucket > name: delivery-photos > Public: ON ကို အရင်ဖန်တီးပြီးမှ ဒါကို Run ပါ)

drop policy if exists "Admin can upload delivery photos" on storage.objects;
create policy "Admin can upload delivery photos" on storage.objects for insert
  with check (bucket_id = 'delivery-photos' and is_admin());

drop policy if exists "Public can view delivery photos" on storage.objects;
create policy "Public can view delivery photos" on storage.objects for select
  using (bucket_id = 'delivery-photos');
