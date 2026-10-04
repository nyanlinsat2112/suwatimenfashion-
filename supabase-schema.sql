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
alter table settings add column if not exists ticker_text text default 'ORDER NOW, DELIVERY AVAILABLE, STREET WEAR, POLO, ORIGINAL MENSWEAR, JEANS, SUWATI MEN FASHION, GRAB YOURS!!';

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
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and tablename = 'settings') then
    alter publication supabase_realtime add table settings;
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


-- ★ Product Pin (Website ရဲ့ အပေါ်ဆုံးမှာ ပြရန်)
alter table products add column if not exists pinned boolean default false;

-- ★ Gift ထုပ်ပိုး ဝန်ဆောင်မှု (Add-on) — ဈေးနှုန်းကို Admin Settings မှာ ပြောင်းလို့ရ၊ Customer ရေးပေးတဲ့ ကတ်စာ
alter table settings add column if not exists gift_wrap_price numeric default 4500;
update settings set gift_wrap_price = 4500 where id = 1 and gift_wrap_price is null;
alter table orders add column if not exists gift_message text;

-- ★ Delivery ခ (Zone အလိုက်) — ပစ္စည်းရောက်မှ Delivery သမား ကောက်ယူ (ဆိုင်ရောင်းရငွေ မဟုတ်)
alter table settings add column if not exists delivery_zones jsonb default '[{"name":"နေပြည်တော်အတွင်း","min":3000,"max":5000},{"name":"အခြားမြို့များ (နေပြည်တော်ပြင်ပ)","min":4500,"max":6000}]'::jsonb;
alter table settings add column if not exists delivery_note text default 'Royal Express Delivery Service မှ နှုန်းထားများအတိုင်း ကျသင့်ပါမည်';
update settings set
  delivery_zones = coalesce(delivery_zones, '[{"name":"နေပြည်တော်အတွင်း","min":3000,"max":5000},{"name":"အခြားမြို့များ (နေပြည်တော်ပြင်ပ)","min":4500,"max":6000}]'::jsonb),
  delivery_note = coalesce(delivery_note, 'Royal Express Delivery Service မှ နှုန်းထားများအတိုင်း ကျသင့်ပါမည်')
where id = 1;
alter table orders add column if not exists delivery_zone text;
alter table orders add column if not exists delivery_fee_range text;


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

-- =====================================================================
-- 🔐 SECURITY HARDENING — PART 2 (Stock + Prepaid Card PIN)
-- =====================================================================

-- ---------- [MEDIUM] Stock — တမင် Stock လျှော့/တိုး မလုပ်နိုင်အောင် ----------
-- Customer (Admin မဟုတ်သူ) က decrement_stock ကို ခေါ်ရင် "Stock လုံလောက်လား" စစ်ရုံသာ (မလျှော့)၊ increment_stock က ဘာမှ မလုပ်
-- တကယ့် Stock လျှော့ခြင်းကို Order / Gift Card ဝင်တဲ့အချိန် Database Trigger က အလိုအလျောက် လုပ်ပေးသည် (Order နဲ့ တစ်ပြိုင်နက် — Atomic)
create or replace function _decrement_stock_internal(p_name text, p_qty int, p_color text default null, p_size text default null)
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
$$ language plpgsql security definer set search_path = public;
revoke all on function _decrement_stock_internal(text, int, text, text) from public, anon, authenticated;

create or replace function _increment_stock_internal(p_name text, p_qty int, p_color text default null, p_size text default null)
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
$$ language plpgsql security definer set search_path = public;
revoke all on function _increment_stock_internal(text, int, text, text) from public, anon, authenticated;

create or replace function decrement_stock(p_name text, p_qty int, p_color text default null, p_size text default null)
returns boolean as $$
declare
  ok boolean := false;
begin
  if is_admin() then
    return _decrement_stock_internal(p_name, p_qty, p_color, p_size);
  end if;
  -- Customer: စစ်ရုံသာ — လျှော့ကြည့်ပြီး ချက်ချင်း Rollback (Variable တန်ဖိုးကတော့ ကျန်နေသည်)
  begin
    ok := _decrement_stock_internal(p_name, p_qty, p_color, p_size);
    raise exception 'STOCK_PROBE_ROLLBACK';
  exception when others then
    null;
  end;
  return coalesce(ok, false);
end;
$$ language plpgsql security definer set search_path = public;
grant execute on function decrement_stock(text, int, text, text) to anon, authenticated;

create or replace function increment_stock(p_name text, p_qty int, p_color text default null, p_size text default null)
returns void as $$
begin
  if is_admin() then
    perform _increment_stock_internal(p_name, p_qty, p_color, p_size);
  end if;
  -- Customer ခေါ်ရင် ဘာမှ မလုပ် (Stock လျှော့ခြင်းကို Trigger က Order နဲ့ တွဲလုပ်ထားလို့ ပြန်တိုးစရာ မလို)
end;
$$ language plpgsql security definer set search_path = public;
grant execute on function increment_stock(text, int, text, text) to anon, authenticated;

-- Customer Order ဝင်တဲ့အချိန် ဈေးနှုန်း/ငွေပေးချေမှု စစ်ပြီးမှ Stock လျှော့ (မလုံလောက်ရင် Order တစ်ခုလုံး ပယ်)
create or replace function verify_customer_orders()
returns trigger as $$
declare
  g record;
  r record;
  gift_price numeric;
  paid numeric;
  bad text;
begin
  if is_admin() then return null; end if;
  select coalesce(gift_wrap_price, 4500) into gift_price from settings where id = 1;
  gift_price := coalesce(gift_price, 4500);

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

  for r in select product_name, size, color, quantity from new_rows where product_name <> '🎁 Gift ထုပ်ပိုး ဝန်ဆောင်မှု' loop
    if not _decrement_stock_internal(r.product_name, r.quantity, r.color, r.size) then
      raise exception 'OUT_OF_STOCK: %', r.product_name || coalesce(' (' || r.size || coalesce(', ' || r.color, '') || ')', '');
    end if;
  end loop;
  return null;
end;
$$ language plpgsql security definer set search_path = public;

-- Gift Card Online ဝယ်ယူမှု ဝင်တဲ့အချိန် Denomination Stock လျှော့ (Admin Reject လုပ်ရင် Admin က ပြန်တိုးပေးသည်)
create or replace function gift_card_purchase_stock()
returns trigger as $$
declare
  gc_name text;
begin
  if is_admin() then return null; end if;
  select name into gc_name from products where coalesce(is_gift_card,false) = true limit 1;
  if gc_name is null then return null; end if;
  if not _decrement_stock_internal(gc_name, 1, null, (new.amount)::bigint::text) then
    raise exception 'OUT_OF_STOCK: Gift Card %', new.amount;
  end if;
  return null;
end;
$$ language plpgsql security definer set search_path = public;
drop trigger if exists trg_gift_card_purchase_stock on gift_cards;
create trigger trg_gift_card_purchase_stock after insert on gift_cards
  for each row execute function gift_card_purchase_stock();

-- ---------- [MEDIUM] Prepaid Card PIN — Staff/Admin တွေ Customer PIN ကို မဖတ်နိုင်အောင် ----------
-- Customer ကိုယ်တိုင် PIN ကြည့်တာ (get_or_create_card) နဲ့ POS မှာ PIN စစ်တာ (pos_debit_by_card) ကတော့ ပုံမှန်အတိုင်း ရသည်
revoke select on wallets from anon, authenticated;
grant select (user_id, balance, updated_at, card_number) on wallets to authenticated;

-- Owner ရဲ့ Full Backup အတွက်သာ (PIN အပါအဝင်)
create or replace function export_wallets_full()
returns setof wallets as $$
begin
  if not is_owner() then raise exception 'PERMISSION_DENIED: owner only'; end if;
  return query select * from wallets;
end;
$$ language plpgsql security definer set search_path = public;
revoke all on function export_wallets_full() from public, anon;
grant execute on function export_wallets_full() to authenticated;


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
