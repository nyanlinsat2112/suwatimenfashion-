-- အဆင့် ၁ — Bucket ဖန်တီးထားပြီးလား စစ်ပါ (Dashboard ကနေ):
-- Supabase Dashboard → Storage → Bucket List ထဲမှာ "delivery-photos" ရှိမရှိ ကြည့်ပါ
-- မရှိသေးရင် → "New bucket" → Name: delivery-photos → Public bucket: ON → Save

-- အဆင့် ၂ — ဒီ SQL ကို SQL Editor မှာ Run ပါ:
drop policy if exists "Admin can upload delivery photos" on storage.objects;
create policy "Admin can upload delivery photos" on storage.objects for insert
  with check (bucket_id = 'delivery-photos' and is_admin());

drop policy if exists "Public can view delivery photos" on storage.objects;
create policy "Public can view delivery photos" on storage.objects for select
  using (bucket_id = 'delivery-photos');

-- အဆင့် ၃ — Bucket ရှိပြီးသားလည်း "Public" ဖြစ်မဖြစ် ပြန်စစ်ပါ:
-- Storage → delivery-photos ဘေးက "..." menu → Edit bucket → Public bucket: ON ဖြစ်အောင် သေချာစေပါ
