-- ==========================================================
-- SUWATI MEN FASHION — Database Setup
-- ဒီ SQL ကို Supabase Dashboard > SQL Editor မှာ paste လုပ်ပြီး "Run" နှိပ်ပါ
-- ဒီ file ကို ဘယ်နှစ်ခါ ပြန် Run လုပ်လုပ် error မတက်အောင် ရေးထားပါတယ် (idempotent)
-- ==========================================================

-- ၁) ပစ္စည်း (Products) table
create table if not exists products (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  price numeric not null,
  sizes text,
  colors text,
  category text default 'Top Wear',
  description text,
  images text,                -- ကွန်မာ (,) ခံပြီး ပုံ link များစွာ (ပထမဆုံးတစ်ခုက image_url အဖြစ်လည်း သိမ်းမည်)
  color_stock jsonb default '{}'::jsonb,  -- (Legacy) ဥပမာ {"Black": 5, "White": 2}
  variant_stock jsonb default '{}'::jsonb, -- Size+Color ပေါင်း ဥပမာ {"S": {"Black": 5, "White": 2}, "M": {"Black": 3}}
  stock_qty int default 0,
  status text default 'available',
  image_url text,
  created_at timestamptz default now()
);
alter table products add column if not exists colors text;
alter table products add column if not exists category text default 'Top Wear';
alter table products add column if not exists description text;
alter table products add column if not exists images text;
alter table products add column if not exists color_stock jsonb default '{}'::jsonb;
alter table products add column if not exists variant_stock jsonb default '{}'::jsonb;

-- ၂) Post/Promotion (Posts) table
create table if not exists posts (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  content text,
  image_url text,
  created_at timestamptz default now()
);

-- ၃) Orders table
create table if not exists orders (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete set null,  -- Login ဝင်ထားရင် ချိတ်၊ Guest ဆို NULL
  customer_name text not null,
  phone text not null,
  email text,
  address text not null,
  product_name text not null,
  size text,
  color text,
  quantity int default 1,
  unit_price numeric not null,
  total_amount numeric not null,
  payment_screenshot_url text,
  order_group_id uuid,  -- ပစ္စည်းအမျိုးမျိုး တခါတည်း Order တင်ရင် အားလုံးကို ချိတ်ဆက်ဖို့
  payment_status text default 'pending',
  order_status text default 'pending_verification',
  created_at timestamptz default now()
);
alter table orders add column if not exists user_id uuid references auth.users(id) on delete set null;
alter table orders add column if not exists order_group_id uuid;

-- ၄) Settings table
create table if not exists settings (
  id int primary key default 1,
  kbzpay_qr_url text,
  payment_instructions text default 'KBZPay QR Code ကို Scan လုပ်ပြီး ငွေပေးချေမှု ပြုလုပ်ပါ။ ပြီးရင် အောက်မှာ Payment Screenshot ကို တင်ပေးပါ။',
  admin_email text,
  constraint settings_single_row check (id = 1)
);
insert into settings (id) values (1) on conflict (id) do nothing;
alter table settings add column if not exists admin_email text;

-- ၅) Admins table — ဒီထဲက user_id ပါသူတွေကိုပဲ "Admin" အဖြစ် သတ်မှတ်မယ် (Customer login နဲ့ ခွဲခြားဖို့)
create table if not exists admins (
  user_id uuid primary key references auth.users(id) on delete cascade
);

-- ၅.၅) Categories table — Admin ကိုယ်တိုင် Category အသစ်ထည့်/ပြင်/ဖျက် လို့ရအောင်
create table if not exists categories (
  id uuid primary key default gen_random_uuid(),
  name text unique not null,
  sort_order int default 0,
  created_at timestamptz default now()
);
insert into categories (name, sort_order) values
  ('Top Wear', 1), ('Outer Wear', 2), ('Pants', 3), ('Accessories', 4), ('Underwear', 5)
on conflict (name) do nothing;

-- ၅.၆) Activity Logs table — Admin တစ်ယောက်ချင်းစီရဲ့ လုပ်ဆောင်ချက်များကို မှတ်တမ်းတင်ရန်
create table if not exists activity_logs (
  id uuid primary key default gen_random_uuid(),
  admin_email text,
  action text not null,
  details text,
  created_at timestamptz default now()
);

-- ★★★ အရေးကြီးဆုံးအဆင့် ★★★
-- သင့် Admin App login account ရဲ့ User ID ကို ဒီအောက်မှာ ထည့်ပေးပါ (Authentication > Users ထဲက Copy လုပ်ပါ)
-- insert into admins (user_id) values ('သင့်-admin-user-id-ကို-ဒီနေရာမှာ-ကူးထည့်ပါ') on conflict do nothing;

-- ၆) Row Level Security ဖွင့်ခြင်း
alter table products enable row level security;
alter table posts enable row level security;
alter table orders enable row level security;
alter table settings enable row level security;
alter table admins enable row level security;
alter table categories enable row level security;
alter table activity_logs enable row level security;

-- ၇) Policies (drop-and-recreate — ဘယ်နှစ်ခါ Run လုပ်လုပ် error မတက်ပါ)

drop policy if exists "Anyone can check admin table" on admins;
create policy "Anyone can check admin table" on admins for select using (true);

drop policy if exists "Public can view categories" on categories;
create policy "Public can view categories" on categories for select using (true);

drop policy if exists "Admin can manage categories" on categories;
create policy "Admin can manage categories" on categories for all
  using (exists (select 1 from admins where user_id = auth.uid()))
  with check (exists (select 1 from admins where user_id = auth.uid()));

drop policy if exists "Admin can view activity logs" on activity_logs;
create policy "Admin can view activity logs" on activity_logs for select
  using (exists (select 1 from admins where user_id = auth.uid()));

drop policy if exists "Admin can create activity logs" on activity_logs;
create policy "Admin can create activity logs" on activity_logs for insert
  with check (exists (select 1 from admins where user_id = auth.uid()));

drop policy if exists "Public can view products" on products;
create policy "Public can view products" on products for select using (true);

drop policy if exists "Admin can manage products" on products;
create policy "Admin can manage products" on products for all
  using (exists (select 1 from admins where user_id = auth.uid()))
  with check (exists (select 1 from admins where user_id = auth.uid()));

drop policy if exists "Public can view posts" on posts;
create policy "Public can view posts" on posts for select using (true);

drop policy if exists "Admin can manage posts" on posts;
create policy "Admin can manage posts" on posts for all
  using (exists (select 1 from admins where user_id = auth.uid()))
  with check (exists (select 1 from admins where user_id = auth.uid()));

drop policy if exists "Public can create orders" on orders;
create policy "Public can create orders" on orders for insert with check (true);

drop policy if exists "Admin can view orders" on orders;
create policy "Admin can view orders" on orders for select
  using (exists (select 1 from admins where user_id = auth.uid()));

drop policy if exists "Customers can view own orders" on orders;
create policy "Customers can view own orders" on orders for select
  using (auth.uid() = user_id);

drop policy if exists "Admin can update orders" on orders;
create policy "Admin can update orders" on orders for update
  using (exists (select 1 from admins where user_id = auth.uid()));

drop policy if exists "Admin can delete orders" on orders;
create policy "Admin can delete orders" on orders for delete
  using (exists (select 1 from admins where user_id = auth.uid()));

drop policy if exists "Public can view settings" on settings;
create policy "Public can view settings" on settings for select using (true);

drop policy if exists "Admin can update settings" on settings;
create policy "Admin can update settings" on settings for update
  using (exists (select 1 from admins where user_id = auth.uid()));

-- ၈) Payment Screenshot Storage Policy
drop policy if exists "Public can upload payment screenshots" on storage.objects;
create policy "Public can upload payment screenshots" on storage.objects for insert
  with check (bucket_id = 'payment-screenshots');

drop policy if exists "Public can view payment screenshots" on storage.objects;
create policy "Public can view payment screenshots" on storage.objects for select
  using (bucket_id = 'payment-screenshots');

-- ၉) "images" Bucket Storage Policy
drop policy if exists "Admin can upload images" on storage.objects;
create policy "Admin can upload images" on storage.objects for insert
  with check (bucket_id = 'images' and exists (select 1 from admins where user_id = auth.uid()));

drop policy if exists "Admin can update images" on storage.objects;
create policy "Admin can update images" on storage.objects for update
  using (bucket_id = 'images' and exists (select 1 from admins where user_id = auth.uid()));

drop policy if exists "Public can view images" on storage.objects;
create policy "Public can view images" on storage.objects for select
  using (bucket_id = 'images');

-- ၁၀) Stock Auto-decrement Function (Size + Color ပေါင်း variant အလိုက်လျှော့ချ)
drop function if exists decrement_stock(text, int);
drop function if exists decrement_stock(text, int, text);
drop function if exists decrement_stock(text, int, text, text);

drop function if exists decrement_stock(text, int, text, text);

create or replace function decrement_stock(p_name text, p_qty int, p_color text default null, p_size text default null)
returns boolean as $$
declare
  cur_variant jsonb;
  cur_color_stock jsonb;
  cur_qty int;
  new_qty int;
  v_size text;
  v_color text;
  base_stock int;
begin
  -- "for update" ဖြင့် Row ကို Lock ချထားလို့ တခြား Order တွေနဲ့ တပြိုင်နက် ဝင်လာရင်တောင် Race Condition မဖြစ်ပါ
  select variant_stock, color_stock, stock_qty into cur_variant, cur_color_stock, base_stock
  from products where name = p_name for update;

  v_size := coalesce(p_size, '_');
  v_color := coalesce(p_color, '_');

  if cur_variant is not null and cur_variant ? v_size and (cur_variant -> v_size) ? v_color then
    cur_qty := ((cur_variant -> v_size) ->> v_color)::int;
    if cur_qty < p_qty then
      return false; -- ★ Stock မလုံလောက်ပါ — Order ကို ငြင်းပယ်ရမည်
    end if;
    new_qty := cur_qty - p_qty;
    update products
    set variant_stock = jsonb_set(variant_stock, array[v_size, v_color], to_jsonb(new_qty)),
        stock_qty = greatest(stock_qty - p_qty, 0),
        status = case when greatest(stock_qty - p_qty, 0) <= 0 then 'sold_out' else status end
    where name = p_name;
    return true;
  elsif p_color is not null and cur_color_stock is not null and cur_color_stock ? p_color then
    cur_qty := (cur_color_stock ->> p_color)::int;
    if cur_qty < p_qty then
      return false;
    end if;
    new_qty := cur_qty - p_qty;
    update products
    set color_stock = jsonb_set(color_stock, array[p_color], to_jsonb(new_qty)),
        stock_qty = greatest(stock_qty - p_qty, 0),
        status = case when greatest(stock_qty - p_qty, 0) <= 0 then 'sold_out' else status end
    where name = p_name;
    return true;
  else
    if base_stock is null or base_stock < p_qty then
      return false;
    end if;
    update products
    set stock_qty = greatest(stock_qty - p_qty, 0),
        status = case when greatest(stock_qty - p_qty, 0) <= 0 then 'sold_out' else status end
    where name = p_name;
    return true;
  end if;
end;
$$ language plpgsql security definer;

grant execute on function decrement_stock(text, int, text, text) to anon, authenticated;

-- ၁၅) Stock Restore Function (Refund/Void ဖြစ်တဲ့အခါ Stock ပြန်တိုးရန်)
drop function if exists increment_stock(text, int, text, text);

create or replace function increment_stock(p_name text, p_qty int, p_color text default null, p_size text default null)
returns void as $$
declare
  cur_variant jsonb;
  cur_color_stock jsonb;
  cur_qty int;
  new_qty int;
  v_size text;
  v_color text;
begin
  select variant_stock, color_stock into cur_variant, cur_color_stock from products where name = p_name;
  v_size := coalesce(p_size, '_');
  v_color := coalesce(p_color, '_');

  if cur_variant is not null and cur_variant ? v_size and (cur_variant -> v_size) ? v_color then
    cur_qty := ((cur_variant -> v_size) ->> v_color)::int;
    new_qty := cur_qty + p_qty;
    update products
    set variant_stock = jsonb_set(variant_stock, array[v_size, v_color], to_jsonb(new_qty)),
        stock_qty = stock_qty + p_qty,
        status = 'available'
    where name = p_name;
  elsif p_color is not null and cur_color_stock is not null and cur_color_stock ? p_color then
    cur_qty := (cur_color_stock ->> p_color)::int;
    new_qty := cur_qty + p_qty;
    update products
    set color_stock = jsonb_set(color_stock, array[p_color], to_jsonb(new_qty)),
        stock_qty = stock_qty + p_qty,
        status = 'available'
    where name = p_name;
  else
    update products
    set stock_qty = stock_qty + p_qty,
        status = 'available'
    where name = p_name;
  end if;
end;
$$ language plpgsql security definer;

grant execute on function increment_stock(text, int, text, text) to anon, authenticated;

-- ၁၁) Realtime ဖွင့်ခြင်း — Order အသစ်ဝင်တိုင်း Admin App ကို live အသိပေးဖို့
do $$
begin
  alter publication supabase_realtime add table orders;
exception when duplicate_object then
  null;
end $$;

-- ၁၂) Featured Product Tags (New Arrival / Best Seller / Featured / Sale)
alter table products add column if not exists tags text; -- ကွန်မာ ခံပြီး ဥပမာ "New Arrival, Sale"

-- ၁၃) Banners table — Home page က NEW ARRIVAL / SUMMER SALE / 20% OFF စတဲ့ Banner များ
create table if not exists banners (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  subtitle text,
  image_url text,
  link_url text,
  sort_order int default 0,
  active boolean default true,
  created_at timestamptz default now()
);

alter table banners enable row level security;

drop policy if exists "Public can view active banners" on banners;
create policy "Public can view active banners" on banners for select using (true);

drop policy if exists "Admin can manage banners" on banners;
create policy "Admin can manage banners" on banners for all
  using (exists (select 1 from admins where user_id = auth.uid()))
  with check (exists (select 1 from admins where user_id = auth.uid()));

-- ၁၄) POS (In-Store Sale) — Website Order နဲ့ ခွဲခြားသိရန်
alter table orders add column if not exists sale_channel text default 'online'; -- 'online' or 'in_store'
alter table orders add column if not exists payment_method text; -- 'Cash' / 'KBZPay' / 'Other' (POS Sale အတွက်)
alter table orders add column if not exists discount_amount numeric default 0; -- POS Sale မှာ လျှော့ပေးထားသော ပမာဏ (item အလိုက် ခွဲသိမ်း)

-- ၁၆) Staff / Multiple Admin Roles
alter table admins add column if not exists role text default 'owner';
alter table admins add column if not exists email text;
alter table admins add column if not exists added_at timestamptz default now();
-- role: 'owner' (အပြည့်အစုံ) or 'staff' (POS/Order/Inventory ကိုပဲ ခွင့်ပြု)

create or replace function is_admin() returns boolean as $$
  select exists (select 1 from admins where user_id = auth.uid());
$$ language sql security definer stable;

create or replace function is_owner() returns boolean as $$
  select exists (select 1 from admins where user_id = auth.uid() and role = 'owner');
$$ language sql security definer stable;

-- Products/Categories/Posts/Settings/Banners — Owner ချည်းသာ စီမံခွင့်
drop policy if exists "Admin can manage products" on products;
drop policy if exists "Owner can manage products" on products;
create policy "Owner can manage products" on products for all
  using (is_owner()) with check (is_owner());

drop policy if exists "Admin can manage categories" on categories;
drop policy if exists "Owner can manage categories" on categories;
create policy "Owner can manage categories" on categories for all
  using (is_owner()) with check (is_owner());

drop policy if exists "Admin can manage posts" on posts;
drop policy if exists "Owner can manage posts" on posts;
create policy "Owner can manage posts" on posts for all
  using (is_owner()) with check (is_owner());

drop policy if exists "Admin can update settings" on settings;
drop policy if exists "Owner can update settings" on settings;
create policy "Owner can update settings" on settings for update
  using (is_owner());

drop policy if exists "Admin can manage banners" on banners;
drop policy if exists "Owner can manage banners" on banners;
create policy "Owner can manage banners" on banners for all
  using (is_owner()) with check (is_owner());

-- Orders — Owner + Staff နှစ်ခုစလုံး ကြည့်/Status ပြင်နိုင်၊ ဖျက်ခြင်းကတော့ Owner ချည်း
drop policy if exists "Admin can view orders" on orders;
create policy "Admin can view orders" on orders for select using (is_admin());

drop policy if exists "Admin can update orders" on orders;
create policy "Admin can update orders" on orders for update using (is_admin());

drop policy if exists "Admin can delete orders" on orders;
drop policy if exists "Owner can delete orders" on orders;
create policy "Owner can delete orders" on orders for delete using (is_owner());

drop policy if exists "Customer can delete own orders" on orders;
create policy "Customer can delete own orders" on orders for delete
  using (auth.uid() = user_id);

-- "images" bucket — Owner ချည်းသာ ပုံတင်ခွင့်
drop policy if exists "Admin can upload images" on storage.objects;
drop policy if exists "Owner can upload images" on storage.objects;
create policy "Owner can upload images" on storage.objects for insert
  with check (bucket_id = 'images' and is_owner());

drop policy if exists "Admin can update images" on storage.objects;
drop policy if exists "Owner can update images" on storage.objects;
create policy "Owner can update images" on storage.objects for update
  using (bucket_id = 'images' and is_owner());

-- Admins table — Owner ချည်းသာ Staff ထည့်/ဖျက်နိုင်
drop policy if exists "Admin can manage categories" on categories;
drop policy if exists "Owner can manage admins" on admins;
create policy "Owner can manage admins" on admins for all
  using (is_owner()) with check (is_owner());

-- ၁၇) Customer ↔ Admin Messaging (Login ဝင်ထားသူများသာ — Guest က Messenger/Viber သုံးရန်)
create table if not exists chat_messages (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  customer_name text,
  sender text not null check (sender in ('customer','admin')),
  message text not null,
  created_at timestamptz default now()
);

-- Unread Message Indicator (Admin ဘက်/Customer ဘက် နှစ်ဖက်စလုံး) အတွက်
alter table chat_messages add column if not exists read_by_admin boolean default false;
alter table chat_messages add column if not exists read_by_customer boolean default false;

alter table chat_messages enable row level security;

drop policy if exists "Customer can view own messages" on chat_messages;
create policy "Customer can view own messages" on chat_messages for select
  using (auth.uid() = user_id);

drop policy if exists "Customer can send own messages" on chat_messages;
create policy "Customer can send own messages" on chat_messages for insert
  with check (auth.uid() = user_id and sender = 'customer');

drop policy if exists "Admin can view all messages" on chat_messages;
create policy "Admin can view all messages" on chat_messages for select
  using (is_admin());

drop policy if exists "Admin can send messages" on chat_messages;
create policy "Admin can send messages" on chat_messages for insert
  with check (is_admin() and sender = 'admin');

drop policy if exists "Customer can mark messages read" on chat_messages;
create policy "Customer can mark messages read" on chat_messages for update
  using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "Admin can mark messages read" on chat_messages;
create policy "Admin can mark messages read" on chat_messages for update
  using (is_admin()) with check (is_admin());

do $$
begin
  alter publication supabase_realtime add table chat_messages;
exception when duplicate_object then
  null;
end $$;

-- ၁၈) Guest Order Tracking — Login မလိုပဲ Order ID + ဖုန်းနံပါတ်ဖြင့် Status ကြည့်နိုင်ရန်
drop function if exists track_order(text, text);

create or replace function track_order(p_order_code text, p_phone text)
returns setof orders as $$
  select * from orders
  where phone = p_phone
    and (
      upper(left(coalesce(order_group_id::text, id::text), 8)) = upper(p_order_code)
      or upper(left(id::text, 8)) = upper(p_order_code)
    );
$$ language sql security definer stable;

grant execute on function track_order(text, text) to anon, authenticated;

-- ၁၉) Delivery Role — Order ပို့ပြီးကြောင်း ပုံတင်ပြီး မှတ်တမ်းတင်ရန်
alter table orders add column if not exists delivery_photo_url text;
alter table orders add column if not exists delivered_by uuid references auth.users(id) on delete set null;
alter table orders add column if not exists delivered_at timestamptz;

-- "delivery-photos" Bucket Policy
-- (Storage > New bucket > name: delivery-photos > Public bucket: ON ဖန်တီးပြီးမှ ဒီအောက်ပိုင်းကို Run ပါ)
drop policy if exists "Admin can upload delivery photos" on storage.objects;
create policy "Admin can upload delivery photos" on storage.objects for insert
  with check (bucket_id = 'delivery-photos' and is_admin());

drop policy if exists "Public can view delivery photos" on storage.objects;
create policy "Public can view delivery photos" on storage.objects for select
  using (bucket_id = 'delivery-photos');

-- ၂၀) Wishlist Account Sync — Login ဝင်ထားသူများအတွက် Device မရွေး Sync ဖြစ်ရန်
create table if not exists wishlists (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  product_name text not null,
  price numeric,
  image_url text,
  created_at timestamptz default now(),
  unique(user_id, product_name)
);

alter table wishlists enable row level security;

drop policy if exists "Customer can view own wishlist" on wishlists;
create policy "Customer can view own wishlist" on wishlists for select
  using (auth.uid() = user_id);

drop policy if exists "Customer can add to own wishlist" on wishlists;
create policy "Customer can add to own wishlist" on wishlists for insert
  with check (auth.uid() = user_id);

drop policy if exists "Customer can remove from own wishlist" on wishlists;
create policy "Customer can remove from own wishlist" on wishlists for delete
  using (auth.uid() = user_id);

-- ၂၁) Sub-Category — Category တစ်ခုအောက်မှာ ထပ်ခွဲရန် (ဥပမာ Top Wear > Shirt, Polo Shirt, Tee)
alter table products add column if not exists subcategory text;
alter table products add column if not exists visible boolean default true;
alter table products add column if not exists is_gift_card boolean default false;

create table if not exists subcategories (
  id uuid primary key default gen_random_uuid(),
  category_name text not null references categories(name) on delete cascade,
  name text not null,
  sort_order int default 0,
  created_at timestamptz default now(),
  unique(category_name, name)
);

alter table subcategories enable row level security;

drop policy if exists "Public can view subcategories" on subcategories;
create policy "Public can view subcategories" on subcategories for select using (true);

drop policy if exists "Owner can manage subcategories" on subcategories;
create policy "Owner can manage subcategories" on subcategories for all
  using (is_owner()) with check (is_owner());

-- ၂၂) Fix — Guest (Login မလုပ်ရသေးသူ) Order တင်နိုင်ရန် (RLS Policy ပြန်သေချာစေရန်)
drop policy if exists "Public can create orders" on orders;
create policy "Public can create orders" on orders for insert
  with check (true);

-- ၂၃) Delivery Note — Delivery Person စာသား ရေးနိုင်ရန်
alter table orders add column if not exists delivery_note text;
alter table orders add column if not exists cancellation_reason text;

-- ၂၄) Staff Profile — Admin App ထဲမှာ Staff/Delivery အချက်အလက် ထည့်နိုင်ရန်
alter table admins add column if not exists age int;
alter table admins add column if not exists dob date;
alter table admins add column if not exists phone text;
alter table admins add column if not exists address text;
alter table admins add column if not exists job_position text;
alter table admins add column if not exists name text;
alter table admins add column if not exists allowed_tabs text[];

-- ၂၅) Chat Image Attachment — Customer က Return/Refund Proof ပုံပို့နိုင်ရန်
alter table chat_messages add column if not exists image_url text;

-- "chat-images" Bucket Policy
-- (Storage > New bucket > name: chat-images > Public bucket: ON ဖန်တီးပြီးမှ ဒီအောက်ပိုင်းကို Run ပါ)
drop policy if exists "Users can upload chat images" on storage.objects;
create policy "Users can upload chat images" on storage.objects for insert
  with check (bucket_id = 'chat-images' and auth.uid() is not null);

drop policy if exists "Public can view chat images" on storage.objects;
create policy "Public can view chat images" on storage.objects for select
  using (bucket_id = 'chat-images');

-- ၂၆) Owner ရဲ့ Email ကို admins table ထဲ Update ထည့်ရန် (Staff tab ထဲ ပေါ်ဖို့)
-- user_id ကို Supabase Auth > Users ထဲက Owner Account ရဲ့ UID အတိအကျ ထည့်ပါ
update admins set role = 'owner' where email = 'nyanlinsat2018@gmail.com';

-- ၂၇) Owner Account ကို ဘယ်သူမှ (Owner ကိုယ်တိုင်ပါ) ဖျက်လို့ မရအောင် ကာကွယ်ခြင်း
create or replace function prevent_owner_delete() returns trigger as $$
begin
  if old.role = 'owner' then
    raise exception 'Owner Account ကို ဖျက်လို့ မရပါ — Database level မှာ ကာကွယ်ထားပါသည်';
  end if;
  return old;
end;
$$ language plpgsql security definer;

drop trigger if exists trg_prevent_owner_delete on admins;
create trigger trg_prevent_owner_delete
  before delete on admins
  for each row execute function prevent_owner_delete();

-- ၂၈) Wallet (Prepaid Balance) System
create table if not exists wallets (
  user_id uuid primary key references auth.users(id) on delete cascade,
  balance numeric default 0,
  updated_at timestamptz default now()
);

alter table wallets enable row level security;

drop policy if exists "Customer can view own wallet" on wallets;
create policy "Customer can view own wallet" on wallets for select
  using (auth.uid() = user_id);

drop policy if exists "Admin can view all wallets" on wallets;
create policy "Admin can view all wallets" on wallets for select
  using (is_admin());

drop policy if exists "Admin can manage wallets" on wallets;
create policy "Admin can manage wallets" on wallets for all
  using (is_owner()) with check (is_owner());

-- Wallet ထဲ ငွေ ဖြည့်ရန် Request (KBZPay Screenshot တင်ပြီး Admin အတည်ပြုစေရန်)
create table if not exists wallet_topups (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  customer_name text,
  phone text,
  amount numeric not null,
  payment_screenshot_url text,
  status text default 'pending', -- pending / approved / rejected
  rejection_reason text,
  created_at timestamptz default now(),
  reviewed_at timestamptz,
  reviewed_by uuid references auth.users(id) on delete set null,
  reviewed_by_email text
);

-- ★ Table က ရှိပြီးသားဖြစ်နေရင် "create table if not exists" က Column အသစ်ကို ထည့်မပေးနိုင်ပါ — ဒါကြောင့် ဒီနေရာမှာ တိုက်ရိုက် ထပ်ထည့်ပေးပါသည်
alter table wallet_topups add column if not exists reviewed_at timestamptz;
alter table wallet_topups add column if not exists reviewed_by uuid references auth.users(id) on delete set null;
alter table wallet_topups add column if not exists reviewed_by_email text;

alter table wallet_topups enable row level security;

drop policy if exists "Customer can create own topup" on wallet_topups;
create policy "Customer can create own topup" on wallet_topups for insert
  with check (auth.uid() = user_id);

drop policy if exists "Customer can view own topup" on wallet_topups;
create policy "Customer can view own topup" on wallet_topups for select
  using (auth.uid() = user_id);

drop policy if exists "Admin can view all topups" on wallet_topups;
create policy "Admin can view all topups" on wallet_topups for select
  using (is_admin());

drop policy if exists "Admin can update topups" on wallet_topups;
create policy "Admin can update topups" on wallet_topups for update
  using (is_admin());

-- Wallet Transaction Ledger — Prepaid Card Usage History အတွက် (Top-up/Redeem/Refund/Purchase အားလုံး မှတ်တမ်းတင်ရန်)
create table if not exists wallet_transactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  type text not null, -- topup / gift_card_redeem / refund / purchase / pos_purchase
  amount numeric not null, -- Credit ဆို +, Debit ဆို -
  description text,
  reference_id text,
  created_at timestamptz default now()
);

alter table wallet_transactions enable row level security;

drop policy if exists "Customer can view own transactions" on wallet_transactions;
create policy "Customer can view own transactions" on wallet_transactions for select
  using (auth.uid() = user_id);

drop policy if exists "Admin can view all transactions" on wallet_transactions;
create policy "Admin can view all transactions" on wallet_transactions for select
  using (is_admin());

-- Wallet ကို ငွေ ဖြည့်ခြင်း/နုတ်ခြင်း (Race Condition မဖြစ်စေရန် Atomic Function များ) — Transaction Log ပါ အလိုအလျောက် တင်ပေးမည်
create or replace function credit_wallet(p_user_id uuid, p_amount numeric, p_type text default 'credit', p_description text default null, p_reference text default null)
returns void as $$
begin
  insert into wallets (user_id, balance) values (p_user_id, p_amount)
  on conflict (user_id) do update set balance = wallets.balance + p_amount, updated_at = now();

  insert into wallet_transactions (user_id, type, amount, description, reference_id)
  values (p_user_id, p_type, p_amount, p_description, p_reference);
end;
$$ language plpgsql security definer;

grant execute on function credit_wallet(uuid, numeric, text, text, text) to authenticated;

create or replace function debit_wallet(p_amount numeric, p_type text default 'debit', p_description text default null, p_reference text default null)
returns boolean as $$
declare
  cur numeric;
begin
  select balance into cur from wallets where user_id = auth.uid() for update;
  if cur is null or cur < p_amount then
    return false;
  end if;
  update wallets set balance = balance - p_amount, updated_at = now() where user_id = auth.uid();

  insert into wallet_transactions (user_id, type, amount, description, reference_id)
  values (auth.uid(), p_type, -p_amount, p_description, p_reference);

  return true;
end;
$$ language plpgsql security definer;

grant execute on function debit_wallet(numeric, text, text, text) to authenticated;

-- ၂၉) Gift Card System (၁၀,၀၀၀ ကျပ် — ၅၀၀,၀၀၀ ကျပ်)
create table if not exists gift_cards (
  id uuid primary key default gen_random_uuid(),
  code text unique not null,
  amount numeric not null,
  purchased_by uuid references auth.users(id) on delete set null,
  purchaser_name text,
  phone text,
  payment_screenshot_url text,
  status text default 'pending', -- pending / active / redeemed / rejected
  rejection_reason text,
  redeemed_by uuid references auth.users(id) on delete set null,
  redeemed_at timestamptz,
  reviewed_by uuid references auth.users(id) on delete set null,
  reviewed_by_email text,
  reviewed_at timestamptz,
  created_at timestamptz default now()
);

-- ★ Table က ရှိပြီးသားဖြစ်နေရင် "create table if not exists" က Column အသစ်ကို ထည့်မပေးနိုင်ပါ — ဒီနေရာမှာ တိုက်ရိုက် ထပ်ထည့်ပေးပါသည်
alter table gift_cards add column if not exists redeemed_by uuid references auth.users(id) on delete set null;
alter table gift_cards add column if not exists redeemed_at timestamptz;
alter table gift_cards add column if not exists reviewed_by uuid references auth.users(id) on delete set null;
alter table gift_cards add column if not exists reviewed_by_email text;
alter table gift_cards add column if not exists reviewed_at timestamptz;
alter table gift_cards add column if not exists rejection_reason text;

alter table gift_cards enable row level security;

drop policy if exists "Customer can purchase gift card" on gift_cards;
create policy "Customer can purchase gift card" on gift_cards for insert
  with check (auth.uid() = purchased_by);

drop policy if exists "Admin can issue gift card" on gift_cards;
create policy "Admin can issue gift card" on gift_cards for insert
  with check (is_admin());

drop policy if exists "Customer can view own gift cards" on gift_cards;
create policy "Customer can view own gift cards" on gift_cards for select
  using (auth.uid() = purchased_by or auth.uid() = redeemed_by);

drop policy if exists "Admin can view all gift cards" on gift_cards;
create policy "Admin can view all gift cards" on gift_cards for select
  using (is_admin());

drop policy if exists "Admin can update gift cards" on gift_cards;
create policy "Admin can update gift cards" on gift_cards for update
  using (is_admin());

-- Gift Card Redeem — Code သုံးသူဆီ Wallet ထဲ ငွေ ထည့်ပေးရန် (Security Definer — RLS ကို Bypass လုပ်ပြီး လုံခြုံစွာ လုပ်ဆောင်ပေးသည်)
create or replace function redeem_gift_card(p_code text)
returns jsonb as $$
declare
  gc record;
begin
  if auth.uid() is null then
    return jsonb_build_object('success', false, 'message', 'Login ဝင်ရန် လိုအပ်ပါသည်');
  end if;

  select * into gc from gift_cards where upper(code) = upper(p_code) for update;

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
  perform credit_wallet(auth.uid(), gc.amount, 'gift_card_redeem', 'Gift Card သုံးစွဲမှု — '||gc.code, gc.code);

  return jsonb_build_object('success', true, 'amount', gc.amount);
end;
$$ language plpgsql security definer;

grant execute on function redeem_gift_card(text) to authenticated;

-- ၃၀) Virtual Prepaid Card — Card Number + PIN + Barcode (In-Store POS မှာ သုံးရန်)
alter table wallets add column if not exists card_number text unique;
alter table wallets add column if not exists card_pin text;

-- Customer ရဲ့ Prepaid Card ကို ရယူရန် (မရှိသေးရင် တစ်ခါတည်း Auto ဖန်တီးပေးမည်)
create or replace function get_or_create_card()
returns wallets as $$
declare
  w wallets;
begin
  if auth.uid() is null then
    raise exception 'Login ဝင်ရန် လိုအပ်ပါသည်';
  end if;

  select * into w from wallets where user_id = auth.uid();

  if w.user_id is null then
    insert into wallets (user_id, balance, card_number, card_pin)
    values (
      auth.uid(), 0,
      lpad((random()*9999)::int::text,4,'0')||' '||lpad((random()*9999)::int::text,4,'0')||' '||lpad((random()*9999)::int::text,4,'0')||' '||lpad((random()*9999)::int::text,4,'0'),
      lpad((random()*9999)::int::text,4,'0')
    )
    returning * into w;
  elsif w.card_number is null then
    update wallets set
      card_number = lpad((random()*9999)::int::text,4,'0')||' '||lpad((random()*9999)::int::text,4,'0')||' '||lpad((random()*9999)::int::text,4,'0')||' '||lpad((random()*9999)::int::text,4,'0'),
      card_pin = lpad((random()*9999)::int::text,4,'0')
    where user_id = auth.uid()
    returning * into w;
  end if;

  return w;
end;
$$ language plpgsql security definer;

grant execute on function get_or_create_card() to authenticated;

-- POS (အပြင်ဆိုင်) မှာ Card Number + PIN ဖြင့် Wallet ကို ငွေရှင်းရန် (Admin/Staff အသုံးပြုမည်)
create or replace function pos_debit_by_card(p_card_number text, p_pin text, p_amount numeric)
returns jsonb as $$
declare
  w record;
begin
  if not is_admin() then
    return jsonb_build_object('success', false, 'message', 'ခွင့်ပြုချက် မရှိပါ');
  end if;

  select * into w from wallets where replace(card_number,' ','') = replace(p_card_number,' ','') for update;

  if w.user_id is null then
    return jsonb_build_object('success', false, 'message', 'Card Number မှားနေပါသည်');
  end if;
  if w.card_pin != p_pin then
    return jsonb_build_object('success', false, 'message', 'PIN မှားနေပါသည်');
  end if;
  if w.balance < p_amount then
    return jsonb_build_object('success', false, 'message', 'Balance မလုံလောက်ပါ — လက်ကျန်: '||w.balance||' ကျပ်');
  end if;

  update wallets set balance = balance - p_amount, updated_at = now() where user_id = w.user_id;

  insert into wallet_transactions (user_id, type, amount, description, reference_id)
  values (w.user_id, 'pos_purchase', -p_amount, 'ဆိုင်တွင် Prepaid Card ဖြင့် ဝယ်ယူမှု', p_card_number);
  return jsonb_build_object('success', true, 'user_id', w.user_id, 'remaining_balance', w.balance - p_amount);
end;
$$ language plpgsql security definer;

grant execute on function pos_debit_by_card(text, text, numeric) to authenticated;

-- ၃၁) Customer Management List ကနေ Customer Entry တစ်ခုကို ဖျောက်ရန် (Order Data ကို ဖျက်တာမဟုတ်ပါ — List ထဲက ချန်ထားရုံသာ)
create table if not exists hidden_customers (
  id uuid primary key default gen_random_uuid(),
  customer_key text unique not null,
  hidden_by uuid references auth.users(id) on delete set null,
  created_at timestamptz default now()
);

alter table hidden_customers enable row level security;

drop policy if exists "Admin can view hidden customers" on hidden_customers;
create policy "Admin can view hidden customers" on hidden_customers for select
  using (is_admin());

drop policy if exists "Owner can manage hidden customers" on hidden_customers;
create policy "Owner can manage hidden customers" on hidden_customers for all
  using (is_owner()) with check (is_owner());

-- ★ Wallet/Gift Card Table အသစ်တွေအတွက် Realtime Notification (Tab ခုန်ခြင်း) အလုပ်လုပ်ဖို့ Supabase Realtime ကို ဖွင့်ပေးရန်
-- (Table အသစ် ဖန်တီးတိုင်း Supabase က Realtime ကို Default အနေနဲ့ ဖွင့်မပေးထားပါ — ဒီနေရာမှာ တိုက်ရိုက် ဖွင့်ပေးရပါမည်)
do $$
begin
  if not exists (
    select 1 from pg_publication_tables where pubname = 'supabase_realtime' and tablename = 'wallet_topups'
  ) then
    alter publication supabase_realtime add table wallet_topups;
  end if;
  if not exists (
    select 1 from pg_publication_tables where pubname = 'supabase_realtime' and tablename = 'gift_cards'
  ) then
    alter publication supabase_realtime add table gift_cards;
  end if;
end $$;

-- ★ Website Auto-Refresh System — Product/Banner/Post/Category ပြောင်းလဲမှုများကို Customer ဘက်က ချက်ချင်း မြင်ရအောင် Realtime ဖွင့်ပေးရန်
do $$
begin
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and tablename = 'products') then
    alter publication supabase_realtime add table products;
  end if;
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and tablename = 'banners') then
    alter publication supabase_realtime add table banners;
  end if;
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and tablename = 'posts') then
    alter publication supabase_realtime add table posts;
  end if;
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and tablename = 'categories') then
    alter publication supabase_realtime add table categories;
  end if;
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and tablename = 'subcategories') then
    alter publication supabase_realtime add table subcategories;
  end if;
end $$;

-- ★ Online Orders Notification Bug Fix — Prepaid Card ဖြင့် ဝယ်ယူတဲ့ Order များက "confirmed" status ချက်ချင်း ရောက်သွားလို့
-- (KBZPay လို "pending_verification" မှာ မရပ်နေတော့လို့) Admin ဘက်က Notification လွတ်နိုင်ခဲ့ပါတယ်
-- viewed_by_admin ဆိုတဲ့ Column အသစ်ဖြင့် Payment Method မရွေး Admin တကယ်ကြည့်ပြီးမှသာ Notification ရပ်စေရန်
alter table orders add column if not exists viewed_by_admin boolean default true;
update orders set viewed_by_admin = true where viewed_by_admin is null;
alter table orders alter column viewed_by_admin set default false;

-- ★ Delivery Tab အတွက်လည်း သီးခြား Tracking — "confirmed" ဖြစ်လာတဲ့ Order အသစ်များကို Delivery Staff မမြင်ရသေးမချင်း ခုန်နေစေရန်
alter table orders add column if not exists viewed_by_delivery boolean default true;
update orders set viewed_by_delivery = true where viewed_by_delivery is null;
alter table orders alter column viewed_by_delivery set default false;
