-- =====================================================================
-- ▮ PRODUCT-BARCODE.sql — ပစ္စည်းပေါ်က Barcode သိမ်းဖို့ ကော်လံ
--   Supabase → SQL Editor → Paste → Run  (ထပ် Run လည်း ဘေးမရှိ · ဘာမှ မဖျက်ပါ)
-- =====================================================================
alter table public.products add column if not exists barcode text;

-- Barcode တူ ၂ ခု မဖြစ်အောင် (အလွတ်ဆိုရင် ကန့်သတ်မထား)
create unique index if not exists products_barcode_uniq
  on public.products (barcode)
  where barcode is not null and barcode <> '';

-- စစ်ရန် — Barcode ရှိ/မရှိ အရေအတွက်
select count(*) filter (where barcode is not null and barcode <> '') as barcode_ရှိ,
       count(*) filter (where barcode is null or barcode = '')       as barcode_မရှိ
  from public.products;
