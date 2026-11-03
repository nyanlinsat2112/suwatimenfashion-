
-- #####################################################################
-- မိဘရိပ် Auto Service — ဆိုင်တစ်ဆိုင်တည်း Edition (ဖောက်သည် Website + Admin)
-- အပေါ်က Garage POS schema ကို ယူသုံးပြီး ဒီအောက်မှာ ထပ်ဖြည့်ထားသည်
-- #####################################################################

-- ---------- ဆိုင်တစ်ဆိုင်တည်း — လစဉ်ကြေး မလို ----------
alter table shops alter column paid_until set default '2099-12-31';
alter table shops alter column plan set default 'yearly';
update shops set paid_until = '2099-12-31', plan = 'yearly' where paid_until < '2099-12-31' and plan <> 'suspended';
alter table shops add column if not exists booking_slots text default '09:00,10:00,11:00,13:00,14:00,15:00,16:00';
alter table shops add column if not exists slot_capacity int default 2;
alter table shops add column if not exists booking_days int default 14;
alter table shops add column if not exists closed_days text default '0';       -- 0=တနင်္ဂနွေ ... 6=စနေ (ကော်မာခံ)
alter table shops add column if not exists viber text;
alter table shops add column if not exists facebook text;

create or replace function is_member(p_shop uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from shop_staff s join shops h on h.id = s.shop_id
                 where s.shop_id = p_shop and s.user_id = auth.uid() and s.active and h.plan <> 'suspended')
$$;

-- ဆိုင်ကို ပထမဆုံးအကြိမ်သာ ဖွင့်လို့ရ (ပထမဆုံး Sign up လုပ်သူ = Owner)
create or replace function create_shop(p_name1 text, p_name2 text, p_owner_name text, p_phone text)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_shop uuid;
begin
  if auth.uid() is null then raise exception 'Login ဝင်ပါ'; end if;
  if exists (select 1 from shops) then raise exception 'ဆိုင် ရှိပြီးသားပါ — ဆိုင်ပိုင်ရှင်ကို ဝန်ထမ်းအဖြစ် Email နဲ့ ထည့်ခိုင်းပါ'; end if;
  if exists (select 1 from customers where user_id = auth.uid()) then raise exception 'ဖောက်သည်အကောင့်ဖြင့် ဆိုင်ဖွင့်လို့ မရပါ'; end if;
  insert into shops(slug, name1, name2, phone) values ('miba-yeik', coalesce(nullif(trim(p_name1),''),'မိဘရိပ်'), coalesce(nullif(trim(p_name2), ''), 'Auto Service'), p_phone)
  returning id into v_shop;
  insert into shop_staff(shop_id, user_id, email, name, phone, role) values (v_shop, auth.uid(), auth.email(), p_owner_name, p_phone, 'owner');
  insert into services(shop_id, name, price, is_oil_change, fav, sort) values
    (v_shop,'အင်ဂျင်ဝိုင်လဲ (လက်ခ)',15000,true,true,1),(v_shop,'ဘရိတ်စစ်/ပြင်',25000,false,true,2),
    (v_shop,'ဘီးချိန် (Alignment)',20000,false,false,3),(v_shop,'AC ဂတ်စ်ဖြည့်',35000,false,false,4),
    (v_shop,'အင်ဂျင်စစ်ဆေး (Scan)',10000,false,true,5),(v_shop,'ကားဆေး',8000,false,false,6);
  insert into categories(shop_id, name) select v_shop, unnest(array['အင်ဂျင်ဝိုင်','Filter','ဘရိတ်','လျှပ်စစ်','အအေးခံ','ဘီး/တာယာ']);
  insert into activity_logs(shop_id, by_staff, message) values (v_shop, my_staff_id(v_shop), 'ဆိုင် ဖွင့်သည်');
  return v_shop;
end $$;

create or replace function the_shop() returns uuid
language sql stable security definer set search_path = public as $$
  select id from shops order by created_at limit 1
$$;

-- ---------- ဖောက်သည် Account ----------
alter table customers add column if not exists user_id uuid references auth.users(id) on delete set null;
alter table customers add column if not exists email text;
create unique index if not exists customers_user_uidx on customers(user_id) where user_id is not null;

create or replace function my_customer_id() returns uuid
language sql stable security definer set search_path = public as $$
  select id from customers where user_id = auth.uid() limit 1
$$;

-- ---------- Booking ----------
create table if not exists bookings (
  id           uuid primary key default gen_random_uuid(),
  shop_id      uuid not null references shops(id) on delete cascade,
  booking_no   int,
  customer_id  uuid references customers(id) on delete set null,
  name         text not null,
  phone        text not null,
  plate        text,
  model        text,
  services     text,
  booking_date date not null,
  time_slot    text not null,
  note         text,
  status       text not null default 'pending' check (status in ('pending','confirmed','done','cancelled','noshow')),
  job_id       uuid references jobs(id) on delete set null,
  shop_note    text,
  created_at   timestamptz default now()
);
create index if not exists bookings_date_idx on bookings(shop_id, booking_date);

-- ---------- Chat ----------
create table if not exists chat_messages (
  id          bigint generated always as identity primary key,
  shop_id     uuid not null references shops(id) on delete cascade,
  customer_id uuid not null references customers(id) on delete cascade,
  sender      text not null check (sender in ('customer','shop')),
  staff_id    uuid references shop_staff(id),
  body        text,
  image_url   text,
  read_at     timestamptz,
  created_at  timestamptz default now(),
  check (coalesce(body,'') <> '' or image_url is not null)
);
create index if not exists chat_customer_idx on chat_messages(customer_id, created_at);

-- ---------- Banner / Post ----------
create table if not exists banners (
  id         uuid primary key default gen_random_uuid(),
  shop_id    uuid not null references shops(id) on delete cascade,
  title      text,
  subtitle   text,
  image_url  text,
  link       text,
  active     boolean default true,
  sort       int default 0,
  created_at timestamptz default now()
);
create table if not exists posts (
  id         uuid primary key default gen_random_uuid(),
  shop_id    uuid not null references shops(id) on delete cascade,
  title      text not null,
  body       text,
  image_url  text,
  published  boolean default true,
  created_at timestamptz default now()
);

-- ---------- RLS (အသစ်) ----------
do $$
declare t text; p record;
begin
  foreach t in array array['bookings','chat_messages','banners','posts'] loop
    execute format('alter table %I enable row level security', t);
    for p in select policyname from pg_policies where schemaname = 'public' and tablename = t loop
      execute format('drop policy %I on %I', p.policyname, t);
    end loop;
  end loop;
end $$;
create policy "staff read"   on bookings for select using (is_member(shop_id));
create policy "staff update" on bookings for update using (is_member(shop_id)) with check (is_member(shop_id));
create policy "staff read"   on chat_messages for select using (is_member(shop_id));
create policy "own read"     on chat_messages for select using (customer_id = my_customer_id());
create policy "staff send"   on chat_messages for insert with check (is_member(shop_id) and sender = 'shop');
create policy "own send"     on chat_messages for insert with check (customer_id = my_customer_id() and sender = 'customer' and shop_id = the_shop() and read_at is null);
create policy "staff mark"   on chat_messages for update using (is_member(shop_id)) with check (is_member(shop_id));
create policy "staff read"   on banners for select using (is_member(shop_id));
create policy "write"        on banners for all using (shop_can(shop_id,'promo')) with check (shop_can(shop_id,'promo'));
create policy "staff read"   on posts for select using (is_member(shop_id));
create policy "write"        on posts for all using (shop_can(shop_id,'promo')) with check (shop_can(shop_id,'promo'));
-- ဖောက်သည်က ကိုယ့်အချက်အလက်ကို ဖတ်ရ
create policy "own read" on customers for select using (user_id = auth.uid());

-- ---------- Website RPC (Login မလို) ----------
create or replace function site_info() returns json
language sql stable security definer set search_path = public as $$
  select json_build_object(
    'name1', h.name1, 'name2', h.name2, 'address', h.address, 'phone', h.phone, 'viber', h.viber, 'facebook', h.facebook,
    'about', h.about, 'hours', h.hours, 'map_url', h.map_url, 'brand_bg', h.brand_bg, 'brand_fg', h.brand_fg,
    'oil_km', h.oil_km, 'oil_months', h.oil_months,
    'booking', json_build_object('slots', h.booking_slots, 'capacity', h.slot_capacity, 'days', h.booking_days, 'closed', h.closed_days),
    'services', coalesce((select json_agg(json_build_object('id', s.id, 'name', s.name, 'price', s.price, 'description', s.description) order by s.sort, s.name)
                          from services s where s.shop_id = h.id and s.active and s.public), '[]'::json),
    'banners', coalesce((select json_agg(json_build_object('title', b.title, 'subtitle', b.subtitle, 'image_url', b.image_url, 'link', b.link) order by b.sort, b.created_at desc)
                          from banners b where b.shop_id = h.id and b.active), '[]'::json),
    'posts', coalesce((select json_agg(x order by x.created_at desc) from (select id, title, body, image_url, created_at from posts p
                          where p.shop_id = h.id and p.published order by created_at desc limit 20) x), '[]'::json))
  from shops h where h.id = the_shop() and h.is_public;
$$;

-- နေ့/အချိန် တစ်ခုချင်း Booking အရေအတွက် (အမည်/ဖုန်း မပါ)
create or replace function booked_counts(p_from date, p_to date)
returns table(booking_date date, time_slot text, n bigint)
language sql stable security definer set search_path = public as $$
  select booking_date, time_slot, count(*) from bookings
   where shop_id = the_shop() and booking_date between p_from and least(p_to, p_from + 60) and status in ('pending','confirmed')
   group by 1, 2;
$$;

create or replace function create_booking(p_name text, p_phone text, p_plate text, p_model text, p_services text, p_date date, p_slot text, p_note text)
returns json language plpgsql security definer set search_path = public as $$
declare h shops; v_cust uuid; v_no int; v_id uuid; v_n int;
begin
  select * into h from shops where id = the_shop();
  if h.id is null or not h.is_public then raise exception 'Booking လက်မခံသေးပါ'; end if;
  if coalesce(trim(p_name),'') = '' or length(regexp_replace(coalesce(p_phone,''), '\D', '', 'g')) < 7 then raise exception 'အမည်နဲ့ ဖုန်းနံပါတ် ထည့်ပါ'; end if;
  if p_date < (now() at time zone 'Asia/Yangon')::date or p_date > (now() at time zone 'Asia/Yangon')::date + h.booking_days then raise exception 'ဒီရက်ကို Booking လုပ်လို့ မရပါ'; end if;
  if extract(dow from p_date)::text = any(string_to_array(replace(coalesce(h.closed_days,''),' ',''), ',')) then raise exception 'ဒီနေ့ ဆိုင်ပိတ်ပါတယ်'; end if;
  if not (p_slot = any(string_to_array(replace(h.booking_slots,' ',''), ','))) then raise exception 'အချိန် မမှန်ပါ'; end if;
  perform pg_advisory_xact_lock(hashtext('booking' || h.id::text));
  select count(*) into v_n from bookings where shop_id = h.id and booking_date = p_date and time_slot = p_slot and status in ('pending','confirmed');
  if v_n >= h.slot_capacity then raise exception 'ဒီအချိန် ပြည့်သွားပါပြီ — တခြားအချိန် ရွေးပါ'; end if;
  select count(*) into v_n from bookings where phone = p_phone and status = 'pending' and created_at > now() - interval '1 day';
  if v_n >= 3 then raise exception 'Booking အများကြီး တင်ထားပါတယ် — ဆိုင်ကို ဖုန်းဆက်ပါ'; end if;
  v_cust := my_customer_id();
  select coalesce(max(booking_no), 100) + 1 into v_no from bookings where shop_id = h.id;
  insert into bookings(shop_id, booking_no, customer_id, name, phone, plate, model, services, booking_date, time_slot, note)
  values (h.id, v_no, v_cust, trim(p_name), trim(p_phone), nullif(upper(trim(p_plate)),''), nullif(trim(p_model),''), left(p_services, 500), p_date, p_slot, left(p_note, 500))
  returning id into v_id;
  return json_build_object('id', v_id, 'no', v_no, 'date', p_date, 'slot', p_slot);
end $$;

-- ဖောက်သည် Account ချိတ်ခြင်း — ဖုန်း + နံပါတ်ပြား ကိုက်မှ ယခင်မှတ်တမ်းကို ချိတ်ပေး
create or replace function customer_register(p_name text, p_phone text, p_plate text)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_id uuid; v_shop uuid := the_shop(); v_digits text := regexp_replace(coalesce(p_phone,''), '\D', '', 'g');
begin
  if auth.uid() is null then raise exception 'Login ဝင်ပါ'; end if;
  if v_shop is null then raise exception 'ဆိုင် မဖွင့်ရသေးပါ'; end if;
  v_id := my_customer_id();
  if v_id is not null then return v_id; end if;
  if length(v_digits) < 7 then raise exception 'ဖုန်းနံပါတ် ထည့်ပါ'; end if;
  if coalesce(trim(p_plate),'') <> '' then
    select c.id into v_id from customers c join vehicles v on v.customer_id = c.id
     where c.shop_id = v_shop and c.user_id is null and regexp_replace(coalesce(c.phone,''), '\D', '', 'g') = v_digits
       and v.plate_key = upper(regexp_replace(p_plate, '[^A-Za-z0-9]', '', 'g')) limit 1;
  end if;
  if v_id is not null then
    update customers set user_id = auth.uid(), email = auth.email() where id = v_id;
  else
    insert into customers(shop_id, name, phone, user_id, email) values (v_shop, coalesce(nullif(trim(p_name),''),'ဖောက်သည်'), trim(p_phone), auth.uid(), auth.email()) returning id into v_id;
    if coalesce(trim(p_plate),'') <> '' then
      insert into vehicles(shop_id, customer_id, plate) values (v_shop, v_id, upper(trim(p_plate))) on conflict (shop_id, plate_key) do nothing;
    end if;
  end if;
  insert into activity_logs(shop_id, message) values (v_shop, 'ဖောက်သည် Account ဖွင့်သည်: ' || coalesce(p_name,''));
  return v_id;
end $$;

create or replace function my_profile() returns json
language plpgsql stable security definer set search_path = public as $$
declare c customers; h shops;
begin
  select * into c from customers where user_id = auth.uid();
  if c.id is null then return null; end if;
  select * into h from shops where id = c.shop_id;
  return json_build_object(
    'id', c.id, 'name', c.name, 'phone', c.phone, 'balance', c.balance,
    'vehicles', coalesce((select json_agg(json_build_object('plate', v.plate, 'model', v.model, 'last_km', v.last_km,
        'oil_due_date', (select (j.paid_at + make_interval(months => h.oil_months))::date from jobs j where j.vehicle_id = v.id and j.status = 'paid'
                           and exists (select 1 from job_lines l join services s on s.id = l.service_id where l.job_id = j.id and s.is_oil_change) order by j.paid_at desc limit 1),
        'oil_due_km', (select j.km + h.oil_km from jobs j where j.vehicle_id = v.id and j.status = 'paid'
                           and exists (select 1 from job_lines l join services s on s.id = l.service_id where l.job_id = j.id and s.is_oil_change) order by j.paid_at desc limit 1)))
      from vehicles v where v.customer_id = c.id), '[]'::json),
    'jobs', coalesce((select json_agg(x order by x.date desc) from (
        select j.job_no as no, j.paid_at as date, j.km, j.total, (select plate from vehicles where id = j.vehicle_id) as plate,
               (select json_agg(l.name || case when l.qty > 1 then ' ×' || l.qty else '' end order by l.id) from job_lines l where l.job_id = j.id) as items
        from jobs j where j.customer_id = c.id and j.status = 'paid' order by j.paid_at desc limit 40) x), '[]'::json),
    'bookings', coalesce((select json_agg(x order by x.booking_date desc, x.time_slot desc) from (
        select id, booking_no, booking_date, time_slot, plate, services, status, shop_note from bookings
         where customer_id = c.id order by booking_date desc limit 20) x), '[]'::json));
end $$;

create or replace function cancel_my_booking(p_id uuid) returns boolean
language plpgsql security definer set search_path = public as $$
begin
  update bookings set status = 'cancelled' where id = p_id and customer_id = my_customer_id() and status in ('pending','confirmed');
  return found;
end $$;

-- Staff: chat thread စာရင်း
create or replace function chat_threads(p_shop uuid)
returns table(customer_id uuid, name text, phone text, last_body text, last_at timestamptz, last_sender text, unread bigint)
language sql stable security definer set search_path = public as $$
  select c.id, c.name, c.phone, m.body, m.created_at, m.sender,
         (select count(*) from chat_messages u where u.customer_id = c.id and u.sender = 'customer' and u.read_at is null)
  from customers c
  join lateral (select * from chat_messages x where x.customer_id = c.id order by created_at desc limit 1) m on true
  where c.shop_id = p_shop and is_member(p_shop)
  order by m.created_at desc;
$$;

-- ---------- ပုံတင်ရန် Storage (Banner / Post / Chat) ----------
do $$
begin
  if exists (select 1 from pg_namespace where nspname = 'storage') then
    insert into storage.buckets (id, name, public) values ('media', 'media', true) on conflict (id) do nothing;
    drop policy if exists "media read" on storage.objects;
    drop policy if exists "media upload" on storage.objects;
    create policy "media read" on storage.objects for select using (bucket_id = 'media');
    create policy "media upload" on storage.objects for insert to authenticated with check (bucket_id = 'media');
  end if;
end $$;

-- ---------- Realtime ----------
do $$
declare t text;
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    foreach t in array array['bookings','chat_messages'] loop
      begin execute format('alter publication supabase_realtime add table %I', t);
      exception when duplicate_object then null; end;
    end loop;
  end if;
end $$;
