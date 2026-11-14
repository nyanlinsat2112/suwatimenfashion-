-- =====================================================================
-- SUWATI — Bug Fix SQL (15 Nov 2026) · Bug Report M6 · M9 · L2 · L9
-- ထပ် Run လည်း ဘေးမရှိ (idempotent) · Claude က Supabase MCP နဲ့ Run ပြီးသား
-- =====================================================================

-- ---------- M6: Order ပယ်/ပြန်ဖွင့် — Stock + Prepaid ငွေ ကို Database ကိုယ်တိုင် လုပ် ----------
-- (Admin Browser ကနေ အဆင့်လိုက် ခေါ်စရာ မလိုတော့ · Network ပြတ်လည်း တစ်ပြိုင်တည်း ဖြစ်)
create or replace function public.orders_on_status_change()
returns trigger language plpgsql security definer set search_path = public as $function$
declare
  r record; g record; amt numeric; uid uuid; pm text; short text := '';
begin
  if current_setting('suwati.restoring', true) = '1' then return null; end if;

  -- ① အသစ် ပယ်လိုက်တဲ့ Row — Stock ပြန်တိုး
  for r in
    select n.product_name, n.quantity, n.color, n.size
      from new_rows n join old_rows o on o.id = n.id
     where n.order_status = 'cancelled' and o.order_status is distinct from 'cancelled'
       and n.product_name not in ('🎁 Gift ထုပ်ပိုး ဝန်ဆောင်မှု', '🏷️ Promo Code')
  loop
    perform _increment_stock_internal(r.product_name, r.quantity, r.color, r.size);
  end loop;

  -- ② ပယ်ပြီးသားကို ပြန်ဖွင့် — Stock ပြန်လျှော့ (မလုံရင် Admin Noti)
  for r in
    select n.product_name, n.quantity, n.color, n.size
      from new_rows n join old_rows o on o.id = n.id
     where o.order_status = 'cancelled' and n.order_status is distinct from 'cancelled'
       and n.product_name not in ('🎁 Gift ထုပ်ပိုး ဝန်ဆောင်မှု', '🏷️ Promo Code')
  loop
    if not _decrement_stock_internal(r.product_name, r.quantity, r.color, r.size) then
      short := short || case when short = '' then '' else ', ' end || r.product_name;
    end if;
  end loop;
  if short <> '' then
    perform _admin_alert('low_stock', '⚠️ Order ပြန်ဖွင့် — Stock မလုံလောက်: ' || short, '/admin', null);
  end if;

  -- ③ အသစ် ပယ်လိုက်တဲ့ Order Group — Prepaid ငွေ ပြန်အမ်း (တစ်ခါသာ)
  for g in
    select distinct coalesce(n.order_group_id, n.id) as grp
      from new_rows n join old_rows o on o.id = n.id
     where n.order_status = 'cancelled' and o.order_status is distinct from 'cancelled'
  loop
    select max(user_id::text)::uuid, min(payment_method) into uid, pm
      from orders where coalesce(order_group_id, id) = g.grp;
    if pm in ('Prepaid Card', 'Wallet') then
      select coalesce(sum(total_amount), 0) into amt from orders where coalesce(order_group_id, id) = g.grp;
    else
      select coalesce(sum(coalesce(wallet_paid, 0)), 0) into amt from orders where coalesce(order_group_id, id) = g.grp;
    end if;
    if uid is not null and amt > 0
       and not exists (select 1 from wallet_transactions where user_id = uid and type = 'refund' and reference_id = g.grp::text) then
      perform _wallet_credit_internal(uid, amt, 'refund', 'Order Refund — #' || upper(left(g.grp::text, 8)), g.grp::text);
    end if;
  end loop;
  return null;
end;
$function$;
revoke execute on function public.orders_on_status_change() from public, anon, authenticated;

create or replace trigger trg_orders_on_status_change
  after update on public.orders
  referencing old table as old_rows new table as new_rows
  for each statement execute function public.orders_on_status_change();

-- Pay Later Auto/Customer ပယ် — Stock/ငွေ ကို အပေါ်က Trigger က လုပ်လို့ ဒီမှာ ထပ်မလုပ်
create or replace function public._cancel_unpaid_group(p_group uuid, p_reason text)
returns boolean language plpgsql security definer set search_path = public as $function$
begin
  perform 1 from orders where order_group_id = p_group and order_status = 'awaiting_payment' for update;
  if not found then return false; end if;
  update orders set order_status = 'cancelled', payment_status = 'cancelled', cancellation_reason = p_reason, viewed_by_admin = true
    where order_group_id = p_group and order_status = 'awaiting_payment';
  return true;
end;
$function$;
revoke execute on function public._cancel_unpaid_group(uuid, text) from public, anon, authenticated;

-- ---------- M9: Card PIN ကို Hash (bcrypt) နဲ့ သိမ်း ----------
-- PIN ကို ဘယ်သူမှ (Owner / Backup / Export) ပြန်မမြင်ရ · "PIN ကြည့်" = Face ID/Password/Google အတည်ပြုပြီး PIN အသစ် ထုတ်ပေး
create or replace function public._pin_hash(p text)
returns text language sql volatile set search_path = public, extensions as $$
  select case when p is null then null else extensions.crypt(p, extensions.gen_salt('bf', 8)) end
$$;
create or replace function public._pin_ok(stored text, given text)
returns boolean language sql stable set search_path = public, extensions as $$
  select stored is not null and given is not null and stored like '$2%' and extensions.crypt(given, stored) = stored
$$;
revoke execute on function public._pin_hash(text) from public, anon, authenticated;
revoke execute on function public._pin_ok(text, text) from public, anon, authenticated;

-- PIN စာသား (Backup Restore / Owner ပြင်) ဝင်လာရင် အလိုလို Hash
create or replace function public.wallets_hash_pin()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.card_pin is not null and new.card_pin not like '$2%' then
    new.card_pin := _pin_hash(new.card_pin);
  end if;
  return new;
end $$;
revoke execute on function public.wallets_hash_pin() from public, anon, authenticated;
create or replace trigger trg_wallets_hash_pin
  before insert or update of card_pin on public.wallets
  for each row execute function public.wallets_hash_pin();

-- ရှိပြီးသား PIN တွေ Hash ပြောင်း
update public.wallets set card_pin = card_pin where card_pin is not null and card_pin not like '$2%';

create or replace function public._check_card_pin(p_pin text)
returns text language plpgsql security definer set search_path = public as $function$
declare w record; left_tries int;
begin
  select * into w from wallets where user_id = auth.uid() for update;
  if w.user_id is null then return 'Card မရှိသေးပါ'; end if;
  if coalesce(w.card_frozen, false) then
    return case when w.frozen_reason = 'pin_lock' then '🔒 PIN မှား ၅ ကြိမ်ကြောင့် Card ပိတ်ထားပါသည် — Card နောက်ကျော PIN ကွက်ကို နှိပ်ပြီး PIN အသစ် ယူပါ' else '❄️ Card ကို ယာယီ ပိတ်ထားပါသည်' end;
  end if;
  if not _pin_ok(w.card_pin, p_pin) then
    update wallets set pin_fail_count = coalesce(pin_fail_count, 0) + 1 where user_id = w.user_id;
    left_tries := 5 - (coalesce(w.pin_fail_count, 0) + 1);
    if left_tries <= 0 then
      update wallets set card_frozen = true, frozen_reason = 'pin_lock' where user_id = w.user_id;
      return '🔒 PIN ၅ ကြိမ် မှားလို့ Card ကို ပိတ်လိုက်ပါပြီ — PIN အသစ် ယူမှ ပြန်ရပါမည်';
    end if;
    return 'PIN မှားနေပါသည် — နောက်ထပ် ' || left_tries || ' ကြိမ်သာ ကျန်ပါသည်';
  end if;
  update wallets set pin_fail_count = 0 where user_id = w.user_id;
  return null;
end $function$;

create or replace function public.change_card_pin(p_old text, p_new text)
returns jsonb language plpgsql security definer set search_path = public as $function$
declare w wallets;
begin
  if auth.uid() is null then return jsonb_build_object('ok', false, 'message', 'Login ဝင်ရန် လိုအပ်ပါသည်'); end if;
  if p_new is null or p_new !~ '^[0-9]{4}$' then return jsonb_build_object('ok', false, 'message', 'PIN အသစ်က ဂဏန်း ၄ လုံး ဖြစ်ရပါမည်'); end if;
  if p_new in ('0000','1111','2222','3333','4444','5555','6666','7777','8888','9999','1234','4321') then
    return jsonb_build_object('ok', false, 'message', 'ခန့်မှန်းရလွယ်တဲ့ PIN ပါ — တခြား ဂဏန်း ရွေးပါ');
  end if;
  select * into w from wallets where user_id = auth.uid() for update;
  if w.user_id is null then return jsonb_build_object('ok', false, 'message', 'Card မရှိသေးပါ'); end if;
  if not _pin_ok(w.card_pin, p_old) then
    update wallets set pin_fail_count = coalesce(pin_fail_count, 0) + 1,
           card_frozen = case when coalesce(pin_fail_count, 0) + 1 >= 5 then true else card_frozen end,
           frozen_reason = case when coalesce(pin_fail_count, 0) + 1 >= 5 then 'pin_lock' else frozen_reason end
     where user_id = auth.uid();
    return jsonb_build_object('ok', false, 'message', 'PIN အဟောင်း မှားနေပါသည် — မေ့သွားရင် Card နောက်ကျော PIN ကွက်ကို နှိပ်ပြီး PIN အသစ် ယူပါ');
  end if;
  if _pin_ok(w.card_pin, p_new) then return jsonb_build_object('ok', false, 'message', 'PIN အသစ်က အဟောင်းနဲ့ တူနေပါသည်'); end if;
  update wallets set card_pin = _pin_hash(p_new), pin_fail_count = 0,
         card_frozen = case when frozen_reason = 'pin_lock' then false else card_frozen end,
         frozen_reason = case when frozen_reason = 'pin_lock' then null else frozen_reason end,
         updated_at = now()
    where user_id = auth.uid();
  return jsonb_build_object('ok', true);
end;
$function$;

-- "PIN ကြည့်" → အတည်ပြုပြီး PIN အသစ် ထုတ်ပေး (တစ်ခါပြ) · PIN Lock ပါ ဖြည်
create or replace function public.reveal_card_pin()
returns text language plpgsql security definer set search_path = public as $function$
declare ok boolean := false; p text;
begin
  if auth.uid() is null then raise exception 'LOGIN_REQUIRED'; end if;
  update wallet_unlocks set used_at = now()
   where id = (select id from wallet_unlocks where user_id = auth.uid() and method = 'faceid' and used_at is null and expires_at > now()
               order by created_at limit 1 for update skip locked)
  returning true into ok;
  if not coalesce(ok, false) then
    select exists (select 1 from jsonb_array_elements(coalesce(auth.jwt() -> 'amr', '[]'::jsonb)) a
                    where a ->> 'method' in ('password', 'oauth')
                      and (a ->> 'timestamp')::bigint > extract(epoch from now())::bigint - 180)
      into ok;
  end if;
  if not coalesce(ok, false) then
    raise exception 'AUTH_REQUIRED: Face ID / Password / Google ဖြင့် အတည်ပြုပြီးမှ PIN အသစ် ယူလို့ရပါမည်';
  end if;
  if not exists (select 1 from wallets where user_id = auth.uid()) then raise exception 'Card မရှိသေးပါ'; end if;
  loop
    p := _rand_digits(4);
    exit when p not in ('0000','1111','2222','3333','4444','5555','6666','7777','8888','9999','1234','4321');
  end loop;
  update wallets set card_pin = _pin_hash(p), pin_fail_count = 0,
         card_frozen = case when frozen_reason = 'pin_lock' then false else card_frozen end,
         frozen_reason = case when frozen_reason = 'pin_lock' then null else frozen_reason end,
         updated_at = now()
   where user_id = auth.uid();
  return p;
end $function$;

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
    values (auth.uid(), 0, num, _pin_hash(_rand_digits(4)))
    returning * into w;
  elsif w.card_number is null then
    update wallets set card_number = num, card_pin = _pin_hash(_rand_digits(4))
    where user_id = auth.uid()
    returning * into w;
  end if;
  w.card_pin := null;
  return w;
end;
$function$;

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
  if not _pin_ok(w.card_pin, p_pin) then
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

-- ---------- L2: Order Track — Website ပြဖို့ လိုတာသာ ပြန်ပေး (Email/လိပ်စာ/ငွေ/User ID မပါ) ----------
create or replace function public.track_order(p_order_code text, p_phone text)
returns setof orders language plpgsql stable security definer set search_path = public as $function$
declare r orders; code text := upper(btrim(coalesce(p_order_code, '')));
begin
  if length(code) < 8 or coalesce(btrim(p_phone), '') = '' then return; end if;
  for r in
    select * from orders
     where norm_phone(phone) = norm_phone(p_phone)
       and (upper(left(coalesce(order_group_id::text, id::text), 8)) = left(code, 8)
            or upper(left(id::text, 8)) = left(code, 8))
     order by created_at
     limit 50
  loop
    r.email := null; r.address := null; r.phone := null; r.user_id := null;
    r.payment_screenshot_url := null; r.wallet_paid := null; r.split_payments := null;
    r.cashback_amount := null; r.gift_message := null; r.delivered_by := null;
    r.payment_method := null; r.promo_code := null;
    return next r;
  end loop;
end $function$;

-- ---------- L9: chat-images / delivery-photos = Private  (⏳ Owner ခွင့်ပြုမှ Run · index/admin Signed URL Code နဲ့ တွဲ) ----------
-- Website/Admin က Public URL ကို Signed URL (၁ နာရီ) နဲ့ အလိုလို အစားထိုးပြ (index.html / admin.html "Bug L9")
drop policy if exists "Customers view own chat images" on storage.objects;
create policy "Customers view own chat images" on storage.objects for select
  using (
    bucket_id = 'chat-images' and auth.uid() is not null and (
      (storage.foldername(name))[1] = auth.uid()::text
      or exists (select 1 from public.chat_messages m where m.user_id = auth.uid() and m.image_url like '%' || name || '%')
    )
  );
drop policy if exists "Customers view own delivery photos" on storage.objects;
create policy "Customers view own delivery photos" on storage.objects for select
  using (
    bucket_id = 'delivery-photos' and auth.uid() is not null
    and exists (select 1 from public.orders o where o.user_id = auth.uid() and o.delivery_photo_url like '%' || name)
  );
update storage.buckets set public = false where id in ('chat-images', 'delivery-photos');
