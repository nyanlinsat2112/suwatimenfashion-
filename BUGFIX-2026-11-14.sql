-- =====================================================================
-- SUWATI — Bug Fix SQL (14 Nov 2026) · Bug Report C1 · C2 · H1–H4 · M1 · M2 · M7 · M9 · L1 · L3
-- ထပ် Run လည်း ဘေးမရှိ (idempotent) · Claude က Supabase MCP နဲ့ Run ပြီးသား
-- =====================================================================

-- ---------- Helper: ငွေကိုင်ခွင့်ရှိ Admin (Delivery Role မပါ) ----------
create or replace function public.is_cashier()
returns boolean language sql stable security definer set search_path = public as $$
  select public.is_admin() and exists (
    select 1 from public.admins a where a.user_id = auth.uid() and coalesce(a.role, 'owner') <> 'delivery')
$$;
revoke execute on function public.is_cashier() from anon;

-- ---------- C1 + H1: Customer Order Insert Policy ----------
-- wallet_paid / payment_due_at / split_payments ကို Customer မသတ်မှတ်ရ (Server က စစ်)
-- awaiting_payment (Pay Later) ပြန်ခွင့်ပြု · Prepaid Method = confirmed ဖြစ်မှ
drop policy if exists "Public can create orders" on public.orders;
create policy "Public can create orders" on public.orders for insert
  with check (
    is_admin() or (
      coalesce(sale_channel, 'online') = 'online'
      and (user_id is null or user_id = auth.uid())
      and coalesce(discount_amount, 0) = 0
      and quantity > 0
      and (total_amount >= 0 or product_name = '🏷️ Promo Code')
      and coalesce(cashback_amount, 0) = 0
      and delivered_at is null and delivery_photo_url is null and delivered_by is null
      and payment_due_at is null and split_payments is null
      and coalesce(wallet_paid, 0) >= 0
      and (coalesce(wallet_paid, 0) = 0 or (auth.uid() is not null and user_id = auth.uid()))
      and (coalesce(payment_method, '') not in ('Prepaid Card', 'Wallet') or order_status = 'confirmed')
      and (
        order_status = 'pending_verification'
        or (order_status = 'awaiting_payment' and auth.uid() is not null and user_id = auth.uid() and payment_screenshot_url is null)
        or (order_status = 'confirmed' and auth.uid() is not null and user_id = auth.uid() and payment_method in ('Prepaid Card', 'Wallet'))
      )
    )
  );

-- ---------- C1 + H1: Order စစ်ဆေး Trigger (Live Version + ခွဲချေ/Pay Later စစ်ချက် ပြန်ထည့်) ----------
create or replace function public.verify_customer_orders()
returns trigger language plpgsql security definer set search_path = public as $function$
declare
  g record; r record;
  is_adm boolean := is_admin();
  gift_price numeric; paid numeric; bad text;
  pc_cnt int; pc_total numeric; pc_code text; sub numeric; res jsonb;
  grp_user uuid; grp_phone text; grp_name text; base numeric; cb numeric; first_id uuid;
  pl_enabled boolean; pl_hours int; open_cnt int;
begin
  if current_setting('suwati.restoring', true) = '1' then return null; end if;
  if not exists (select 1 from new_rows where coalesce(sale_channel,'online') = 'online') then
    return null;
  end if;

  select coalesce(gift_wrap_price, 4500), coalesce(pay_later_enabled, false), coalesce(unpaid_cancel_hours, 24)
    into gift_price, pl_enabled, pl_hours from settings where id = 1;
  gift_price := coalesce(gift_price, 4500);
  pl_enabled := coalesce(pl_enabled, false);
  pl_hours := greatest(coalesce(pl_hours, 24), 1);

  -- ဈေးနှုန်း စစ်ဆေးမှု (Customer အတွက်သာ)
  if not is_adm then
    select string_agg(n.product_name, ', ') into bad
    from new_rows n
    left join products p on p.name = n.product_name and coalesce(p.is_gift_card,false) = false
    where n.product_name <> '🏷️ Promo Code' and (
          n.total_amount <> n.unit_price * n.quantity
       or not (
         (n.product_name = '🎁 Gift ထုပ်ပိုး ဝန်ဆောင်မှု' and n.quantity = 1 and n.unit_price = gift_price)
         or (p.id is not null and (n.unit_price = public.product_price(p) or n.unit_price = p.price or n.unit_price = public.bundle_unit_price(public.product_price(p), coalesce(p.category, 'Top Wear'), (select jsonb_agg(jsonb_build_object('c', coalesce(px.category, 'Top Wear'), 'q', x.quantity)) from new_rows x join products px on px.name = x.product_name and coalesce(px.is_gift_card, false) = false where x.order_group_id = n.order_group_id))))
       ));
    if bad is not null then raise exception 'PRICE_MISMATCH: %', bad; end if;
  end if;

  for g in
    select order_group_id, sum(total_amount) as total, count(*) as cnt,
           count(distinct order_status) as status_cnt, max(order_status) as status,
           coalesce(sum(coalesce(wallet_paid,0)),0) as wallet_part,
           bool_or(payment_method in ('Prepaid Card','Wallet')) as any_prepaid_method,
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

    if not is_adm then
      if g.status_cnt <> 1 then raise exception 'MIXED_PAYMENT_STATUS'; end if;

      -- Prepaid အပြည့် — တကယ် ငွေဖြတ်ထားမှ
      if g.any_prepaid_method or g.any_prepaid then
        if not g.all_prepaid then raise exception 'MIXED_PAYMENT_STATUS'; end if;
        if g.wallet_part > 0 then raise exception 'SPLIT_PAYMENT_INVALID'; end if;
        select -sum(amount) into paid from wallet_transactions
          where user_id = auth.uid() and type = 'purchase' and reference_id = g.order_group_id::text;
        if paid is null or paid <> g.total then raise exception 'PAYMENT_NOT_VERIFIED'; end if;
        if exists (select 1 from wallet_transactions where user_id = auth.uid() and type = 'refund' and reference_id = g.order_group_id::text) then
          raise exception 'PAYMENT_ALREADY_REFUNDED';
        end if;
      end if;

      -- ခွဲချေ (Prepaid တစ်စိတ် + KBZPay) — wallet_paid = တကယ် ဖြတ်ထားတဲ့ ငွေ ဖြစ်ရမည် (C1)
      if g.wallet_part > 0 then
        if g.wallet_part >= g.total then raise exception 'SPLIT_PAYMENT_INVALID'; end if;
        select -sum(amount) into paid from wallet_transactions
          where user_id = auth.uid() and type = 'purchase' and reference_id = g.order_group_id::text;
        if paid is null or paid <> g.wallet_part then raise exception 'PAYMENT_NOT_VERIFIED'; end if;
        if exists (select 1 from wallet_transactions where user_id = auth.uid() and type = 'refund' and reference_id = g.order_group_id::text) then
          raise exception 'PAYMENT_ALREADY_REFUNDED';
        end if;
      end if;

      -- Pay Later (H1) — ဖွင့်ထားမှ · တစ်ယောက် ၂ ခုထိ · ငွေလွှဲရမည့် အချိန် သတ်မှတ်
      if g.status = 'awaiting_payment' then
        if not pl_enabled then raise exception 'PAY_LATER_DISABLED'; end if;
        select count(distinct order_group_id) into open_cnt from orders
          where user_id = grp_user and order_status = 'awaiting_payment' and order_group_id <> g.order_group_id;
        if open_cnt >= 2 then raise exception 'PAY_LATER_LIMIT'; end if;
        update orders set payment_due_at = now() + make_interval(hours => pl_hours), payment_status = 'unpaid', viewed_by_admin = true
          where order_group_id = g.order_group_id;
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

  -- Stock လျှော့ခြင်း — Customer အတွက်သာ
  if not is_adm then
    for r in select product_name, size, color, quantity from new_rows
             where coalesce(sale_channel,'online') = 'online'
               and product_name not in ('🎁 Gift ထုပ်ပိုး ဝန်ဆောင်မှု','🏷️ Promo Code') loop
      if not _decrement_stock_internal(r.product_name, r.quantity, r.color, r.size) and not public.is_preorder(r.product_name) then
        raise exception 'OUT_OF_STOCK: %', r.product_name || coalesce(' (' || r.size || coalesce(', ' || r.color, '') || ')', '');
      end if;
    end loop;
  end if;
  return null;
end;
$function$;

-- ---------- C2 + M1: Refund တစ်ခါသာ (Order/Reference တစ်ခုကို ၂ ခါ ပြန်မအမ်း) ----------
create unique index if not exists wallet_tx_refund_once
  on public.wallet_transactions (user_id, reference_id)
  where type = 'refund' and reference_id is not null;

-- ---------- H2: ကာကွယ်ချက်မပါတဲ့ Function အဟောင်း ၂ ခု ဖျက် ----------
drop function if exists public.credit_wallet(uuid, numeric);
drop function if exists public.debit_wallet(numeric);

-- ---------- M2: credit_wallet = ငွေကိုင် Admin သာ (Delivery မရ) ----------
create or replace function public.credit_wallet(p_user_id uuid, p_amount numeric, p_type text default 'credit', p_description text default null, p_reference text default null)
returns void language plpgsql security definer set search_path = public as $function$
begin
  if not public.is_cashier() then
    raise exception 'PERMISSION_DENIED: admin only';
  end if;
  if p_type = 'refund' and p_reference is not null
     and exists (select 1 from wallet_transactions where user_id = p_user_id and type = 'refund' and reference_id = p_reference) then
    raise exception 'ALREADY_REFUNDED: ဒီ Order ကို ပြန်အမ်းပြီးသားပါ';
  end if;
  perform _wallet_credit_internal(p_user_id, p_amount, p_type, p_description, p_reference);
end;
$function$;
revoke execute on function public.credit_wallet(uuid, numeric, text, text, text) from anon;

-- ---------- debit_wallet: ပိတ်ထားတဲ့ Card နဲ့ ဝယ်မရ · Type ကန့်သတ် ----------
create or replace function public.debit_wallet(p_amount numeric, p_type text default 'debit', p_description text default null, p_reference text default null)
returns boolean language plpgsql security definer set search_path = public as $function$
declare
  cur numeric; frozen boolean;
  um text;
begin
  if auth.uid() is null or p_amount is null or p_amount <= 0 then
    return false;
  end if;
  if coalesce(p_type, '') not in ('purchase', 'pos_purchase', 'debit') then
    raise exception 'INVALID_DEBIT_TYPE';
  end if;
  if exists (select 1 from wallets where user_id = auth.uid() and coalesce(bio_required, false)) then
    um := public._consume_wallet_unlock();
    if um is null then raise exception 'AUTH_REQUIRED: Face ID (သို့) Card PIN ဖြင့် အတည်ပြုရန် လိုအပ်ပါသည်'; end if;
    if um = 'faceid' then p_description := coalesce(p_description, '') || ' · 🙂 Face ID'; end if;
  end if;
  select balance, coalesce(card_frozen, false) into cur, frozen from wallets where user_id = auth.uid() for update;
  if cur is null or frozen or cur < p_amount then
    return false;
  end if;
  update wallets set balance = balance - p_amount, updated_at = now() where user_id = auth.uid();
  insert into wallet_transactions (user_id, type, amount, description, reference_id)
  values (auth.uid(), p_type, -p_amount, p_description, p_reference);
  return true;
end;
$function$;
revoke execute on function public.debit_wallet(numeric, text, text, text) from anon;

-- ---------- M1: refund_failed_purchase — Lock နဲ့ (တစ်ပြိုင်နက် ၂ ခါ မရ) ----------
create or replace function public.refund_failed_purchase(p_reference text)
returns boolean language plpgsql security definer set search_path = public as $function$
declare t record;
begin
  if auth.uid() is null or p_reference is null then return false; end if;
  perform pg_advisory_xact_lock(hashtext('refund:' || auth.uid()::text || ':' || p_reference));
  select * into t from wallet_transactions
    where user_id = auth.uid() and type = 'purchase' and reference_id = p_reference
    order by created_at desc limit 1;
  if t is null then return false; end if;
  if exists (select 1 from orders where order_group_id::text = p_reference) then return false; end if;
  if exists (select 1 from wallet_transactions where user_id = auth.uid() and type = 'refund' and reference_id = p_reference) then return false; end if;
  perform _wallet_credit_internal(auth.uid(), abs(t.amount), 'refund', 'Order မအောင်မြင်၍ ပြန်အမ်းငွေ', p_reference);
  return true;
end;
$function$;

-- ---------- H3: ငွေဖြတ်ပြီး Order မဝင်ခဲ့ရင် ၁၀ မိနစ်နောက် အလိုလို ပြန်အမ်း ----------
create or replace function public.refund_orphan_purchases()
returns integer language plpgsql security definer set search_path = public as $function$
declare t record; n int := 0;
begin
  for t in
    select w.user_id, w.reference_id, -sum(w.amount) as amt
      from wallet_transactions w
     where w.type = 'purchase' and w.reference_id is not null
       and w.created_at < now() - interval '10 minutes'
       and w.created_at > now() - interval '7 days'
       and w.reference_id ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
       and not exists (select 1 from orders o where o.order_group_id::text = w.reference_id)
       and not exists (select 1 from qr_pay_requests q where q.id::text = w.reference_id)
       and not exists (select 1 from wallet_transactions x where x.user_id = w.user_id and x.type = 'refund' and x.reference_id = w.reference_id)
     group by w.user_id, w.reference_id
  loop
    if t.amt > 0 then
      perform _wallet_credit_internal(t.user_id, t.amt, 'refund', '⏰ Order မဝင်ခဲ့၍ အလိုအလျောက် ပြန်အမ်းငွေ', t.reference_id);
      perform _admin_alert('topup', '↩️ Order မဝင်ခဲ့လို့ Prepaid ' || to_char(t.amt, 'FM999,999,999') || ' ကျပ် အလိုလို ပြန်အမ်းပြီး', '/admin', 'orphan:' || t.reference_id);
      n := n + 1;
    end if;
  end loop;
  return n;
end;
$function$;
revoke execute on function public.refund_orphan_purchases() from anon, authenticated;

-- ---------- H3 + H4: Cron ----------
select cron.unschedule(jobid) from cron.job where jobname in ('suwati-refund-orphans', 'suwati-cancel-unpaid');
select cron.schedule('suwati-refund-orphans', '*/10 * * * *', 'select public.refund_orphan_purchases()');
select cron.schedule('suwati-cancel-unpaid', '*/10 * * * *', 'select public.cancel_expired_unpaid_orders()');

-- ---------- M2: ငွေ/Promo/Settings ကို Delivery Role ပြင်မရ ----------
drop policy if exists "Admin can update topups" on public.wallet_topups;
create policy "Admin can update topups" on public.wallet_topups for update using (is_cashier()) with check (is_cashier());
drop policy if exists "Admin can issue gift card" on public.gift_cards;
create policy "Admin can issue gift card" on public.gift_cards for insert with check (is_cashier());
drop policy if exists "Admin can update gift cards" on public.gift_cards;
create policy "Admin can update gift cards" on public.gift_cards for update using (is_cashier()) with check (is_cashier());
drop policy if exists "Admin manage promo codes" on public.promo_codes;
create policy "Admin manage promo codes" on public.promo_codes for all using (is_cashier()) with check (is_cashier());
drop policy if exists "Admin manage cashback" on public.cashback_campaigns;
create policy "Admin manage cashback" on public.cashback_campaigns for all using (is_cashier()) with check (is_cashier());
drop policy if exists "Admins manage bundle deals" on public.bundle_deals;
create policy "Admins manage bundle deals" on public.bundle_deals for all using (is_cashier()) with check (is_cashier());
drop policy if exists "Owner writes private settings" on public.admin_private_settings;
create policy "Owner writes private settings" on public.admin_private_settings for insert with check (is_owner());
drop policy if exists "Owner updates private settings" on public.admin_private_settings;
create policy "Owner updates private settings" on public.admin_private_settings for update using (is_owner()) with check (is_owner());

-- ---------- L1: POS Card ငွေဖြတ် — ပမာဏ/PIN NULL/မှား ၅ ကြိမ် Lock ----------
create or replace function public.pos_debit_by_card(p_card_number text, p_pin text, p_amount numeric)
returns jsonb language plpgsql security definer set search_path = public as $function$
declare
  w record; left_tries int;
begin
  if not public.is_cashier() then
    return jsonb_build_object('success', false, 'message', 'ခွင့်ပြုချက် မရှိပါ');
  end if;
  if p_amount is null or p_amount <= 0 then
    return jsonb_build_object('success', false, 'message', 'ငွေပမာဏ မမှန်ပါ');
  end if;
  if p_pin is null or p_pin !~ '^\d{4,6}$' then
    return jsonb_build_object('success', false, 'message', 'PIN ရိုက်ထည့်ပါ');
  end if;

  select * into w from wallets where replace(card_number,' ','') = replace(coalesce(p_card_number,''),' ','') for update;
  if w.user_id is null then
    return jsonb_build_object('success', false, 'message', 'Card Number မှားနေပါသည်');
  end if;
  if coalesce(w.card_frozen, false) then
    return jsonb_build_object('success', false, 'message', 'ဒီ Card ကို ပိတ်ထားပါသည်');
  end if;
  if w.card_pin is distinct from p_pin then
    update wallets set pin_fail_count = coalesce(pin_fail_count, 0) + 1 where user_id = w.user_id;
    left_tries := 5 - (coalesce(w.pin_fail_count, 0) + 1);
    if left_tries <= 0 then
      update wallets set card_frozen = true, frozen_reason = 'pin_lock' where user_id = w.user_id;
      return jsonb_build_object('success', false, 'message', '🔒 PIN ၅ ကြိမ် မှားလို့ Card ပိတ်လိုက်ပါပြီ');
    end if;
    return jsonb_build_object('success', false, 'message', 'PIN မှားနေပါသည် — ' || left_tries || ' ကြိမ် ကျန်');
  end if;
  if w.balance < p_amount then
    return jsonb_build_object('success', false, 'message', 'Balance မလုံလောက်ပါ — လက်ကျန်: '||w.balance||' ကျပ်');
  end if;

  update wallets set balance = balance - p_amount, pin_fail_count = 0, updated_at = now() where user_id = w.user_id;
  insert into wallet_transactions (user_id, type, amount, description, reference_id)
  values (w.user_id, 'pos_purchase', -p_amount, 'ဆိုင်တွင် Prepaid Card ဖြင့် ဝယ်ယူမှု', p_card_number);
  return jsonb_build_object('success', true, 'user_id', w.user_id, 'remaining_balance', w.balance - p_amount);
end;
$function$;
revoke execute on function public.pos_debit_by_card(text, text, numeric) from anon;

-- ---------- M9: Card No / PIN ကို Crypto Random နဲ့ ထုတ် ----------
create or replace function public._rand_digits(n int)
returns text language sql volatile set search_path = public, extensions as $$
  select string_agg((get_byte(b, i) % 10)::text, '')
    from (select extensions.gen_random_bytes(n) as b) x, generate_series(0, n - 1) i
$$;
revoke execute on function public._rand_digits(int) from anon, authenticated;

create or replace function public.get_or_create_card()
returns wallets language plpgsql security definer set search_path = public as $function$
declare
  w wallets; num text;
begin
  if auth.uid() is null then
    raise exception 'Login ဝင်ရန် လိုအပ်ပါသည်';
  end if;
  select * into w from wallets where user_id = auth.uid();
  if w.user_id is null or w.card_number is null then
    loop
      num := _rand_digits(4)||' '||_rand_digits(4)||' '||_rand_digits(4)||' '||_rand_digits(4);
      exit when not exists (select 1 from wallets where card_number = num);
    end loop;
  end if;
  if w.user_id is null then
    insert into wallets (user_id, balance, card_number, card_pin)
    values (auth.uid(), 0, num, _rand_digits(4))
    returning * into w;
  elsif w.card_number is null then
    update wallets set card_number = num, card_pin = _rand_digits(4)
    where user_id = auth.uid()
    returning * into w;
  end if;
  w.card_pin := null;   -- 🔒 PIN ကို reveal_card_pin() ကသာ ပေး
  return w;
end;
$function$;
revoke execute on function public.get_or_create_card() from anon;

-- ---------- M7: ပစ္စည်းနာမည် ထပ်မရ (Stock/ဈေး က နာမည်နဲ့ ချိတ်ထား) ----------
create unique index if not exists products_name_uniq on public.products (lower(btrim(name)));

-- ---------- L3: search_path သတ်မှတ် ----------
alter function public.prevent_owner_delete() set search_path = public;
alter function public.products_sync_stock() set search_path = public;
alter function public.track_order(text, text) set search_path = public;
alter function public._ckey(text) set search_path = public;
alter function public.norm_phone(text) set search_path = public;
alter function public.customer_ids_lock() set search_path = public;
alter function public.customer_code(bigint) set search_path = public;

-- ---------- Trigger Function တွေကို API ကနေ တိုက်ရိုက် မခေါ်ရ ----------
do $$
declare f record;
begin
  for f in
    select p.oid::regprocedure as sig from pg_proc p join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public' and p.prorettype = 'trigger'::regtype
  loop
    execute format('revoke execute on function %s from anon, authenticated, public', f.sig);
  end loop;
end $$;
revoke execute on function public.cancel_expired_unpaid_orders() from anon;

-- PUBLIC ကနေလည်း ပိတ် (Function တွေက မူလ PUBLIC Execute ခွင့် ရထား)
revoke execute on function public.refund_orphan_purchases() from public, anon, authenticated;
revoke execute on function public._rand_digits(int) from public, anon, authenticated;
revoke execute on function public.cancel_expired_unpaid_orders() from public, anon;
grant execute on function public.cancel_expired_unpaid_orders() to authenticated;
