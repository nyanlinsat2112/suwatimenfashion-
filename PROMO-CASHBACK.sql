-- =====================================================================
-- 🎟️ PROMO CODE + 🎉 CASHBACK CAMPAIGN (ကာလသတ်မှတ်ပြီး Auto အလုပ်လုပ်)
-- SECURITY-HARDENING.sql ပြီးမှ Run ပါ (supabase-schema.sql အဆုံးမှာလည်း ပါပြီးသား)
-- =====================================================================

create table if not exists promo_codes (
  id uuid primary key default gen_random_uuid(),
  code text not null,
  discount_type text not null default 'percent' check (discount_type in ('percent','fixed')),
  discount_value numeric not null check (discount_value > 0),
  max_discount numeric,                 -- % အတွက် အများဆုံး လျှော့ပေးမည့် ငွေ (Optional)
  min_order numeric not null default 0, -- အနည်းဆုံး ဝယ်ရမည့် ပမာဏ
  max_uses int,                         -- စုစုပေါင်း သုံးခွင့် အကြိမ်ရေ (NULL = အကန့်အသတ်မဲ့)
  once_per_customer boolean not null default true,
  starts_at timestamptz not null default now(),
  ends_at timestamptz,
  active boolean not null default true,
  used_count int not null default 0,
  note text,
  created_by text,
  created_at timestamptz default now()
);
create unique index if not exists promo_codes_code_upper on promo_codes (upper(code));
alter table promo_codes enable row level security;
drop policy if exists "Admin manage promo codes" on promo_codes;
create policy "Admin manage promo codes" on promo_codes for all using (is_admin()) with check (is_admin());

create table if not exists promo_redemptions (
  id uuid primary key default gen_random_uuid(),
  code text not null,
  order_group_id uuid not null,
  user_id uuid,
  phone text,
  customer_name text,
  discount_amount numeric not null,
  created_at timestamptz default now()
);
alter table promo_redemptions enable row level security;
drop policy if exists "Admin view promo redemptions" on promo_redemptions;
create policy "Admin view promo redemptions" on promo_redemptions for select using (is_admin());

create table if not exists cashback_campaigns (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  tiers jsonb not null default '[]'::jsonb,  -- [{"min":300000,"type":"percent","value":3},{"min":500000,"type":"percent","value":5}]
  max_cashback numeric,                      -- Order တစ်ခုအတွက် အများဆုံး (Optional)
  starts_at timestamptz not null default now(),
  ends_at timestamptz,
  active boolean not null default true,
  created_by text,
  created_at timestamptz default now()
);
alter table cashback_campaigns enable row level security;
drop policy if exists "Public view running cashback" on cashback_campaigns;
create policy "Public view running cashback" on cashback_campaigns for select
  using (active and starts_at <= now() and (ends_at is null or ends_at > now()));
drop policy if exists "Admin manage cashback" on cashback_campaigns;
create policy "Admin manage cashback" on cashback_campaigns for all using (is_admin()) with check (is_admin());

alter table orders add column if not exists promo_code text;
alter table orders add column if not exists cashback_amount numeric default 0;

-- ---------- Promo Code တွက်ချက်/စစ်ဆေး (Browser နဲ့ Database Trigger နှစ်ခုလုံး ဒီ Logic တစ်ခုတည်းကို သုံး) ----------
create or replace function promo_evaluate(p_code text, p_subtotal numeric, p_user uuid, p_phone text, p_lock boolean default false)
returns jsonb as $$
declare
  pc promo_codes;
  d numeric;
begin
  if p_code is null or trim(p_code) = '' then
    return jsonb_build_object('ok', false, 'message', 'Promo Code ရိုက်ထည့်ပါ');
  end if;
  if p_lock then
    select * into pc from promo_codes where upper(code) = upper(trim(p_code)) for update;
  else
    select * into pc from promo_codes where upper(code) = upper(trim(p_code));
  end if;
  if pc.id is null then return jsonb_build_object('ok', false, 'message', 'Promo Code မှားနေပါသည်'); end if;
  if not pc.active then return jsonb_build_object('ok', false, 'message', 'ဒီ Promo Code ကို ယာယီ ရပ်ထားပါသည်'); end if;
  if pc.starts_at > now() then return jsonb_build_object('ok', false, 'message', 'ဒီ Promo Code ကို ' || to_char(pc.starts_at at time zone 'Asia/Yangon', 'DD/MM/YYYY HH24:MI') || ' မှ စသုံးလို့ရပါမည်'); end if;
  if pc.ends_at is not null and pc.ends_at <= now() then return jsonb_build_object('ok', false, 'message', 'ဒီ Promo Code သက်တမ်း ကုန်သွားပါပြီ'); end if;
  if pc.max_uses is not null and pc.used_count >= pc.max_uses then return jsonb_build_object('ok', false, 'message', 'ဒီ Promo Code သုံးခွင့် ပြည့်သွားပါပြီ'); end if;
  if coalesce(p_subtotal,0) < pc.min_order then
    return jsonb_build_object('ok', false, 'message', to_char(pc.min_order, 'FM999,999,999') || ' ကျပ်နှင့်အထက် ဝယ်မှ သုံးလို့ရပါသည်');
  end if;
  if pc.once_per_customer and exists (
    select 1 from promo_redemptions r
    where upper(r.code) = upper(pc.code)
      and ((p_user is not null and r.user_id = p_user) or (coalesce(p_phone,'') <> '' and regexp_replace(r.phone,'\D','','g') = regexp_replace(p_phone,'\D','','g')))
  ) then
    return jsonb_build_object('ok', false, 'message', 'ဒီ Promo Code ကို သုံးပြီးသား ဖြစ်ပါသည် (တစ်ယောက် တစ်ကြိမ်သာ)');
  end if;

  if pc.discount_type = 'percent' then
    d := floor(p_subtotal * pc.discount_value / 100);
    if pc.max_discount is not null then d := least(d, pc.max_discount); end if;
  else
    d := pc.discount_value;
  end if;
  d := least(d, p_subtotal);
  return jsonb_build_object('ok', true, 'discount', d, 'code', pc.code,
    'label', case when pc.discount_type='percent' then pc.discount_value::text || '%' else to_char(pc.discount_value,'FM999,999,999') || ' ကျပ်' end);
end;
$$ language plpgsql security definer set search_path = public;
revoke all on function promo_evaluate(text, numeric, uuid, text, boolean) from public, anon, authenticated;

-- Customer က Checkout မှာ "Apply" နှိပ်ရင် ခေါ်မည့် Function (ကြည့်ရုံသာ — မသုံးသေး)
create or replace function check_promo_code(p_code text, p_subtotal numeric, p_phone text default null)
returns jsonb as $$
begin
  return promo_evaluate(p_code, p_subtotal, auth.uid(), p_phone, false);
end;
$$ language plpgsql security definer set search_path = public;
grant execute on function check_promo_code(text, numeric, text) to anon, authenticated;

-- ---------- Cashback တွက်ချက် (လက်ရှိ Run နေတဲ့ Campaign များထဲက အများဆုံး) ----------
create or replace function calc_cashback(p_base numeric)
returns numeric as $$
declare
  c record; t jsonb; best numeric := 0; v numeric;
begin
  for c in select * from cashback_campaigns where active and starts_at <= now() and (ends_at is null or ends_at > now()) loop
    v := 0;
    for t in select * from jsonb_array_elements(c.tiers) e order by (e->>'min')::numeric desc loop
      if p_base >= coalesce((t->>'min')::numeric,0) then
        v := case when t->>'type' = 'fixed' then (t->>'value')::numeric else floor(p_base * (t->>'value')::numeric / 100) end;
        exit;
      end if;
    end loop;
    if c.max_cashback is not null then v := least(v, c.max_cashback); end if;
    best := greatest(best, v);
  end loop;
  return best;
end;
$$ language plpgsql security definer set search_path = public;
grant execute on function calc_cashback(numeric) to anon, authenticated;

-- ---------- Order Insert စစ်ဆေးမှု (ဈေးနှုန်း + Promo + ငွေပေးချေမှု + Cashback တွက် + Stock) ----------
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
      and (
        order_status = 'pending_verification'
        or (order_status = 'confirmed' and auth.uid() is not null and user_id = auth.uid() and payment_method in ('Prepaid Card','Wallet'))
      )
    )
  );

create or replace function verify_customer_orders()
returns trigger as $$
declare
  g record; r record;
  gift_price numeric; paid numeric; bad text;
  pc_cnt int; pc_total numeric; pc_code text; sub numeric; res jsonb;
  grp_user uuid; grp_phone text; grp_name text; base numeric; cb numeric; first_id uuid;
begin
  if is_admin() then return null; end if;
  select coalesce(gift_wrap_price, 4500) into gift_price from settings where id = 1;
  gift_price := coalesce(gift_price, 4500);

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

  for g in
    select order_group_id, sum(total_amount) as total, count(*) as cnt,
           bool_or(order_status = 'confirmed') as any_prepaid, bool_and(order_status = 'confirmed') as all_prepaid
    from new_rows group by order_group_id
  loop
    if g.order_group_id is null then raise exception 'MISSING_ORDER_GROUP'; end if;
    if (select count(*) from orders where order_group_id = g.order_group_id) <> g.cnt then raise exception 'DUPLICATE_ORDER_GROUP'; end if;

    select max(user_id::text)::uuid, max(phone), max(customer_name) into grp_user, grp_phone, grp_name from new_rows where order_group_id = g.order_group_id;
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

    -- Prepaid ငွေပေးချေမှု
    if g.any_prepaid then
      if not g.all_prepaid then raise exception 'MIXED_PAYMENT_STATUS'; end if;
      select -sum(amount) into paid from wallet_transactions
        where user_id = auth.uid() and type = 'purchase' and reference_id = g.order_group_id::text;
      if paid is null or paid <> g.total then raise exception 'PAYMENT_NOT_VERIFIED'; end if;
      if exists (select 1 from wallet_transactions where user_id = auth.uid() and type = 'refund' and reference_id = g.order_group_id::text) then
        raise exception 'PAYMENT_ALREADY_REFUNDED';
      end if;
    end if;

    -- Cashback (Login ဝင်ထားသူသာ — Order ချိန်က Campaign အတိုင်း Lock လုပ်ထား၊ Delivered ဖြစ်မှ Wallet ထဲ ထည့်)
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

  for r in select product_name, size, color, quantity from new_rows
           where product_name not in ('🎁 Gift ထုပ်ပိုး ဝန်ဆောင်မှု','🏷️ Promo Code') loop
    if not _decrement_stock_internal(r.product_name, r.quantity, r.color, r.size) then
      raise exception 'OUT_OF_STOCK: %', r.product_name || coalesce(' (' || r.size || coalesce(', ' || r.color, '') || ')', '');
    end if;
  end loop;
  return null;
end;
$$ language plpgsql security definer set search_path = public;

-- ---------- Order Status ပြောင်းတဲ့အခါ — Delivered → Cashback ထည့် / Cancelled → Promo ပြန်လွှတ် + Cashback ပြန်နုတ် ----------
create or replace function handle_order_rewards()
returns trigger as $$
declare
  grp uuid := coalesce(new.order_group_id, new.id);
  ref text := 'CB-' || coalesce(new.order_group_id, new.id)::text;
  cb numeric; uid uuid; bal numeric; take numeric;
begin
  if new.order_status is not distinct from old.order_status then return null; end if;

  if new.order_status = 'delivered' then
    select sum(coalesce(cashback_amount,0)), max(user_id::text)::uuid into cb, uid
      from orders where coalesce(order_group_id, id) = grp;
    if uid is not null and cb > 0 and not exists (select 1 from wallet_transactions where type = 'cashback' and reference_id = ref) then
      perform _wallet_credit_internal(uid, cb, 'cashback', '🎉 Cashback — Order #' || upper(left(grp::text, 8)), ref);
    end if;

  elsif new.order_status = 'cancelled' then
    if exists (select 1 from promo_redemptions where order_group_id = grp) then
      update promo_codes set used_count = greatest(used_count - 1, 0)
        where upper(code) in (select upper(code) from promo_redemptions where order_group_id = grp);
      delete from promo_redemptions where order_group_id = grp;
    end if;
    select amount, user_id into cb, uid from wallet_transactions where type = 'cashback' and reference_id = ref limit 1;
    if cb is not null and not exists (select 1 from wallet_transactions where type = 'cashback_reversal' and reference_id = ref) then
      select balance into bal from wallets where user_id = uid for update;
      take := least(cb, greatest(coalesce(bal,0), 0));
      update wallets set balance = balance - take, updated_at = now() where user_id = uid;
      insert into wallet_transactions (user_id, type, amount, description, reference_id)
        values (uid, 'cashback_reversal', -take, 'Cashback ပြန်နုတ် — Order ပယ်ဖျက်/Refund', ref);
    end if;
  end if;
  return null;
end;
$$ language plpgsql security definer set search_path = public;
drop trigger if exists trg_handle_order_rewards on orders;
create trigger trg_handle_order_rewards after update of order_status on orders
  for each row execute function handle_order_rewards();


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
