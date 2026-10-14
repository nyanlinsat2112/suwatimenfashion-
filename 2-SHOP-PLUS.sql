-- =====================================================================
-- 🛍️ SHOP PLUS — SUWATI MEN FASHION
--   Customer : ⭐ Review · 📦 Bundle Deal · 🛒 ခြင်းထဲ ကျန်နေရင် သတိပေး
--   Admin    : 🔐 2FA · 📥 ပစ္စည်းအဝင် မှတ်တမ်း · 📉 Stock နည်းရင် ဖုန်းသတိပေး · 👥 Staff လုပ်ပိုင်ခွင့်
-- Supabase → SQL Editor မှာ ဒီဖိုင်တစ်ခုလုံး Run ပါ (ထပ် Run လည်း ဘေးမရှိ)
-- ⚠️ SALE.sql ကို အရင် Run ထားရပါမည်
-- =====================================================================

-- =====================================================================
-- ① ⭐ REVIEW / RATING — ပစ္စည်းရောက်ပြီးသူမှ ရေးခွင့် · Admin စစ်ပြီးမှ ပြ
-- =====================================================================
create table if not exists product_reviews (
  id uuid primary key default gen_random_uuid(),
  product_name text not null,
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  reviewer_name text,
  rating int not null check (rating between 1 and 5),
  comment text check (char_length(comment) <= 1000),
  photo_url text,
  size_bought text,
  status text not null default 'pending' check (status in ('pending','approved','hidden')),
  admin_reply text,
  created_at timestamptz default now(),
  unique (user_id, product_name)
);
create index if not exists product_reviews_product_idx on product_reviews (product_name, status);
alter table product_reviews enable row level security;

drop policy if exists "Approved reviews are public" on product_reviews;
create policy "Approved reviews are public" on product_reviews for select
  using (status = 'approved' or user_id = auth.uid() or is_admin());
drop policy if exists "Buyers can write a review" on product_reviews;
create policy "Buyers can write a review" on product_reviews for insert
  with check (
    user_id = auth.uid() and status = 'pending' and admin_reply is null
    and exists (select 1 from orders o where o.user_id = auth.uid() and o.product_name = product_reviews.product_name and o.order_status = 'delivered')
  );
drop policy if exists "Users delete own review" on product_reviews;
create policy "Users delete own review" on product_reviews for delete using (user_id = auth.uid() or is_admin());
drop policy if exists "Admins moderate reviews" on product_reviews;
create policy "Admins moderate reviews" on product_reviews for update using (is_admin()) with check (is_admin());

-- Review ပုံ (Public ကြည့်ခွင့် · ကိုယ့် Folder ထဲသာ တင်ခွင့်)
insert into storage.buckets (id, name, public) values ('review-photos', 'review-photos', true)
  on conflict (id) do update set public = true;
drop policy if exists "Users upload own review photos" on storage.objects;
create policy "Users upload own review photos" on storage.objects for insert
  with check (bucket_id = 'review-photos' and auth.uid() is not null and (storage.foldername(name))[1] = auth.uid()::text);
drop policy if exists "Anyone can view review photos" on storage.objects;
create policy "Anyone can view review photos" on storage.objects for select using (bucket_id = 'review-photos');
drop policy if exists "Admins delete review photos" on storage.objects;
create policy "Admins delete review photos" on storage.objects for delete using (bucket_id = 'review-photos' and is_admin());

-- =====================================================================
-- ② 📦 BUNDLE DEAL — "၃ ထည်ဝယ် 10% off" · Category တစ်ခုချင်း (သို့) အားလုံး
-- =====================================================================
create table if not exists bundle_deals (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  min_qty int not null check (min_qty >= 2),
  discount_pct numeric not null check (discount_pct > 0 and discount_pct < 90),
  category text,                       -- null = ပစ္စည်းအားလုံး
  active boolean default true,
  starts_at timestamptz,
  ends_at timestamptz,
  created_at timestamptz default now()
);
alter table bundle_deals enable row level security;
drop policy if exists "Bundle deals are public" on bundle_deals;
create policy "Bundle deals are public" on bundle_deals for select using (true);
drop policy if exists "Admins manage bundle deals" on bundle_deals;
create policy "Admins manage bundle deals" on bundle_deals for all using (is_admin()) with check (is_admin());

-- ခြင်းထဲ ပစ္စည်းများ (grp = [{c:category,q:qty},...]) အရ ဒီပစ္စည်းရဲ့ Bundle ဈေး (မကိုက်ရင် null)
create or replace function bundle_unit_price(p_eff numeric, p_cat text, p_grp jsonb) returns numeric
language sql stable set search_path = public as $$
  -- မကိုက်ရင် -1 (null ဆိုရင် Order စစ်ချက်ထဲ NOT(... or null) ဖြစ်ပြီး ကျော်သွားနိုင်လို့)
  select case when best is null then -1 else round(p_eff * (100 - best) / 100) end
  from (
    select max(b.discount_pct) as best from bundle_deals b
    where b.active
      and (b.starts_at is null or now() >= b.starts_at)
      and (b.ends_at is null or now() < b.ends_at)
      and (b.category is null or b.category = p_cat)
      and (select coalesce(sum((e->>'q')::int), 0) from jsonb_array_elements(coalesce(p_grp, '[]'::jsonb)) e
           where b.category is null or e->>'c' = b.category) >= b.min_qty
  ) t
$$;

-- Order စစ်တဲ့ verify_customer_orders() — Bundle ဈေးကိုပါ လက်ခံ
do $$
declare d text; bundle_expr text;
begin
  d := pg_get_functiondef('public.verify_customer_orders()'::regprocedure);
  if position('bundle_unit_price' in d) > 0 then return; end if;
  bundle_expr := 'n.unit_price = public.bundle_unit_price(public.product_price(p), coalesce(p.category, ''Top Wear''), '
    || '(select jsonb_agg(jsonb_build_object(''c'', coalesce(px.category, ''Top Wear''), ''q'', x.quantity)) from new_rows x '
    || 'join products px on px.name = x.product_name and coalesce(px.is_gift_card, false) = false '
    || 'where x.order_group_id = n.order_group_id))';
  if position('(n.unit_price = public.product_price(p) or n.unit_price = p.price)' in d) > 0 then
    d := replace(d, '(n.unit_price = public.product_price(p) or n.unit_price = p.price)',
                    '(n.unit_price = public.product_price(p) or n.unit_price = p.price or ' || bundle_expr || ')');
  elsif position('(p.id is not null and n.unit_price = p.price)' in d) > 0 then
    d := replace(d, '(p.id is not null and n.unit_price = p.price)',
                    '(p.id is not null and (n.unit_price = public.product_price(p) or n.unit_price = p.price or ' || bundle_expr || '))');
  else
    raise exception 'verify_customer_orders() ထဲမှာ ဈေးစစ်တဲ့ စာကြောင်း မတွေ့ပါ — supabase-schema.sql နဲ့ SALE.sql ကို အရင် Run ပါ';
  end if;
  execute d;
end $$;

-- =====================================================================
-- ③ 🛒 ခြင်းထဲ ကျန်နေရင် သတိပေး (Login ဝင်ထားသူ · Chat + ဖုန်း Notification)
-- =====================================================================
alter table settings add column if not exists cart_reminder_hours int default 24;   -- 0 = ပိတ်
create table if not exists cart_snapshots (
  user_id uuid primary key default auth.uid() references auth.users(id) on delete cascade,
  items jsonb not null default '[]'::jsonb,
  item_count int not null default 0,
  updated_at timestamptz default now(),
  reminded_at timestamptz
);
alter table cart_snapshots enable row level security;
drop policy if exists "Users manage own cart snapshot" on cart_snapshots;
create policy "Users manage own cart snapshot" on cart_snapshots for all
  using (user_id = auth.uid()) with check (user_id = auth.uid());

create or replace function remind_abandoned_carts() returns int
language plpgsql security definer set search_path = public as $$
declare h int; n int := 0; r record; first_name text;
begin
  select coalesce(cart_reminder_hours, 24) into h from settings where id = 1;
  h := coalesce(h, 24);
  if h <= 0 then return 0; end if;
  for r in
    select c.user_id, c.items, c.item_count,
           coalesce(u.raw_user_meta_data->>'full_name', u.email) as nm
    from cart_snapshots c join auth.users u on u.id = c.user_id
    where c.item_count > 0
      and c.updated_at < now() - make_interval(hours => h)
      and c.updated_at > now() - interval '7 days'
      and (c.reminded_at is null or c.reminded_at < c.updated_at)
    limit 200
  loop
    first_name := coalesce(r.items->0->>'name', 'ပစ္စည်း');
    insert into chat_messages (user_id, customer_name, sender, message)
    values (r.user_id, r.nm, 'admin',
      '🛒 ခြင်းထဲမှာ "' || first_name || '"' ||
      case when r.item_count > 1 then ' အပါအဝင် ပစ္စည်း ' || r.item_count || ' ခု' else '' end ||
      ' ကျန်နေပါသေးတယ် — Stock မကုန်ခင် ဝယ်ယူလိုက်ပါဦး 🛍️');
    update cart_snapshots set reminded_at = now() where user_id = r.user_id;
    n := n + 1;
  end loop;
  return n;
end $$;
revoke all on function remind_abandoned_carts() from public, anon, authenticated;

-- နာရီတိုင်း စစ် (pg_cron — AUTO-BACKUP-PUSH.sql မှာ ဖွင့်ပြီးသား)
do $$
begin
  if exists (select 1 from pg_namespace where nspname = 'cron') then
    begin perform cron.unschedule('suwati-cart-reminder'); exception when others then null; end;
    perform cron.schedule('suwati-cart-reminder', '15 * * * *', 'select public.remind_abandoned_carts()');
  else
    raise notice 'pg_cron မဖွင့်ရသေးပါ — AUTO-BACKUP-PUSH.sql ကို Run ပြီးမှ ဒီဖိုင်ကို ပြန် Run ပါ';
  end if;
end $$;

-- =====================================================================
-- ④ 👥 STAFF လုပ်ပိုင်ခွင့်
--   edit_product (ပစ္စည်းထည့်/ပြင်) · edit_price (ဈေး/Sale) · edit_stock (Stock) · delete_product · refund
--   allowed_actions = null → Refund ပဲ ရ (အရင်အတိုင်း) · Owner အမြဲ အကုန်ရ
-- =====================================================================
alter table admins add column if not exists allowed_actions text[];

-- 🔐 2FA — 2FA ဖွင့်ထားတဲ့ Admin က Code မရိုက်ရသေးရင် Admin ခွင့် မရ
create or replace function mfa_ok() returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce(auth.jwt()->>'aal', 'aal1') = 'aal2'
      or not exists (select 1 from auth.mfa_factors f where f.user_id = auth.uid() and f.status::text = 'verified')
$$;
create or replace function is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from admins where user_id = auth.uid()) and public.mfa_ok()
$$;
create or replace function is_owner() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from admins where user_id = auth.uid() and role = 'owner') and public.mfa_ok()
$$;

create or replace function admin_can(p_action text) returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce((
    select case
      when a.role = 'owner' then true
      when a.role = 'delivery' then false
      when a.allowed_actions is null then p_action = 'refund'
      else p_action = any(a.allowed_actions)
    end
    from admins a where a.user_id = auth.uid()
  ), false) and public.mfa_ok()
$$;

create or replace function products_permission_guard() returns trigger
language plpgsql security definer set search_path = public as $$
declare src text := coalesce(current_setting('suwati.stock_src', true), '');
begin
  if auth.uid() is null or not exists (select 1 from admins where user_id = auth.uid()) then
    return coalesce(new, old);   -- Customer Order / System — Stock function တွေက လုပ်တာ
  end if;
  if tg_op = 'DELETE' then
    if not admin_can('delete_product') then raise exception 'NO_PERMISSION: ပစ္စည်းဖျက်ခွင့် မရှိပါ'; end if;
    return old;
  end if;
  if tg_op = 'INSERT' then
    if not (admin_can('edit_product') and admin_can('edit_price')) then raise exception 'NO_PERMISSION: ပစ္စည်းအသစ် ထည့်ခွင့် မရှိပါ'; end if;
    return new;
  end if;
  if (to_jsonb(new) - array['price','sale_price','sale_start','sale_end','variant_stock','color_stock','stock_qty','status'])
     is distinct from (to_jsonb(old) - array['price','sale_price','sale_start','sale_end','variant_stock','color_stock','stock_qty','status'])
     and not admin_can('edit_product') then
    raise exception 'NO_PERMISSION: ပစ္စည်းပြင်ခွင့် မရှိပါ';
  end if;
  if (new.price is distinct from old.price or new.sale_price is distinct from old.sale_price
      or new.sale_start is distinct from old.sale_start or new.sale_end is distinct from old.sale_end)
     and not admin_can('edit_price') then
    raise exception 'NO_PERMISSION: ဈေးပြင်ခွင့် / Sale ချခွင့် မရှိပါ';
  end if;
  if src not in ('auto', 'in')
     and (new.variant_stock is distinct from old.variant_stock or new.color_stock is distinct from old.color_stock
          or new.stock_qty is distinct from old.stock_qty)
     and not admin_can('edit_stock') then
    raise exception 'NO_PERMISSION: Stock ပြင်ခွင့် မရှိပါ';
  end if;
  return new;
end $$;
drop trigger if exists trg_products_permission_guard on products;
create trigger trg_products_permission_guard before insert or update or delete on products
  for each row execute function products_permission_guard();

-- ပစ္စည်း ထည့်/ပြင်/ဖျက် — Admin အားလုံး (ခွင့်ရှိ/မရှိကို အပေါ်က Guard က စစ်)
drop policy if exists "Owner can manage products" on products;
drop policy if exists "Admins insert products" on products;
drop policy if exists "Admins update products" on products;
drop policy if exists "Admins delete products" on products;
create policy "Admins insert products" on products for insert with check (is_admin());
create policy "Admins update products" on products for update using (is_admin()) with check (is_admin());
create policy "Admins delete products" on products for delete using (is_admin());

create or replace function orders_refund_guard() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.payment_status = 'refunded' and old.payment_status is distinct from 'refunded'
     and exists (select 1 from admins where user_id = auth.uid()) and not admin_can('refund') then
    raise exception 'NO_PERMISSION: Refund/Void လုပ်ခွင့် မရှိပါ';
  end if;
  return new;
end $$;
drop trigger if exists trg_orders_refund_guard on orders;
create trigger trg_orders_refund_guard before update on orders
  for each row execute function orders_refund_guard();

-- =====================================================================
-- ⑤ 📥 ပစ္စည်းအဝင် / Stock ပြင်ဆင်မှု မှတ်တမ်း
-- =====================================================================
create table if not exists stock_movements (
  id uuid primary key default gen_random_uuid(),
  product_name text not null,
  size text, color text,
  qty_change int not null,
  stock_after int,
  kind text not null check (kind in ('in','adjust')),
  supplier text, note text,
  created_by uuid default auth.uid(),
  created_by_email text,
  created_at timestamptz default now()
);
create index if not exists stock_movements_created_idx on stock_movements (created_at desc);
alter table stock_movements enable row level security;
drop policy if exists "Admins read stock movements" on stock_movements;
create policy "Admins read stock movements" on stock_movements for select using (is_admin());

-- ဝယ်ဈေး (Owner ချည်းသာ မြင်)
create table if not exists stock_in_costs (
  movement_id uuid primary key references stock_movements(id) on delete cascade,
  unit_cost numeric not null
);
alter table stock_in_costs enable row level security;
drop policy if exists "Owner reads stock-in costs" on stock_in_costs;
create policy "Owner reads stock-in costs" on stock_in_costs for select using (is_owner());

-- Order/Cancel ကြောင့် Stock ပြောင်းတာ — "auto" လို့ မှတ် (မှတ်တမ်းထဲ မထည့်)
do $$
declare fn text; d text;
begin
  foreach fn in array array['public._decrement_stock_internal(text,integer,text,text)', 'public._increment_stock_internal(text,integer,text,text)'] loop
    begin
      d := pg_get_functiondef(fn::regprocedure);
    exception when others then continue;
    end;
    if position('suwati.stock_src' in d) = 0 then
      d := regexp_replace(d, E'\nbegin\n', E'\nbegin\n  perform set_config(''suwati.stock_src'', ''auto'', true);\n');
      execute d;
    end if;
  end loop;
end $$;

-- ပစ္စည်းအဝင် စာရင်းသွင်း
create or replace function stock_receive(p_name text, p_qty int, p_size text default null, p_color text default null,
                                         p_unit_cost numeric default null, p_supplier text default null, p_note text default null)
returns jsonb language plpgsql security definer set search_path = public as $$
declare old_total int; new_total int; mid uuid; oc numeric; em text;
begin
  if not is_admin() then raise exception 'NOT_ADMIN'; end if;
  if not admin_can('edit_stock') then raise exception 'NO_PERMISSION: Stock ပြင်ခွင့် မရှိပါ'; end if;
  if p_qty is null or p_qty <= 0 or p_qty > 100000 then raise exception 'INVALID_QTY'; end if;
  select stock_qty into old_total from products where name = p_name and coalesce(is_gift_card, false) = false;
  if not found then raise exception 'PRODUCT_NOT_FOUND'; end if;
  perform set_config('suwati.stock_src', 'in', true);
  perform _increment_stock_internal(p_name, p_qty, nullif(p_color, ''), nullif(p_size, ''));
  select stock_qty into new_total from products where name = p_name;
  select email into em from auth.users where id = auth.uid();
  insert into stock_movements (product_name, size, color, qty_change, stock_after, kind, supplier, note, created_by_email)
    values (p_name, nullif(p_size, ''), nullif(p_color, ''), p_qty, new_total, 'in', nullif(trim(p_supplier), ''), nullif(trim(p_note), ''), em)
    returning id into mid;
  if coalesce(p_unit_cost, 0) > 0 and is_owner() then
    insert into stock_in_costs (movement_id, unit_cost) values (mid, p_unit_cost);
    -- ဝယ်ဈေး ပျမ်းမျှ (အဟောင်း Stock × ဈေးဟောင်း + အသစ် × ဈေးသစ်)
    select cost_price into oc from product_costs where product_name = p_name;
    insert into product_costs (product_name, cost_price, updated_at)
      values (p_name, case when oc is null or oc <= 0 or greatest(coalesce(old_total, 0), 0) = 0 then p_unit_cost
                      else round((oc * greatest(old_total, 0) + p_unit_cost * p_qty) / (greatest(old_total, 0) + p_qty)) end, now())
      on conflict (product_name) do update set cost_price = excluded.cost_price, updated_at = now();
  end if;
  return jsonb_build_object('ok', true, 'stock', new_total);
end $$;
revoke all on function stock_receive(text,int,text,text,numeric,text,text) from public, anon;
grant execute on function stock_receive(text,int,text,text,numeric,text,text) to authenticated;

-- Admin က Product Form ကနေ Stock ကို လက်နဲ့ ပြင်ရင် မှတ်တမ်း
create or replace function log_manual_stock_change() returns trigger
language plpgsql security definer set search_path = public as $$
declare em text;
begin
  if coalesce(current_setting('suwati.stock_src', true), '') in ('auto', 'in') then return null; end if;
  if coalesce(new.is_gift_card, false) then return null; end if;
  if coalesce(old.stock_qty, 0) = coalesce(new.stock_qty, 0) then return null; end if;
  if auth.uid() is null or not exists (select 1 from admins where user_id = auth.uid()) then return null; end if;
  select email into em from auth.users where id = auth.uid();
  insert into stock_movements (product_name, qty_change, stock_after, kind, note, created_by_email)
    values (new.name, coalesce(new.stock_qty, 0) - coalesce(old.stock_qty, 0), new.stock_qty, 'adjust', 'ပစ္စည်း Form မှ ပြင်', em);
  return null;
end $$;
drop trigger if exists trg_log_manual_stock_change on products;
create trigger trg_log_manual_stock_change after update on products
  for each row execute function log_manual_stock_change();

-- =====================================================================
-- ⑥ 📉 Stock နည်း/ကုန် → Admin ဖုန်းဆီ Notification
-- =====================================================================
create table if not exists admin_alerts (
  id uuid primary key default gen_random_uuid(),
  kind text not null,
  message text not null,
  url text default '/admin',
  created_at timestamptz default now(),
  pushed_at timestamptz
);
alter table admin_alerts enable row level security;
drop policy if exists "Admins read alerts" on admin_alerts;
create policy "Admins read alerts" on admin_alerts for select using (is_admin());

create or replace function alert_low_stock() returns trigger
language plpgsql security definer set search_path = public as $$
declare thr int;
begin
  if coalesce(new.is_gift_card, false) then return null; end if;
  select coalesce(low_stock_threshold, 2) into thr from settings where id = 1;
  thr := coalesce(thr, 2);
  if coalesce(old.stock_qty, 0) > 0 and coalesce(new.stock_qty, 0) <= 0 then
    insert into admin_alerts (kind, message) values ('sold_out', '⚫ "' || new.name || '" ကုန်သွားပါပြီ (Sold Out) — ပစ္စည်း ပြန်ဖြည့်ရန်');
  elsif coalesce(old.stock_qty, 0) > thr and coalesce(new.stock_qty, 0) between 1 and thr then
    insert into admin_alerts (kind, message) values ('low_stock', '📉 "' || new.name || '" — ' || new.stock_qty || ' ခုပဲ ကျန်တော့သည်');
  end if;
  return null;
end $$;
drop trigger if exists trg_alert_low_stock on products;
create trigger trg_alert_low_stock after update on products
  for each row execute function alert_low_stock();

create or replace function push_on_admin_alert() returns trigger
language plpgsql security definer set search_path = public, extensions as $$
declare u text; k text;
begin
  select value into u from public.app_private_config where key = 'project_url';
  select value into k from public.app_private_config where key = 'anon_key';
  if u is null then return null; end if;
  begin
    perform net.http_post(
      url := u || '/functions/v1/send-push',
      headers := jsonb_build_object('Content-Type', 'application/json', 'Authorization', 'Bearer ' || coalesce(k, '')),
      body := '{"source":"admin_alerts"}'::jsonb,
      timeout_milliseconds := 15000);
  exception when others then null;
  end;
  return null;
end $$;
do $$
begin
  if to_regclass('public.app_private_config') is not null then
    execute 'drop trigger if exists trg_push_on_admin_alert on admin_alerts';
    execute 'create trigger trg_push_on_admin_alert after insert on admin_alerts for each statement execute function push_on_admin_alert()';
  else
    raise notice 'app_private_config မရှိသေးပါ — AUTO-BACKUP-PUSH.sql ကို Run ပြီးမှ ဒီဖိုင်ကို ပြန် Run ပါ';
  end if;
end $$;

-- send-push Edge Function က ခေါ်သည် (Service Key ဖြင့်သာ)
create or replace function claim_admin_alerts(p_limit int default 50)
returns setof admin_alerts language sql security definer set search_path = public as $$
  update admin_alerts set pushed_at = now()
  where id in (select id from admin_alerts where pushed_at is null and created_at > now() - interval '1 day'
               order by created_at limit p_limit for update skip locked)
  returning *
$$;
revoke all on function claim_admin_alerts(int) from public, anon, authenticated;
do $$ begin
  if exists (select 1 from pg_roles where rolname = 'service_role') then
    execute 'grant execute on function claim_admin_alerts(int) to service_role';
  end if;
end $$;

-- ✅ စစ်ရန်
select 'product_reviews' as t, count(*) from product_reviews
union all select 'bundle_deals', count(*) from bundle_deals
union all select 'stock_movements', count(*) from stock_movements;
