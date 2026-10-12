-- =====================================================================
-- 💳 PAYMENT UPGRADE — SUWATI MEN FASHION
--   ③ ငွေ နောက်မှလွှဲ (Pay Later) + အချိန်ပြည့်ရင် Auto Cancel + Stock ပြန်ထည့်
--   ⑤ Top-up Bonus (ဥပမာ 1 သိန်းဖြည့် → 5% Bonus)
--   ⑦ ငွေ ၂ မျိုး ခွဲချေ (Website: Prepaid + KBZPay / POS: ငွေသား + အခြား)
--   ⑧ POS နေ့စဉ် ငွေသား စာရင်းပိတ် (Cash Closing)
-- Supabase → SQL Editor မှာ ဒီဖိုင်တစ်ခုလုံး Copy ကူးပြီး Run ပါ (ထပ် Run လည်း ဘေးမရှိပါ)
-- ⚠️ ယခင် SQL ဖိုင်များ (FIX-promo-cashback-admin-account.sql အပါအဝင်) ကို Run ပြီးမှ ဒီဖိုင်ကို Run ပါ
-- =====================================================================

-- ---------- ၁) Column အသစ်များ ----------
alter table settings add column if not exists pay_later_enabled boolean default true;
alter table settings add column if not exists unpaid_cancel_hours int default 24;
alter table settings add column if not exists topup_bonus jsonb default '{"enabled":false,"tiers":[]}'::jsonb;
update settings set pay_later_enabled = coalesce(pay_later_enabled, true),
                    unpaid_cancel_hours = coalesce(unpaid_cancel_hours, 24),
                    topup_bonus = coalesce(topup_bonus, '{"enabled":false,"tiers":[]}'::jsonb)
where id = 1;

alter table orders add column if not exists wallet_paid numeric default 0;      -- Website: Prepaid Card ထဲက ပေးပြီးသား ပမာဏ (ခွဲချေ)
alter table orders add column if not exists payment_due_at timestamptz;         -- Pay Later: ဒီအချိန်မတိုင်ခင် ငွေလွှဲရမည်
alter table orders add column if not exists split_payments jsonb;               -- POS: [{"method":"Cash","amount":20000},{"method":"KBZPay","amount":15000}]
alter table wallet_topups add column if not exists bonus_amount numeric default 0;

create index if not exists idx_orders_awaiting on orders (payment_due_at) where order_status = 'awaiting_payment';


-- ---------- ၂) Customer Order တင်ခွင့် (Pay Later + ခွဲချေ ခွင့်ပြု) ----------
drop policy if exists "Public can create orders" on orders;
create policy "Public can create orders" on orders for insert
  with check (
    is_admin() or (
      coalesce(sale_channel,'online') = 'online'
      and (user_id is null or user_id = auth.uid())
      and coalesce(discount_amount,0) = 0
      and quantity > 0
      and (total_amount >= 0 or product_name = '🏷️ Promo Code')
      and coalesce(cashback_amount,0) = 0
      and delivered_at is null and delivery_photo_url is null and delivered_by is null
      and payment_due_at is null and split_payments is null
      and coalesce(wallet_paid,0) >= 0
      and (coalesce(wallet_paid,0) = 0 or (auth.uid() is not null and user_id = auth.uid()))
      and (
        order_status = 'pending_verification'
        or (order_status = 'awaiting_payment' and auth.uid() is not null and user_id = auth.uid() and payment_screenshot_url is null)
        or (order_status = 'confirmed' and auth.uid() is not null and user_id = auth.uid() and payment_method in ('Prepaid Card','Wallet'))
      )
    )
  );


-- ---------- ၃) Order စစ်ဆေးမှု Trigger (ယခင်အတိုင်း + Pay Later + ခွဲချေ စစ်ဆေးမှု) ----------
create or replace function verify_customer_orders()
returns trigger as $$
declare
  g record; r record;
  is_adm boolean := is_admin();
  gift_price numeric; paid numeric; bad text;
  pc_cnt int; pc_total numeric; pc_code text; sub numeric; res jsonb;
  grp_user uuid; grp_phone text; grp_name text; base numeric; cb numeric; first_id uuid;
  pl_enabled boolean; pl_hours int; open_cnt int;
begin
  if not exists (select 1 from new_rows where coalesce(sale_channel,'online') = 'online') then
    return null;
  end if;

  select coalesce(gift_wrap_price, 4500), coalesce(pay_later_enabled, true), coalesce(unpaid_cancel_hours, 24)
    into gift_price, pl_enabled, pl_hours from settings where id = 1;
  gift_price := coalesce(gift_price, 4500);
  pl_enabled := coalesce(pl_enabled, true);
  pl_hours := greatest(coalesce(pl_hours, 24), 1);

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
           count(distinct order_status) as status_cnt, max(order_status) as status,
           coalesce(sum(coalesce(wallet_paid,0)),0) as wallet_part,
           bool_or(order_status = 'confirmed' and payment_method in ('Prepaid Card','Wallet')) as any_prepaid,
           bool_and(order_status = 'confirmed' and payment_method in ('Prepaid Card','Wallet')) as all_prepaid
    from new_rows where coalesce(sale_channel,'online') = 'online'
    group by order_group_id
  loop
    if g.order_group_id is null then raise exception 'MISSING_ORDER_GROUP'; end if;
    if (select count(*) from orders where order_group_id = g.order_group_id) <> g.cnt then raise exception 'DUPLICATE_ORDER_GROUP'; end if;
    if g.status_cnt <> 1 then raise exception 'MIXED_PAYMENT_STATUS'; end if;

    select max(user_id::text)::uuid, max(phone), max(customer_name) into grp_user, grp_phone, grp_name
      from new_rows where order_group_id = g.order_group_id;
    select coalesce(sum(total_amount),0) into sub from new_rows
      where order_group_id = g.order_group_id and product_name not in ('🎁 Gift ထုပ်ပိုး ဝန်ဆောင်မှု','🏷️ Promo Code');

    -- Promo Code
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

    -- Prepaid အပြည့် ငွေပေးချေမှု စစ်ဆေး
    if g.any_prepaid then
      if not g.all_prepaid then raise exception 'MIXED_PAYMENT_STATUS'; end if;
      if g.wallet_part > 0 then raise exception 'SPLIT_PAYMENT_INVALID'; end if;
      select -sum(amount) into paid from wallet_transactions
        where user_id = auth.uid() and type = 'purchase' and reference_id = g.order_group_id::text;
      if paid is null or paid <> g.total then raise exception 'PAYMENT_NOT_VERIFIED'; end if;
      if exists (select 1 from wallet_transactions where user_id = auth.uid() and type = 'refund' and reference_id = g.order_group_id::text) then
        raise exception 'PAYMENT_ALREADY_REFUNDED';
      end if;
    end if;

    -- ⑦ ခွဲချေ (Prepaid တစ်စိတ် + KBZPay ကျန်ငွေ) စစ်ဆေး
    if g.wallet_part > 0 then
      if g.wallet_part >= g.total then raise exception 'SPLIT_PAYMENT_INVALID'; end if;
      select -sum(amount) into paid from wallet_transactions
        where user_id = auth.uid() and type = 'purchase' and reference_id = g.order_group_id::text;
      if paid is null or paid <> g.wallet_part then raise exception 'PAYMENT_NOT_VERIFIED'; end if;
      if exists (select 1 from wallet_transactions where user_id = auth.uid() and type = 'refund' and reference_id = g.order_group_id::text) then
        raise exception 'PAYMENT_ALREADY_REFUNDED';
      end if;
    end if;

    -- ③ Pay Later — ဖွင့်ထားမှ / တစ်ယောက် ငွေမချေရသေးသော Order ၂ ခုထက် မပို (Stock ပိတ်မထားနိုင်ရန်)
    if g.status = 'awaiting_payment' then
      if not pl_enabled and not is_adm then raise exception 'PAY_LATER_DISABLED'; end if;
      select count(distinct order_group_id) into open_cnt from orders
        where user_id = grp_user and order_status = 'awaiting_payment' and order_group_id <> g.order_group_id;
      if open_cnt >= 2 and not is_adm then raise exception 'PAY_LATER_LIMIT'; end if;
      -- ငွေမလွှဲရသေးလို့ Admin ကို ချက်ချင်း မသတိပေး — Screenshot တင်မှ (attach_payment_proof) NEW ပြမည်
      update orders set payment_due_at = now() + make_interval(hours => pl_hours), payment_status = 'unpaid', viewed_by_admin = true
        where order_group_id = g.order_group_id;
    end if;

    -- Cashback
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

  -- Stock လျှော့ခြင်း — Customer အတွက်သာ
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

drop trigger if exists trg_verify_customer_orders on orders;
create trigger trg_verify_customer_orders
  after insert on orders
  referencing new table as new_rows
  for each statement execute function verify_customer_orders();


-- ---------- ၄) ③ ငွေမချေရသေးသော Order ကို Cancel (Stock ပြန်ထည့် + Prepaid ပေးထားတာ ပြန်အမ်း) ----------
create or replace function _cancel_unpaid_group(p_group uuid, p_reason text)
returns boolean as $$
declare
  r record; wp numeric; uid uuid;
begin
  perform 1 from orders where order_group_id = p_group and order_status = 'awaiting_payment' for update;
  if not found then return false; end if;

  for r in select product_name, size, color, quantity from orders
           where order_group_id = p_group and order_status = 'awaiting_payment'
             and product_name not in ('🎁 Gift ထုပ်ပိုး ဝန်ဆောင်မှု','🏷️ Promo Code') loop
    perform _increment_stock_internal(r.product_name, r.quantity, r.color, r.size);
  end loop;

  select coalesce(sum(coalesce(wallet_paid,0)),0), max(user_id::text)::uuid into wp, uid
    from orders where order_group_id = p_group;

  update orders set order_status = 'cancelled', payment_status = 'cancelled', cancellation_reason = p_reason, viewed_by_admin = true
    where order_group_id = p_group and order_status = 'awaiting_payment';

  if wp > 0 and uid is not null
     and not exists (select 1 from wallet_transactions where type = 'refund' and reference_id = p_group::text) then
    perform _wallet_credit_internal(uid, wp, 'refund', 'Order ပယ်ဖျက် — Prepaid ငွေ ပြန်အမ်း', p_group::text);
  end if;
  return true;
end;
$$ language plpgsql security definer set search_path = public;
revoke all on function _cancel_unpaid_group(uuid, text) from public, anon, authenticated;

-- သက်တမ်းကုန် Order များ Auto Cancel (Website/Admin App ဖွင့်တိုင်း အလိုအလျောက် ခေါ်သည် — ဘယ်သူခေါ်ခေါ် သက်တမ်းကုန်တာကိုသာ Cancel လုပ်)
create or replace function cancel_expired_unpaid_orders()
returns int as $$
declare
  g uuid; n int := 0;
begin
  for g in select distinct order_group_id from orders
           where order_status = 'awaiting_payment' and payment_due_at is not null and payment_due_at < now()
           limit 200 loop
    if _cancel_unpaid_group(g, '⏰ သတ်မှတ်ချိန်အတွင်း ငွေမလွှဲ၍ အလိုအလျောက် ပယ်ဖျက်ပါသည်') then n := n + 1; end if;
  end loop;
  return n;
end;
$$ language plpgsql security definer set search_path = public;
grant execute on function cancel_expired_unpaid_orders() to anon, authenticated;

-- Customer ကိုယ်တိုင် ငွေမချေရသေးသော Order ကို ပယ်ဖျက်
create or replace function cancel_my_unpaid_order(p_group uuid)
returns boolean as $$
begin
  if auth.uid() is null then return false; end if;
  if not exists (select 1 from orders where order_group_id = p_group and user_id = auth.uid() and order_status = 'awaiting_payment') then
    return false;
  end if;
  return _cancel_unpaid_group(p_group, 'Customer ကိုယ်တိုင် ပယ်ဖျက်ပါသည်');
end;
$$ language plpgsql security definer set search_path = public;
revoke all on function cancel_my_unpaid_order(uuid) from public, anon;
grant execute on function cancel_my_unpaid_order(uuid) to authenticated;

-- Customer က နောက်မှ ငွေလွှဲ Screenshot တင်ခြင်း → "ငွေချေမှု စစ်ဆေးဆဲ" ဖြစ်သွားမည်
create or replace function attach_payment_proof(p_group uuid, p_url text)
returns jsonb as $$
declare
  due timestamptz;
begin
  if auth.uid() is null then return jsonb_build_object('ok',false,'message','Login ဝင်ရန် လိုအပ်ပါသည်'); end if;
  if p_url is null or p_url not like '%/storage/v1/object/public/payment-screenshots/%' then
    return jsonb_build_object('ok',false,'message','Screenshot မမှန်ကန်ပါ');
  end if;
  select min(payment_due_at) into due from orders
    where order_group_id = p_group and user_id = auth.uid() and order_status = 'awaiting_payment';
  if not found or due is null then
    return jsonb_build_object('ok',false,'message','ဒီ Order က ငွေလွှဲရန် မလိုတော့ပါ (သို့) ပယ်ဖျက်ပြီးပါပြီ');
  end if;
  if due < now() then
    perform _cancel_unpaid_group(p_group, '⏰ သတ်မှတ်ချိန်အတွင်း ငွေမလွှဲ၍ အလိုအလျောက် ပယ်ဖျက်ပါသည်');
    return jsonb_build_object('ok',false,'message','သတ်မှတ်ချိန် ကျော်သွားလို့ Order ပယ်ဖျက်ပြီးပါပြီ');
  end if;
  update orders set payment_screenshot_url = p_url, order_status = 'pending_verification', payment_status = 'pending',
                    viewed_by_admin = false
    where order_group_id = p_group and order_status = 'awaiting_payment';
  return jsonb_build_object('ok',true);
end;
$$ language plpgsql security definer set search_path = public;
revoke all on function attach_payment_proof(uuid, text) from public, anon;
grant execute on function attach_payment_proof(uuid, text) to authenticated;

-- (Optional) Supabase မှာ pg_cron Extension ဖွင့်ထားရင် ၁၅ မိနစ်တစ်ခါ အလိုအလျောက် စစ်ရန် — အောက်က ၂ ကြောင်းကို -- ဖြုတ်ပြီး Run ပါ
-- create extension if not exists pg_cron;
-- select cron.schedule('suwati-cancel-unpaid', '*/15 * * * *', 'select cancel_expired_unpaid_orders()');


-- ---------- ၅) ⑤ Top-up Bonus ----------
-- settings.topup_bonus = {"enabled":true,"starts_at":null,"ends_at":"2026-12-31T23:59:59+06:30",
--                         "tiers":[{"min":50000,"type":"percent","value":3},{"min":100000,"type":"percent","value":5}]}
create or replace function topup_bonus_for(p_amount numeric)
returns numeric as $$
declare
  cfg jsonb; t jsonb; best numeric := 0; bestmin numeric := -1; b numeric; m numeric;
begin
  select topup_bonus into cfg from settings where id = 1;
  if cfg is null or not coalesce((cfg->>'enabled')::boolean, false) or p_amount is null or p_amount <= 0 then return 0; end if;
  if coalesce(cfg->>'starts_at','') <> '' and (cfg->>'starts_at')::timestamptz > now() then return 0; end if;
  if coalesce(cfg->>'ends_at','') <> '' and (cfg->>'ends_at')::timestamptz < now() then return 0; end if;
  for t in select * from jsonb_array_elements(coalesce(cfg->'tiers','[]'::jsonb)) loop
    m := coalesce((t->>'min')::numeric, 0);
    if p_amount >= m and m > bestmin then
      bestmin := m;
      if t->>'type' = 'percent' then
        b := floor(p_amount * least(greatest(coalesce((t->>'value')::numeric,0),0),100) / 100);
      else
        b := greatest(coalesce((t->>'value')::numeric,0),0);
      end if;
      best := b;
    end if;
  end loop;
  return coalesce(best, 0);
end;
$$ language plpgsql stable security definer set search_path = public;
grant execute on function topup_bonus_for(numeric) to anon, authenticated;

-- Admin က Top-up Approve လုပ်ပြီး ငွေဝင်သွားတာနဲ့ Bonus ကို အလိုအလျောက် ထပ်ထည့် (တစ်ကြိမ်သာ)
create or replace function apply_topup_bonus()
returns trigger as $$
declare b numeric;
begin
  if new.type <> 'topup' or coalesce(new.amount,0) <= 0 or new.reference_id is null then return null; end if;
  if not exists (select 1 from wallet_topups where id::text = new.reference_id) then return null; end if;
  if exists (select 1 from wallet_transactions where type = 'topup_bonus' and reference_id = new.reference_id) then return null; end if;
  b := topup_bonus_for(new.amount);
  if b > 0 then
    perform _wallet_credit_internal(new.user_id, b, 'topup_bonus', '🎁 Top-up Bonus', new.reference_id);
    update wallet_topups set bonus_amount = b where id::text = new.reference_id;
  end if;
  return null;
end;
$$ language plpgsql security definer set search_path = public;
drop trigger if exists trg_apply_topup_bonus on wallet_transactions;
create trigger trg_apply_topup_bonus after insert on wallet_transactions
  for each row execute function apply_topup_bonus();


-- ---------- ၆) ⑧ POS နေ့စဉ် ငွေသား စာရင်းပိတ် ----------
create table if not exists cash_closings (
  id uuid primary key default gen_random_uuid(),
  closing_date date not null,
  opening_float numeric default 0,     -- ဆိုင်ဖွင့်ချိန် ဗီရိုထဲ ထားခဲ့တဲ့ အမ်းငွေ
  cash_sales numeric default 0,        -- POS ငွေသား အရောင်း
  cash_other_in numeric default 0,     -- တခြား ငွေသား ဝင်ငွေ (Gift Card စသဖြင့်)
  cash_out numeric default 0,          -- ဗီရိုထဲကနေ ထုတ်သုံးငွေ
  expected_cash numeric default 0,
  counted_cash numeric default 0,
  difference numeric default 0,
  denominations jsonb,
  note text,
  closed_by uuid default auth.uid(),
  closed_by_email text,
  created_at timestamptz default now()
);
alter table cash_closings enable row level security;
drop policy if exists "Admin can view cash closings" on cash_closings;
create policy "Admin can view cash closings" on cash_closings for select using (is_admin());
drop policy if exists "Admin can add cash closings" on cash_closings;
create policy "Admin can add cash closings" on cash_closings for insert with check (is_admin());
drop policy if exists "Owner can delete cash closings" on cash_closings;
create policy "Owner can delete cash closings" on cash_closings for delete using (is_owner());
create index if not exists idx_cash_closings_date on cash_closings (closing_date desc);
