-- =====================================================================
-- 🔧 FIX: Owner/Admin/Staff Account နဲ့ Website ကနေ ဝယ်ရင်လည်း Promo "တစ်ယောက် တစ်ကြိမ်" + Cashback မှန်ကန်စွာ အလုပ်လုပ်ရန်
-- ယခင်က Admin Account ဆိုရင် (POS အတွက်) စစ်ဆေးမှု အကုန်ကျော်ပစ်လို့ Promo သုံးမှတ်တမ်း မသိမ်း၊ Cashback မတွက်ခဲ့ပါ
-- ⚠️ ဒီဖိုင်ကို SQL ဖိုင်အားလုံးထဲမှာ နောက်ဆုံးမှ Run ပါ
-- =====================================================================
create or replace function verify_customer_orders()
returns trigger as $$
declare
  g record; r record;
  is_adm boolean := is_admin();
  gift_price numeric; paid numeric; bad text;
  pc_cnt int; pc_total numeric; pc_code text; sub numeric; res jsonb;
  grp_user uuid; grp_phone text; grp_name text; base numeric; cb numeric; first_id uuid;
begin
  -- ဆိုင်ထဲ POS အရောင်း (In-Store) သာ ဆိုရင် ဘာမှ မစစ် (Admin က Stock/ဈေး ကိုယ်တိုင် ထိန်းသည်)
  if not exists (select 1 from new_rows where coalesce(sale_channel,'online') = 'online') then
    return null;
  end if;

  select coalesce(gift_wrap_price, 4500) into gift_price from settings where id = 1;
  gift_price := coalesce(gift_price, 4500);

  -- ဈေးနှုန်း စစ်ဆေးမှု (Customer အတွက်သာ — Admin က ဈေးညှိပေးခွင့် ရှိ)
  if not is_adm then
    select string_agg(n.product_name, ', ') into bad
    from new_rows n
    left join products p on p.name = n.product_name and coalesce(p.is_gift_card,false) = false
    where n.product_name <> '🏷️ Promo Code' and (
          n.total_amount <> n.unit_price * n.quantity
       or not (
         (n.product_name = '🎁 Gift ထုပ်ပိုး ဝန်ဆောင်မှု' and n.quantity = 1 and n.unit_price = gift_price)
         or (p.id is not null and n.unit_price = p.price)
       ));
    if bad is not null then raise exception 'PRICE_MISMATCH: %', bad; end if;
  end if;

  for g in
    select order_group_id, sum(total_amount) as total, count(*) as cnt,
           bool_or(order_status = 'confirmed' and payment_method in ('Prepaid Card','Wallet')) as any_prepaid,
           bool_and(order_status = 'confirmed' and payment_method in ('Prepaid Card','Wallet')) as all_prepaid
    from new_rows where coalesce(sale_channel,'online') = 'online'
    group by order_group_id
  loop
    if g.order_group_id is null then raise exception 'MISSING_ORDER_GROUP'; end if;
    if (select count(*) from orders where order_group_id = g.order_group_id) <> g.cnt then raise exception 'DUPLICATE_ORDER_GROUP'; end if;

    select max(user_id::text)::uuid, max(phone), max(customer_name) into grp_user, grp_phone, grp_name
      from new_rows where order_group_id = g.order_group_id;
    select coalesce(sum(total_amount),0) into sub from new_rows
      where order_group_id = g.order_group_id and product_name not in ('🎁 Gift ထုပ်ပိုး ဝန်ဆောင်မှု','🏷️ Promo Code');

    -- Promo Code (Admin Account အပါအဝင် လူတိုင်း — တစ်ယောက် တစ်ကြိမ်/အကြိမ်ရေ Limit အမှန်အတိုင်း စစ်ပြီး မှတ်တမ်းတင်)
    select count(*), coalesce(sum(total_amount),0), max(promo_code) into pc_cnt, pc_total, pc_code
      from new_rows where order_group_id = g.order_group_id and product_name = '🏷️ Promo Code';
    if pc_cnt > 1 then raise exception 'PROMO_INVALID: တစ်ခုထက်ပို'; end if;
    if pc_cnt = 1 then
      res := promo_evaluate(pc_code, sub, grp_user, grp_phone, true);
      if not coalesce((res->>'ok')::boolean,false) then raise exception 'PROMO_INVALID: %', res->>'message'; end if;
      if -pc_total <> (res->>'discount')::numeric then raise exception 'PROMO_INVALID: Discount မကိုက်ညီ'; end if;
      insert into promo_redemptions (code, order_group_id, user_id, phone, customer_name, discount_amount)
        values (res->>'code', g.order_group_id, grp_user, grp_phone, grp_name, -pc_total);
      update promo_codes set used_count = used_count + 1 where upper(code) = upper(res->>'code');
    end if;

    -- Prepaid ငွေပေးချေမှု စစ်ဆေး
    if g.any_prepaid then
      if not g.all_prepaid then raise exception 'MIXED_PAYMENT_STATUS'; end if;
      select -sum(amount) into paid from wallet_transactions
        where user_id = auth.uid() and type = 'purchase' and reference_id = g.order_group_id::text;
      if paid is null or paid <> g.total then raise exception 'PAYMENT_NOT_VERIFIED'; end if;
      if exists (select 1 from wallet_transactions where user_id = auth.uid() and type = 'refund' and reference_id = g.order_group_id::text) then
        raise exception 'PAYMENT_ALREADY_REFUNDED';
      end if;
    end if;

    -- Cashback (Login ဝင်ထားသူ — Delivered ဖြစ်မှ Wallet ထဲ ထည့်မည်)
    if grp_user is not null then
      base := sub + (case when pc_cnt = 1 then pc_total else 0 end);
      cb := calc_cashback(base);
      if cb > 0 then
        select id into first_id from new_rows where order_group_id = g.order_group_id
          and product_name not in ('🎁 Gift ထုပ်ပိုး ဝန်ဆောင်မှု','🏷️ Promo Code') limit 1;
        update orders set cashback_amount = cb where id = first_id;
      end if;
    end if;
  end loop;

  -- Stock လျှော့ခြင်း — Customer အတွက်သာ (Admin Account ဆိုရင် Website က Stock ကို ချက်ချင်း လျှော့ပြီးသားဖြစ်လို့ ထပ်မလျှော့)
  if not is_adm then
    for r in select product_name, size, color, quantity from new_rows
             where coalesce(sale_channel,'online') = 'online'
               and product_name not in ('🎁 Gift ထုပ်ပိုး ဝန်ဆောင်မှု','🏷️ Promo Code') loop
      if not _decrement_stock_internal(r.product_name, r.quantity, r.color, r.size) then
        raise exception 'OUT_OF_STOCK: %', r.product_name || coalesce(' (' || r.size || coalesce(', ' || r.color, '') || ')', '');
      end if;
    end loop;
  end if;
  return null;
end;
$$ language plpgsql security definer set search_path = public;

-- Customer အတွက် Cashback History နဲ့ Promo သုံးပြီးကြောင်း Admin မှာ စစ်ကြည့်ရန် (Optional စစ်ဆေးမှု Query)
-- select code, customer_name, phone, discount_amount, created_at from promo_redemptions order by created_at desc;
-- select id, order_group_id, cashback_amount, order_status from orders where cashback_amount > 0 order by created_at desc;

-- ယခင်က မှတ်တမ်းမတင်ခဲ့ရတဲ့ Promo သုံးမှုများကို ပြန်ဖြည့် (ထပ် Run လည်း ထပ်မဖြည့်ပါ)
insert into promo_redemptions (code, order_group_id, user_id, phone, customer_name, discount_amount)
select o.promo_code, o.order_group_id, o.user_id, o.phone, o.customer_name, -o.total_amount
from orders o
where o.product_name = '🏷️ Promo Code' and o.promo_code is not null and o.order_group_id is not null
  and coalesce(o.order_status,'') <> 'cancelled'
  and not exists (select 1 from promo_redemptions r where r.order_group_id = o.order_group_id);
update promo_codes pc set used_count = (select count(*) from promo_redemptions r where upper(r.code) = upper(pc.code));
