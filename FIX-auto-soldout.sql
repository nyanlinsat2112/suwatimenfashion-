-- =====================================================================
-- 🔧 FIX: Stock 0 ဖြစ်ရင် Auto "SOLD OUT"၊ Stock ပြန်ဖြည့်ရင် Auto "Available"
-- Size/အရောင်အလိုက် Stock (variant_stock / color_stock) ကနေ စုစုပေါင်း Stock ကို အမြဲ ပြန်တွက်ပေးသည်
-- (ယခင်က Size တိုင်း 0 ဖြစ်နေလည်း စုစုပေါင်း ဂဏန်း မကိုက်ညီရင် Sold Out မပြောင်းခဲ့ပါ)
-- =====================================================================
create or replace function products_sync_stock()
returns trigger as $$
declare
  total int;
begin
  if new.variant_stock is not null and jsonb_typeof(new.variant_stock) = 'object' and new.variant_stock <> '{}'::jsonb then
    select coalesce(sum(case when (c.value #>> '{}') ~ '^-?[0-9]+$' then greatest((c.value #>> '{}')::int, 0) else 0 end), 0)
      into total
      from jsonb_each(new.variant_stock) s,
           jsonb_each(case when jsonb_typeof(s.value) = 'object' then s.value else '{}'::jsonb end) c;
    new.stock_qty := total;
  elsif new.color_stock is not null and jsonb_typeof(new.color_stock) = 'object' and new.color_stock <> '{}'::jsonb then
    select coalesce(sum(case when (c.value #>> '{}') ~ '^-?[0-9]+$' then greatest((c.value #>> '{}')::int, 0) else 0 end), 0)
      into total from jsonb_each(new.color_stock) c;
    new.stock_qty := total;
  end if;

  if coalesce(new.stock_qty, 0) <= 0 then
    new.status := 'sold_out';
  elsif tg_op = 'UPDATE' and coalesce(old.stock_qty, 0) <= 0 and new.status = 'sold_out' then
    new.status := 'available';   -- Stock ပြန်ဖြည့်လိုက်ရင် Auto ပြန်ရောင်းလို့ရ
  end if;
  return new;
end;
$$ language plpgsql;

drop trigger if exists trg_products_sync_stock on products;
create trigger trg_products_sync_stock before insert or update on products
  for each row execute function products_sync_stock();

-- ရှိပြီးသား ပစ္စည်းအားလုံးကို တစ်ခါ ပြန်တွက် (Stock 0 ပစ္စည်းများ ချက်ချင်း Sold Out ပြောင်းမည်)
update products set stock_qty = stock_qty;
