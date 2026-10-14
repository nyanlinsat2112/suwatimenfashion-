-- =====================================================================
-- 🧩 SHOP EXTRA — SUWATI MEN FASHION
--   📍 လိပ်စာ အများကြီး သိမ်း · ⏳ Pre-order · 📣 Customer အားလုံးဆီ သတင်းပို့
--   🏷️ Barcode (SKU) · 📋 Stock ရေတွက်စစ်ဆေး · 🔍 Admin Login မှတ်တမ်း
-- Supabase → SQL Editor မှာ Run ပါ (ထပ် Run လည်း ဘေးမရှိ)
-- ⚠️ SALE.sql → AUTO-BACKUP-PUSH.sql → SHOP-PLUS.sql ကို အရင် Run ထားရပါမည်
-- =====================================================================

-- =====================================================================
-- ① 📍 Customer လိပ်စာ စာအုပ်
-- =====================================================================
create table if not exists customer_addresses (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  label text not null default 'အိမ်' check (char_length(label) <= 30),
  name text, phone text,
  region text not null, township text not null, detail text not null,
  last_used_at timestamptz default now(),
  created_at timestamptz default now()
);
create index if not exists customer_addresses_user_idx on customer_addresses (user_id, last_used_at desc);
alter table customer_addresses enable row level security;
drop policy if exists "Users manage own addresses" on customer_addresses;
create policy "Users manage own addresses" on customer_addresses for all
  using (user_id = auth.uid()) with check (user_id = auth.uid());
-- တစ်ယောက် လိပ်စာ ၁၀ ခုထက် မပို
create or replace function limit_customer_addresses() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if (select count(*) from customer_addresses where user_id = new.user_id) >= 10 then
    raise exception 'ADDRESS_LIMIT: လိပ်စာ ၁၀ ခုအထိသာ သိမ်းလို့ရပါသည်';
  end if;
  return new;
end $$;
drop trigger if exists trg_limit_customer_addresses on customer_addresses;
create trigger trg_limit_customer_addresses before insert on customer_addresses
  for each row execute function limit_customer_addresses();

-- =====================================================================
-- ② ⏳ PRE-ORDER — Stock မရှိလည်း ကြိုမှာလို့ရ
-- =====================================================================
alter table products add column if not exists preorder boolean default false;
alter table products add column if not exists preorder_eta date;
alter table products add column if not exists preorder_note text;
alter table orders add column if not exists is_preorder boolean default false;

create or replace function is_preorder(p_name text) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from products where name = p_name and coalesce(preorder, false))
$$;

-- Order ဝင်တာနဲ့ Pre-order ပစ္စည်းလား မှတ်
create or replace function mark_preorder_rows() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  new.is_preorder := public.is_preorder(new.product_name);
  return new;
end $$;
drop trigger if exists trg_mark_preorder_rows on orders;
create trigger trg_mark_preorder_rows before insert on orders
  for each row execute function mark_preorder_rows();

-- Order စစ်ချက် — Pre-order ပစ္စည်းဆို Stock မလုံလောက်လည်း လက်ခံ
do $$
declare d text;
begin
  d := pg_get_functiondef('public.verify_customer_orders()'::regprocedure);
  if position('is_preorder(r.product_name)' in d) > 0 then return; end if;
  if position('if not _decrement_stock_internal(r.product_name, r.quantity, r.color, r.size) then' in d) = 0 then
    raise exception 'verify_customer_orders() ထဲမှာ Stock စစ်တဲ့ စာကြောင်း မတွေ့ပါ — supabase-schema.sql ကို အရင် Run ပါ';
  end if;
  d := replace(d, 'if not _decrement_stock_internal(r.product_name, r.quantity, r.color, r.size) then',
                  'if not _decrement_stock_internal(r.product_name, r.quantity, r.color, r.size) and not public.is_preorder(r.product_name) then');
  execute d;
end $$;

-- =====================================================================
-- ③ 📣 Customer အားလုံး (သို့) အုပ်စုလိုက် သတင်းပို့ (Chat + ဖုန်း Notification)
-- =====================================================================
alter table chat_messages add column if not exists is_broadcast boolean default false;
create table if not exists broadcasts (
  id uuid primary key default gen_random_uuid(),
  message text not null,
  segment text not null,
  recipients int default 0,
  created_by uuid default auth.uid(),
  created_at timestamptz default now()
);
alter table broadcasts enable row level security;
drop policy if exists "Owner reads broadcasts" on broadcasts;
create policy "Owner reads broadcasts" on broadcasts for select using (is_owner());

-- ပို့မည့် Customer စာရင်း
create or replace function _broadcast_targets(p_segment text, p_min_spend numeric, p_days int)
returns table (user_id uuid, nm text)
language sql stable security definer set search_path = public as $$
  with cust as (
    select u.id, coalesce(u.raw_user_meta_data->>'full_name', split_part(u.email, '@', 1)) as nm
    from auth.users u where not exists (select 1 from admins a where a.user_id = u.id)
  ), spend as (
    select o.user_id, sum(o.total_amount) as total, max(o.created_at) as last_at
    from orders o where o.user_id is not null and o.order_status <> 'cancelled' group by o.user_id
  )
  select c.id, c.nm from cust c left join spend s on s.user_id = c.id
  where case p_segment
    when 'all' then true
    when 'buyers' then s.user_id is not null
    when 'vip' then coalesce(s.total, 0) >= coalesce(p_min_spend, 0)
    when 'inactive' then s.user_id is not null and s.last_at < now() - make_interval(days => greatest(coalesce(p_days, 60), 1))
    when 'never' then s.user_id is null
    else false end
$$;
revoke all on function _broadcast_targets(text, numeric, int) from public, anon, authenticated;

create or replace function broadcast_count(p_segment text, p_min_spend numeric default 0, p_days int default 60)
returns jsonb language plpgsql security definer set search_path = public as $$
declare t int; wp int;
begin
  if not is_owner() then raise exception 'OWNER_ONLY'; end if;
  select count(*), count(*) filter (where exists (select 1 from push_subscriptions ps where ps.user_id = x.user_id))
    into t, wp from _broadcast_targets(p_segment, p_min_spend, p_days) x;
  return jsonb_build_object('total', t, 'with_push', wp);
end $$;

create or replace function broadcast_send(p_message text, p_segment text, p_min_spend numeric default 0, p_days int default 60)
returns int language plpgsql security definer set search_path = public as $$
declare n int; msg text;
begin
  if not is_owner() then raise exception 'OWNER_ONLY'; end if;
  msg := trim(coalesce(p_message, ''));
  if char_length(msg) < 2 or char_length(msg) > 600 then raise exception 'INVALID_MESSAGE'; end if;
  -- ၁၀ မိနစ်အတွင်း ၃ ကြိမ်ထက် မပို (မှားနှိပ်မိတာ ကာကွယ်)
  if (select count(*) from broadcasts where created_at > now() - interval '10 minutes') >= 3 then
    raise exception 'TOO_MANY: ခဏစောင့်ပြီးမှ ထပ်ပို့ပါ';
  end if;
  if left(msg, 2) <> '📣' then msg := '📣 ' || msg; end if;
  insert into chat_messages (user_id, customer_name, sender, message, is_broadcast, read_by_admin, read_by_customer)
    select x.user_id, x.nm, 'admin', msg, true, true, false from _broadcast_targets(p_segment, p_min_spend, p_days) x;
  get diagnostics n = row_count;
  insert into broadcasts (message, segment, recipients) values (msg, p_segment || coalesce(':' || p_min_spend::text, ''), n);
  return n;
end $$;
revoke all on function broadcast_count(text, numeric, int) from public, anon;
revoke all on function broadcast_send(text, text, numeric, int) from public, anon;
grant execute on function broadcast_count(text, numeric, int) to authenticated;
grant execute on function broadcast_send(text, text, numeric, int) to authenticated;

-- =====================================================================
-- ④ 🏷️ BARCODE — ပစ္စည်းတိုင်း နံပါတ် (SKU) · Label: S{နံပါတ်}-{Size}-{အရောင်}
-- =====================================================================
create sequence if not exists products_sku_seq start 1001;
alter table products add column if not exists sku_code int;
alter table products alter column sku_code set default nextval('products_sku_seq');
update products set sku_code = nextval('products_sku_seq') where sku_code is null;
create unique index if not exists products_sku_code_key on products (sku_code);

-- =====================================================================
-- ⑤ 📋 STOCK ရေတွက်စစ်ဆေးခြင်း — ရေတွက်ထားတဲ့ ဂဏန်းအတိုင်း Stock ပြင် + မှတ်တမ်း
-- =====================================================================
alter table stock_movements drop constraint if exists stock_movements_kind_check;
alter table stock_movements add constraint stock_movements_kind_check check (kind in ('in', 'adjust', 'count'));

-- p_items = [{"name":"..","size":"M","color":"Black","counted":5}, ...]
create or replace function stocktake_apply(p_items jsonb, p_note text default null)
returns jsonb language plpgsql security definer set search_path = public as $$
declare it jsonb; p record; v_size text; v_color text; cur int; cnt int; changed int := 0; em text; tot_diff int := 0;
begin
  if not is_admin() then raise exception 'NOT_ADMIN'; end if;
  if not admin_can('edit_stock') then raise exception 'NO_PERMISSION: Stock ပြင်ခွင့် မရှိပါ'; end if;
  if jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) > 2000 then raise exception 'INVALID_ITEMS'; end if;
  perform set_config('suwati.stock_src', 'in', true);
  select email into em from auth.users where id = auth.uid();
  for it in select * from jsonb_array_elements(p_items) loop
    cnt := (it->>'counted')::int;
    if cnt is null or cnt < 0 or cnt > 100000 then continue; end if;
    select * into p from products where name = it->>'name' and coalesce(is_gift_card, false) = false for update;
    if not found then continue; end if;
    v_size := coalesce(nullif(it->>'size', ''), '_');
    v_color := coalesce(nullif(it->>'color', ''), '_');
    if p.variant_stock is not null and jsonb_typeof(p.variant_stock) = 'object' and p.variant_stock <> '{}'::jsonb then
      cur := coalesce(((p.variant_stock -> v_size) ->> v_color)::int, 0);
      if cur = cnt then continue; end if;
      update products set variant_stock = jsonb_set(variant_stock, array[v_size],
               coalesce(variant_stock -> v_size, '{}'::jsonb) || jsonb_build_object(v_color, cnt))
        where id = p.id;
    elsif p.color_stock is not null and jsonb_typeof(p.color_stock) = 'object' and p.color_stock <> '{}'::jsonb and v_color <> '_' then
      cur := coalesce((p.color_stock ->> v_color)::int, 0);
      if cur = cnt then continue; end if;
      update products set color_stock = color_stock || jsonb_build_object(v_color, cnt) where id = p.id;
    else
      cur := coalesce(p.stock_qty, 0);
      if cur = cnt then continue; end if;
      update products set stock_qty = cnt where id = p.id;
    end if;
    insert into stock_movements (product_name, size, color, qty_change, stock_after, kind, note, created_by_email)
      values (p.name, nullif(v_size, '_'), nullif(v_color, '_'), cnt - cur,
              (select stock_qty from products where id = p.id), 'count', coalesce(nullif(trim(p_note), ''), 'Stock ရေတွက်စစ်ဆေးခြင်း'), em);
    changed := changed + 1; tot_diff := tot_diff + (cnt - cur);
  end loop;
  return jsonb_build_object('ok', true, 'changed', changed, 'diff', tot_diff);
end $$;
revoke all on function stocktake_apply(jsonb, text) from public, anon;
grant execute on function stocktake_apply(jsonb, text) to authenticated;

-- =====================================================================
-- ⑥ 🔍 ADMIN LOGIN မှတ်တမ်း + ဖုန်း/ကွန်ပျူတာ အသစ်ကနေ ဝင်ရင် Owner ကို သတိပေး
-- =====================================================================
create table if not exists admin_logins (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid(),
  email text,
  device_id text,
  device_label text,
  user_agent text,
  is_new_device boolean default false,
  created_at timestamptz default now()
);
create index if not exists admin_logins_created_idx on admin_logins (created_at desc);
alter table admin_logins enable row level security;
drop policy if exists "Admins read own logins, owner all" on admin_logins;
create policy "Admins read own logins, owner all" on admin_logins for select using (user_id = auth.uid() or is_owner());

create or replace function record_admin_login(p_device_id text, p_label text, p_ua text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare em text; seen boolean; first_time boolean; recent boolean;
begin
  if not is_admin() then raise exception 'NOT_ADMIN'; end if;
  select email into em from auth.users where id = auth.uid();
  -- တစ်နာရီအတွင်း ဒီ Device ကနေ မှတ်ပြီးသားဆို ထပ်မမှတ်
  select exists (select 1 from admin_logins where user_id = auth.uid() and device_id = p_device_id and created_at > now() - interval '1 hour') into recent;
  if recent then return jsonb_build_object('ok', true, 'skipped', true); end if;
  select exists (select 1 from admin_logins where user_id = auth.uid() and device_id = p_device_id) into seen;
  select not exists (select 1 from admin_logins where user_id = auth.uid()) into first_time;
  insert into admin_logins (email, device_id, device_label, user_agent, is_new_device)
    values (em, left(p_device_id, 64), left(p_label, 80), left(p_ua, 300), not seen);
  if not seen and not first_time then
    insert into admin_alerts (kind, message)
      values ('new_login', '🆕 Device အသစ်ကနေ Admin Login ဝင်ထားပါသည် — ' || coalesce(em, '?') || ' · ' || coalesce(left(p_label, 80), '?') || ' — သင်မဟုတ်ရင် Password ချက်ချင်း ပြောင်းပါ');
  end if;
  return jsonb_build_object('ok', true, 'new_device', not seen);
end $$;
revoke all on function record_admin_login(text, text, text) from public, anon;
grant execute on function record_admin_login(text, text, text) to authenticated;

-- ✅ စစ်ရန်
select 'customer_addresses' as t, count(*) from customer_addresses
union all select 'broadcasts', count(*) from broadcasts
union all select 'admin_logins', count(*) from admin_logins
union all select 'products without sku', count(*) from products where sku_code is null;
