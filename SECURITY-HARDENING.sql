-- =====================================================================
-- 🔐 SECURITY HARDENING — SUWATI MEN FASHION
-- supabase-schema.sql ရဲ့ အဆုံးမှာလည်း ထည့်ထားပြီးသားပါ (ဒီဖိုင်ကို သီးသန့် Run လည်း ရပါသည်၊ ထပ်ခါ Run လည်း ဘေးမရှိပါ)
-- =====================================================================

-- ---------- [CRITICAL 1] Wallet ငွေဖြည့်ခြင်း — Admin ချည်းသာ ----------
-- ယခင်က Login ဝင်ထားသူ ဘယ်သူမဆို credit_wallet ကို ခေါ်ပြီး ကိုယ့် Prepaid Card ထဲ ငွေ ကိုယ်တိုင် ထည့်လို့ ရနေခဲ့သည်
create or replace function _wallet_credit_internal(p_user_id uuid, p_amount numeric, p_type text, p_description text, p_reference text)
returns void as $$
begin
  if p_user_id is null or p_amount is null or p_amount <= 0 then
    raise exception 'INVALID_CREDIT_AMOUNT';
  end if;
  insert into wallets (user_id, balance) values (p_user_id, p_amount)
  on conflict (user_id) do update set balance = wallets.balance + p_amount, updated_at = now();
  insert into wallet_transactions (user_id, type, amount, description, reference_id)
  values (p_user_id, p_type, p_amount, p_description, p_reference);
end;
$$ language plpgsql security definer set search_path = public;
revoke all on function _wallet_credit_internal(uuid, numeric, text, text, text) from public, anon, authenticated;

create or replace function credit_wallet(p_user_id uuid, p_amount numeric, p_type text default 'credit', p_description text default null, p_reference text default null)
returns void as $$
begin
  if not is_admin() then
    raise exception 'PERMISSION_DENIED: admin only';
  end if;
  perform _wallet_credit_internal(p_user_id, p_amount, p_type, p_description, p_reference);
end;
$$ language plpgsql security definer set search_path = public;
revoke all on function credit_wallet(uuid, numeric, text, text, text) from public, anon;
grant execute on function credit_wallet(uuid, numeric, text, text, text) to authenticated;

-- ---------- [CRITICAL 2] Wallet နုတ်ခြင်း — အနုတ်ပမာဏ (Negative) ဖြင့် ငွေတိုးမရအောင် ----------
create or replace function debit_wallet(p_amount numeric, p_type text default 'debit', p_description text default null, p_reference text default null)
returns boolean as $$
declare
  cur numeric;
begin
  if auth.uid() is null or p_amount is null or p_amount <= 0 then
    return false;
  end if;
  select balance into cur from wallets where user_id = auth.uid() for update;
  if cur is null or cur < p_amount then
    return false;
  end if;
  update wallets set balance = balance - p_amount, updated_at = now() where user_id = auth.uid();
  insert into wallet_transactions (user_id, type, amount, description, reference_id)
  values (auth.uid(), p_type, -p_amount, p_description, p_reference);
  return true;
end;
$$ language plpgsql security definer set search_path = public;
revoke all on function debit_wallet(numeric, text, text, text) from public, anon;
grant execute on function debit_wallet(numeric, text, text, text) to authenticated;

-- Order တင်တာ မအောင်မြင်ရင် Customer ကိုယ်တိုင် ပြန်အမ်းငွေ ရနိုင်ရန် (Order မဝင်ရသေးတဲ့ ကိုယ့်ငွေနုတ်မှုကိုသာ၊ တစ်ကြိမ်သာ)
create or replace function refund_failed_purchase(p_reference text)
returns boolean as $$
declare
  t record;
begin
  if auth.uid() is null or p_reference is null then return false; end if;
  select * into t from wallet_transactions
    where user_id = auth.uid() and type = 'purchase' and reference_id = p_reference
    order by created_at desc limit 1;
  if t is null then return false; end if;
  if exists (select 1 from orders where order_group_id::text = p_reference) then return false; end if;
  if exists (select 1 from wallet_transactions where user_id = auth.uid() and type = 'refund' and reference_id = p_reference) then return false; end if;
  perform _wallet_credit_internal(auth.uid(), abs(t.amount), 'refund', 'Order မအောင်မြင်၍ ပြန်အမ်းငွေ', p_reference);
  return true;
end;
$$ language plpgsql security definer set search_path = public;
revoke all on function refund_failed_purchase(text) from public, anon;
grant execute on function refund_failed_purchase(text) to authenticated;

-- Gift Card Redeem — Internal Credit Function ကို သုံးအောင် ပြန်ရေး
create or replace function redeem_gift_card(p_code text)
returns jsonb as $$
declare
  gc record;
begin
  if auth.uid() is null then
    return jsonb_build_object('success', false, 'message', 'Login ဝင်ရန် လိုအပ်ပါသည်');
  end if;
  select * into gc from gift_cards where upper(code) = upper(trim(p_code)) for update;
  if gc is null then
    return jsonb_build_object('success', false, 'message', 'Gift Card Code မှားနေပါသည်');
  end if;
  if gc.status = 'redeemed' then
    return jsonb_build_object('success', false, 'message', 'ဒီ Gift Card ကို အသုံးပြုပြီးသားဖြစ်ပါသည်');
  end if;
  if gc.status != 'active' then
    return jsonb_build_object('success', false, 'message', 'ဒီ Gift Card က အသုံးပြုရန် အသင့် မဖြစ်သေးပါ');
  end if;
  update gift_cards set status = 'redeemed', redeemed_by = auth.uid(), redeemed_at = now() where id = gc.id;
  perform _wallet_credit_internal(auth.uid(), gc.amount, 'gift_card_redeem', 'Gift Card သုံးစွဲမှု — '||gc.code, gc.code);
  return jsonb_build_object('success', true, 'amount', gc.amount);
end;
$$ language plpgsql security definer set search_path = public;
revoke all on function redeem_gift_card(text) from public, anon;
grant execute on function redeem_gift_card(text) to authenticated;

-- ---------- [CRITICAL 3] Gift Card — Customer က "Active" Card ကို ကိုယ်တိုင် ဖန်တီးပြီး Redeem မလုပ်နိုင်အောင် ----------
drop policy if exists "Customer can purchase gift card" on gift_cards;
create policy "Customer can purchase gift card" on gift_cards for insert
  with check (auth.uid() = purchased_by and status = 'pending' and redeemed_by is null and redeemed_at is null and reviewed_by is null);

drop policy if exists "Customer can create own topup" on wallet_topups;
create policy "Customer can create own topup" on wallet_topups for insert
  with check (auth.uid() = user_id and coalesce(status,'pending') = 'pending' and reviewed_by is null and reviewed_at is null);

-- ---------- [CRITICAL 4] Order — ငွေမပေးဘဲ "Confirmed" Order / ဈေးလျှော့ပြင်ထားတဲ့ Order မတင်နိုင်အောင် ----------
drop policy if exists "Public can create orders" on orders;
create policy "Public can create orders" on orders for insert
  with check (
    is_admin() or (
      coalesce(sale_channel,'online') = 'online'
      and (user_id is null or user_id = auth.uid())
      and coalesce(discount_amount,0) = 0
      and quantity > 0 and total_amount >= 0
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
  g record;
  gift_price numeric;
  paid numeric;
  bad text;
begin
  if is_admin() then return null; end if;
  select coalesce(gift_wrap_price, 4500) into gift_price from settings where id = 1;
  gift_price := coalesce(gift_price, 4500);

  -- ဈေးနှုန်း စစ်ဆေး (Browser ကနေ ဈေးပြင်ပြီး တင်တာကို ကာကွယ်)
  select string_agg(n.product_name, ', ') into bad
  from new_rows n
  left join products p on p.name = n.product_name and coalesce(p.is_gift_card,false) = false
  where n.total_amount <> n.unit_price * n.quantity
     or not (
       (n.product_name = '🎁 Gift ထုပ်ပိုး ဝန်ဆောင်မှု' and n.quantity = 1 and n.unit_price = gift_price)
       or (p.id is not null and n.unit_price = p.price)
     );
  if bad is not null then
    raise exception 'PRICE_MISMATCH: %', bad;
  end if;

  for g in
    select order_group_id, sum(total_amount) as total, count(*) as cnt,
           bool_or(order_status = 'confirmed') as any_prepaid, bool_and(order_status = 'confirmed') as all_prepaid
    from new_rows group by order_group_id
  loop
    if g.order_group_id is null then raise exception 'MISSING_ORDER_GROUP'; end if;
    if (select count(*) from orders where order_group_id = g.order_group_id) <> g.cnt then
      raise exception 'DUPLICATE_ORDER_GROUP';
    end if;
    if g.any_prepaid then
      if not g.all_prepaid then raise exception 'MIXED_PAYMENT_STATUS'; end if;
      select -sum(amount) into paid from wallet_transactions
        where user_id = auth.uid() and type = 'purchase' and reference_id = g.order_group_id::text;
      if paid is null or paid <> g.total then
        raise exception 'PAYMENT_NOT_VERIFIED';
      end if;
      if exists (select 1 from wallet_transactions where user_id = auth.uid() and type = 'refund' and reference_id = g.order_group_id::text) then
        raise exception 'PAYMENT_ALREADY_REFUNDED';
      end if;
    end if;
  end loop;
  return null;
end;
$$ language plpgsql security definer set search_path = public;

drop trigger if exists trg_verify_customer_orders on orders;
create trigger trg_verify_customer_orders
  after insert on orders
  referencing new table as new_rows
  for each statement execute function verify_customer_orders();

-- ---------- [HIGH] Customer က Order မှတ်တမ်းကို တကယ် မဖျက်နိုင်အောင် (ဆိုင်ရဲ့ အရောင်းမှတ်တမ်း မပျောက်စေရန်) ----------
-- Customer ဘက်မှာ "ဖျက်မည်" နှိပ်ရင် သူ့ History ထဲကနေပဲ ဖျောက်ပေးမည် — Admin ဘက်မှာ မှတ်တမ်း ဆက်ရှိနေမည်
alter table orders add column if not exists hidden_by_customer boolean default false;
update orders set hidden_by_customer = false where hidden_by_customer is null;
drop policy if exists "Customer can delete own orders" on orders;

create or replace function hide_my_orders(p_ids text[] default null)
returns int as $$
declare n int;
begin
  if auth.uid() is null then return 0; end if;
  update orders set hidden_by_customer = true
    where user_id = auth.uid() and (p_ids is null or id::text = any(p_ids));
  get diagnostics n = row_count;
  return n;
end;
$$ language plpgsql security definer set search_path = public;
revoke all on function hide_my_orders(text[]) from public, anon;
grant execute on function hide_my_orders(text[]) to authenticated;

-- ---------- [HIGH] Staff ကိုယ်ရေးအချက်အလက် (Email/ဖုန်း/မွေးနေ့/လိပ်စာ) ကို လူတိုင်း ဖတ်လို့ မရအောင် ----------
drop policy if exists "Anyone can check admin table" on admins;
drop policy if exists "Admins readable by self or admins" on admins;
create policy "Admins readable by self or admins" on admins for select
  using (user_id = auth.uid() or is_admin());

-- ---------- [MEDIUM] Customer က Chat Message ကို ပြင်လို့ မရအောင် (ဖတ်ပြီး မှတ်ခြင်း/အမည်ပြောင်းခြင်းသာ) ----------
create or replace function protect_chat_message_update()
returns trigger as $$
declare
  keep_read boolean := new.read_by_customer;
  keep_name text := new.customer_name;
begin
  if is_admin() then return new; end if;
  new := old;
  new.read_by_customer := keep_read;
  new.customer_name := keep_name;
  return new;
end;
$$ language plpgsql security definer set search_path = public;
drop trigger if exists trg_protect_chat_message_update on chat_messages;
create trigger trg_protect_chat_message_update before update on chat_messages
  for each row execute function protect_chat_message_update();

-- ---------- [MEDIUM] Admin-only Functions များ ကို Login မဝင်သူ မခေါ်နိုင်အောင် ----------
do $$ begin
  begin revoke all on function pos_debit_by_card(text, text, numeric) from public, anon; exception when others then null; end;
  begin grant execute on function pos_debit_by_card(text, text, numeric) to authenticated; exception when others then null; end;
end $$;
