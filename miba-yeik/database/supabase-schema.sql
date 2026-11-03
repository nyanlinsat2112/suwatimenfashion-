-- =====================================================================
-- မိဘရိပ် Auto Service — Supabase Schema
-- (Garage POS v2 schema အပေါ် ဆိုင်တစ်ဆိုင်တည်း Website edition ထပ်ဖြည့်ထားသည်)
-- ကားဝပ်ရှော့ အများကြီး တစ်စနစ်တည်းမှာ လစဉ်ကြေးနဲ့ သုံးနိုင်အောင်
--
-- အသုံးပြုနည်း: Supabase Dashboard → SQL Editor → ဒီဖိုင်တစ်ခုလုံး Paste → Run
-- (ထပ်ခါ Run လည်း ရပါသည် — ရှိပြီးသား data မပျက်ပါ)
--
--   * Table တိုင်းမှာ shop_id ပါသည်။ ဆိုင်တစ်ဆိုင်က တခြားဆိုင်ရဲ့ data ကို မမြင်ရ (RLS)
--   * ဝန်ထမ်းအဆင့်: owner / manager / staff / mechanic
--   * ငွေရှင်း၊ stock၊ ကြိုတင်ငွေ — RPC function များကနေပဲ (transaction တစ်ခုတည်း)
--   * platform_admins = Garage POS ပိုင်ရှင် (သင်) — ဆိုင်တွေရဲ့ လစဉ်ကြေး သက်တမ်းတိုးရန်
--   * public_shop / vehicle_history — ဆိုင်ရဲ့ ဖောက်သည် website (shop.html) အတွက်
-- =====================================================================

create extension if not exists pgcrypto;

-- ---------- ၁) ဆိုင် ----------
create table if not exists shops (
  id             uuid primary key default gen_random_uuid(),
  slug           text unique not null default ('shop-' || substr(md5(random()::text), 1, 6)),
  name1          text not null,
  name2          text default 'Auto Service',
  address        text,
  phone          text,
  about          text,
  hours          text default 'တနင်္လာ – စနေ  ၈:၀၀ – ၆:၀၀',
  map_url        text,
  brand_bg       text default '#1d4fa3',
  brand_fg       text default '#e3121b',
  receipt_footer text default 'ကျေးဇူးတင်ပါသည်။ နောက်လည်း လာခဲ့ပါဦး။',
  oil_km         int  default 5000,
  oil_months     int  default 3,
  is_public      boolean default true,
  plan           text default 'trial' check (plan in ('trial','monthly','yearly','suspended')),
  paid_until     date default (current_date + 14),
  monthly_fee    int  default 35000,
  created_at     timestamptz default now()
);
alter table shops add column if not exists slug text;
alter table shops add column if not exists about text;
alter table shops add column if not exists hours text default 'တနင်္လာ – စနေ  ၈:၀၀ – ၆:၀၀';
alter table shops add column if not exists map_url text;
alter table shops add column if not exists brand_bg text default '#1d4fa3';
alter table shops add column if not exists brand_fg text default '#e3121b';
alter table shops add column if not exists is_public boolean default true;

create table if not exists platform_admins (
  user_id uuid primary key references auth.users(id) on delete cascade
);

-- ---------- ၂) ဝန်ထမ်း ----------
create table if not exists shop_staff (
  id         uuid primary key default gen_random_uuid(),
  shop_id    uuid not null references shops(id) on delete cascade,
  user_id    uuid references auth.users(id) on delete set null,
  email      text,                       -- ဒီ email နဲ့ Sign up လုပ်ရင် ဒီဆိုင်ကို အလိုအလျောက် ချိတ်ပေးမည်
  name       text not null,
  phone      text,
  role       text not null default 'staff' check (role in ('owner','manager','staff','mechanic')),
  active     boolean default true,
  created_at timestamptz default now(),
  unique (shop_id, user_id)
);
alter table shop_staff add column if not exists email text;
create index if not exists shop_staff_user_idx on shop_staff(user_id);

-- ---------- Helper functions ----------
create or replace function my_role(p_shop uuid) returns text
language sql stable security definer set search_path = public as $$
  select role from shop_staff where shop_id = p_shop and user_id = auth.uid() and active limit 1
$$;

create or replace function is_member(p_shop uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from shop_staff s join shops h on h.id = s.shop_id
                 where s.shop_id = p_shop and s.user_id = auth.uid() and s.active
                   and h.plan <> 'suspended' and h.paid_until >= current_date)
$$;

create or replace function shop_can(p_shop uuid, p_action text) returns boolean
language sql stable security definer set search_path = public as $$
  select case my_role(p_shop)
    when 'owner'    then is_member(p_shop)
    when 'manager'  then is_member(p_shop) and p_action in ('checkout','money','stockEdit','customers','reports','closing','promo','logs','settings')
    when 'staff'    then is_member(p_shop) and p_action in ('checkout','money','stockEdit','customers','closing')
    when 'mechanic' then is_member(p_shop) and p_action in ('jobEdit')
    else false end
$$;

create or replace function is_platform_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from platform_admins where user_id = auth.uid())
$$;

create or replace function my_staff_id(p_shop uuid) returns uuid
language sql stable security definer set search_path = public as $$
  select id from shop_staff where shop_id = p_shop and user_id = auth.uid() limit 1
$$;

-- ---------- ၃) လက်ခ ----------
create table if not exists services (
  id            uuid primary key default gen_random_uuid(),
  shop_id       uuid not null references shops(id) on delete cascade,
  name          text not null,
  price         int  not null default 0,
  description   text,
  is_oil_change boolean default false,
  fav           boolean default false,
  public        boolean default true,     -- ဖောက်သည် website မှာ ပြမည်
  active        boolean default true,
  sort          int default 0
);
alter table services add column if not exists description text;
alter table services add column if not exists public boolean default true;
alter table services add column if not exists sort int default 0;

-- ---------- ၄) အပိုပစ္စည်း ----------
create table if not exists categories (
  id      uuid primary key default gen_random_uuid(),
  shop_id uuid not null references shops(id) on delete cascade,
  name    text not null,
  unique (shop_id, name)
);
create table if not exists parts (
  id          uuid primary key default gen_random_uuid(),
  shop_id     uuid not null references shops(id) on delete cascade,
  category_id uuid references categories(id) on delete set null,
  name        text not null,
  price       int  not null default 0,
  stock       int  not null default 0 check (stock >= 0),
  min_stock   int  not null default 3,
  fav         boolean default false,
  active      boolean default true,
  created_at  timestamptz default now()
);
create table if not exists part_costs (
  part_id uuid primary key references parts(id) on delete cascade,
  shop_id uuid not null references shops(id) on delete cascade,
  cost    int  not null default 0
);
create table if not exists stock_moves (
  id         bigint generated always as identity primary key,
  shop_id    uuid not null references shops(id) on delete cascade,
  part_id    uuid not null references parts(id) on delete cascade,
  qty        int  not null,
  note       text,
  job_id     uuid,
  by_staff   uuid references shop_staff(id),
  created_at timestamptz default now()
);

-- ---------- ၅) ဖောက်သည် နှင့် ကား ----------
create table if not exists customers (
  id         uuid primary key default gen_random_uuid(),
  shop_id    uuid not null references shops(id) on delete cascade,
  name       text not null,
  phone      text,
  balance    int  not null default 0 check (balance >= 0),
  note       text,
  created_at timestamptz default now()
);
create index if not exists customers_phone_idx on customers(shop_id, phone);

create table if not exists vehicles (
  id          uuid primary key default gen_random_uuid(),
  shop_id     uuid not null references shops(id) on delete cascade,
  customer_id uuid references customers(id) on delete set null,
  plate       text not null,
  plate_key   text generated always as (upper(regexp_replace(plate, '[^A-Za-z0-9]', '', 'g'))) stored,
  model       text,
  last_km     int,
  unique (shop_id, plate_key)
);

create table if not exists topups (
  id          bigint generated always as identity primary key,
  shop_id     uuid not null references shops(id) on delete cascade,
  customer_id uuid not null references customers(id) on delete cascade,
  amount      int  not null check (amount > 0),
  method      text not null,
  by_staff    uuid references shop_staff(id),
  created_at  timestamptz default now()
);

-- ---------- ၆) Job Card ----------
create table if not exists jobs (
  id           uuid primary key default gen_random_uuid(),
  shop_id      uuid not null references shops(id) on delete cascade,
  job_no       int  not null,
  vehicle_id   uuid references vehicles(id) on delete set null,
  customer_id  uuid references customers(id) on delete set null,
  km           int,
  note         text,
  status       text not null default 'waiting' check (status in ('waiting','working','done','paid','cancelled')),
  mechanic_id  uuid references shop_staff(id),
  subtotal     int, discount_amt int default 0, promo_code text, promo_amt int default 0, total int,
  cash_given   int, change_amt int,
  cashier_id   uuid references shop_staff(id),
  created_at   timestamptz default now(),
  paid_at      timestamptz,
  unique (shop_id, job_no)
);
create index if not exists jobs_shop_status_idx on jobs(shop_id, status);
create index if not exists jobs_shop_paid_idx   on jobs(shop_id, paid_at);
create index if not exists jobs_vehicle_idx     on jobs(vehicle_id);

create table if not exists job_lines (
  id         bigint generated always as identity primary key,
  shop_id    uuid not null references shops(id) on delete cascade,
  job_id     uuid not null references jobs(id) on delete cascade,
  kind       text not null check (kind in ('svc','part')),
  service_id uuid references services(id),
  part_id    uuid references parts(id),
  name       text not null,
  price      int  not null,
  qty        int  not null default 1 check (qty > 0)
);
create index if not exists job_lines_job_idx on job_lines(job_id);

-- ပစ္စည်းတစ်ခုချင်းရဲ့ ဝယ်ဈေး (ငွေရှင်းချိန်က) — owner ချည်းသာ ဖတ်ရ
create table if not exists job_line_costs (
  line_id    bigint primary key references job_lines(id) on delete cascade,
  shop_id    uuid not null references shops(id) on delete cascade,
  cost       int not null default 0,
  created_at timestamptz default now()
);

create table if not exists job_payments (
  id      bigint generated always as identity primary key,
  shop_id uuid not null references shops(id) on delete cascade,
  job_id  uuid not null references jobs(id) on delete cascade,
  method  text not null check (method in ('Cash','KBZPay','WavePay','AYA Pay','Prepaid')),
  amount  int  not null check (amount > 0)
);
create index if not exists job_payments_job_idx on job_payments(job_id);

-- ---------- ၇) Promo / စရိတ် / စာရင်းပိတ် / Log ----------
create table if not exists promo_codes (
  id        uuid primary key default gen_random_uuid(),
  shop_id   uuid not null references shops(id) on delete cascade,
  code      text not null,
  kind      text not null check (kind in ('pct','ks')),
  value     int  not null check (value > 0),
  starts_at timestamptz default now(),
  ends_at   timestamptz,
  uses      int  default 0,
  active    boolean default true,
  unique (shop_id, code)
);
create table if not exists expenses (
  id         uuid primary key default gen_random_uuid(),
  shop_id    uuid not null references shops(id) on delete cascade,
  spent_on   date not null default current_date,
  category   text not null,
  amount     int  not null check (amount > 0),
  note       text,
  by_staff   uuid references shop_staff(id),
  created_at timestamptz default now()
);
create table if not exists cash_closings (
  id         uuid primary key default gen_random_uuid(),
  shop_id    uuid not null references shops(id) on delete cascade,
  close_date date not null,
  expected   int not null,
  counted    int not null,
  diff       int generated always as (counted - expected) stored,
  by_staff   uuid references shop_staff(id),
  created_at timestamptz default now(),
  unique (shop_id, close_date)
);
create table if not exists activity_logs (
  id         bigint generated always as identity primary key,
  shop_id    uuid not null references shops(id) on delete cascade,
  by_staff   uuid references shop_staff(id),
  message    text not null,
  created_at timestamptz default now()
);
create index if not exists activity_logs_shop_idx on activity_logs(shop_id, created_at desc);

-- =====================================================================
-- ၈) Row Level Security
-- =====================================================================
do $$
declare t text; p record;
begin
  foreach t in array array['shops','platform_admins','shop_staff','services','categories','parts','part_costs','stock_moves',
                           'customers','vehicles','topups','jobs','job_lines','job_line_costs','job_payments',
                           'promo_codes','expenses','cash_closings','activity_logs']
  loop
    execute format('alter table %I enable row level security', t);
    for p in select policyname from pg_policies where schemaname = 'public' and tablename = t loop
      execute format('drop policy %I on %I', p.policyname, t);
    end loop;
  end loop;
end $$;

create policy "shop read"   on shops for select using (my_role(id) is not null or is_platform_admin());
create policy "shop update" on shops for update using (my_role(id) = 'owner') with check (my_role(id) = 'owner');
create policy "pa read" on platform_admins for select using (user_id = auth.uid());

create policy "member read"  on shop_staff for select using (is_member(shop_id) or user_id = auth.uid());
create policy "owner manage" on shop_staff for all using (my_role(shop_id) = 'owner') with check (my_role(shop_id) = 'owner');

-- အဖွဲ့ဝင်အားလုံး ဖတ်ရ
create policy "member read" on services    for select using (is_member(shop_id));
create policy "member read" on categories  for select using (is_member(shop_id));
create policy "member read" on parts       for select using (is_member(shop_id));
create policy "member read" on customers   for select using (is_member(shop_id));
create policy "member read" on vehicles    for select using (is_member(shop_id));
create policy "member read" on jobs        for select using (is_member(shop_id));
create policy "member read" on job_lines   for select using (is_member(shop_id));
create policy "member read" on promo_codes for select using (is_member(shop_id));
-- ငွေနဲ့ဆိုင်သော data — မက္ကင်းနစ် မမြင်ရ
create policy "money read"   on job_payments  for select using (shop_can(shop_id,'money'));
create policy "money read"   on topups        for select using (shop_can(shop_id,'money'));
create policy "closing read" on cash_closings for select using (shop_can(shop_id,'closing'));
create policy "stock read"   on stock_moves   for select using (shop_can(shop_id,'stockEdit'));
create policy "logs read"    on activity_logs for select using (shop_can(shop_id,'logs'));
-- ဝယ်ဈေး၊ အမြတ်၊ စရိတ် — owner ချည်းသာ (part_costs ကို manager လည်း ပြင်ရ)
create policy "owner read"  on part_costs     for select using (my_role(shop_id) in ('owner','manager') and is_member(shop_id));
create policy "owner read"  on job_line_costs for select using (my_role(shop_id) = 'owner' and is_member(shop_id));
create policy "owner read"  on expenses       for select using (my_role(shop_id) = 'owner' and is_member(shop_id));

-- ရေးခွင့်
create policy "write" on services   for all using (shop_can(shop_id,'settings'))  with check (shop_can(shop_id,'settings'));
create policy "write" on categories for all using (shop_can(shop_id,'stockEdit')) with check (shop_can(shop_id,'stockEdit'));
create policy "insert" on parts for insert with check (shop_can(shop_id,'stockEdit') and stock = 0);   -- stock ကို adjust_stock() ကနေပဲ
create policy "update" on parts for update using (shop_can(shop_id,'stockEdit')) with check (shop_can(shop_id,'stockEdit'));
create policy "write" on part_costs for all using (my_role(shop_id) in ('owner','manager') and is_member(shop_id))
                                        with check (my_role(shop_id) in ('owner','manager') and is_member(shop_id));
create policy "insert" on customers for insert with check (is_member(shop_id) and balance = 0);
create policy "update" on customers for update using (shop_can(shop_id,'customers')) with check (shop_can(shop_id,'customers'));
create policy "write" on vehicles for all using (is_member(shop_id)) with check (is_member(shop_id));
create policy "insert" on jobs for insert with check (is_member(shop_id) and status in ('waiting','working','done'));
create policy "update" on jobs for update using (is_member(shop_id) and status not in ('paid','cancelled'))
                                        with check (status <> 'paid' and (status <> 'cancelled' or shop_can(shop_id,'checkout')));
create policy "write" on job_lines for all
  using (is_member(shop_id) and exists (select 1 from jobs j where j.id = job_id and j.status not in ('paid','cancelled')))
  with check (is_member(shop_id) and exists (select 1 from jobs j where j.id = job_id and j.status not in ('paid','cancelled') and j.shop_id = job_lines.shop_id));
create policy "write" on promo_codes for all using (shop_can(shop_id,'promo')) with check (shop_can(shop_id,'promo'));
create policy "write" on expenses for all using (my_role(shop_id) = 'owner' and is_member(shop_id)) with check (my_role(shop_id) = 'owner' and is_member(shop_id));
create policy "write" on cash_closings for all using (shop_can(shop_id,'closing')) with check (shop_can(shop_id,'closing'));
create policy "insert" on activity_logs for insert with check (is_member(shop_id));
-- job_payments / topups / job_line_costs / stock_moves ကို client က တိုက်ရိုက် မရေးရ — RPC ကနေပဲ

-- =====================================================================
-- ၉) RPC — Login / ဆိုင်ဖွင့် / ဝန်ထမ်း
-- =====================================================================

-- ကိုယ်ဝင်ထားတဲ့ ဆိုင်များ (သက်တမ်းကုန်နေလည်း ပြမည် — Subscription မျက်နှာအတွက်)
create or replace function my_shops()
returns table(shop_id uuid, staff_id uuid, role text, name1 text, name2 text, slug text, plan text, paid_until date, monthly_fee int, active boolean)
language sql stable security definer set search_path = public as $$
  select h.id, s.id, s.role, h.name1, h.name2, h.slug, h.plan, h.paid_until, h.monthly_fee,
         (h.plan <> 'suspended' and h.paid_until >= current_date)
  from shop_staff s join shops h on h.id = s.shop_id
  where s.user_id = auth.uid() and s.active
  order by s.created_at
$$;

-- Owner က email နဲ့ ထည့်ထားတဲ့ ဝန်ထမ်းက Sign up လုပ်ပြီး ဝင်လာရင် ချိတ်ပေး
create or replace function claim_staff_invite() returns int
language plpgsql security definer set search_path = public as $$
declare n int;
begin
  if auth.uid() is null or coalesce(auth.email(), '') = '' then return 0; end if;
  update shop_staff set user_id = auth.uid()
   where user_id is null and active and lower(email) = lower(auth.email())
     and not exists (select 1 from shop_staff x where x.shop_id = shop_staff.shop_id and x.user_id = auth.uid());
  get diagnostics n = row_count;
  return n;
end $$;

create or replace function create_shop(p_name1 text, p_name2 text, p_owner_name text, p_phone text)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_shop uuid;
begin
  if auth.uid() is null then raise exception 'Login ဝင်ပါ'; end if;
  if coalesce(trim(p_name1), '') = '' then raise exception 'ဆိုင်နာမည် ထည့်ပါ'; end if;
  insert into shops(name1, name2, phone) values (trim(p_name1), coalesce(nullif(trim(p_name2), ''), 'Auto Service'), p_phone)
  returning id into v_shop;
  insert into shop_staff(shop_id, user_id, email, name, phone, role) values (v_shop, auth.uid(), auth.email(), p_owner_name, p_phone, 'owner');
  insert into services(shop_id, name, price, is_oil_change, fav, sort) values
    (v_shop,'အင်ဂျင်ဝိုင်လဲ (လက်ခ)',15000,true,true,1),(v_shop,'ဘရိတ်စစ်/ပြင်',25000,false,true,2),
    (v_shop,'ဘီးချိန် (Alignment)',20000,false,false,3),(v_shop,'AC ဂတ်စ်ဖြည့်',35000,false,false,4),
    (v_shop,'အင်ဂျင်စစ်ဆေး (Scan)',10000,false,true,5),(v_shop,'ကားဆေး',8000,false,false,6);
  insert into categories(shop_id, name) select v_shop, unnest(array['အင်ဂျင်ဝိုင်','Filter','ဘရိတ်','လျှပ်စစ်','အအေးခံ','ဘီး/တာယာ']);
  insert into activity_logs(shop_id, by_staff, message) values (v_shop, my_staff_id(v_shop), 'ဆိုင်အသစ် ဖွင့်သည်');
  return v_shop;
end $$;

-- Job နံပါတ် (ဆိုင်တစ်ဆိုင်ချင်း J-1001, J-1002 ...)
create or replace function set_job_no() returns trigger language plpgsql as $$
begin
  if new.job_no is null then
    perform pg_advisory_xact_lock(hashtext(new.shop_id::text));
    select coalesce(max(job_no), 1000) + 1 into new.job_no from jobs where shop_id = new.shop_id;
  end if;
  return new;
end $$;
drop trigger if exists jobs_job_no on jobs;
create trigger jobs_job_no before insert on jobs for each row execute function set_job_no();

-- =====================================================================
-- ၁၀) RPC — ငွေရှင်း / Stock / ကြိုတင်ငွေ
-- =====================================================================
-- p_payments: '[{"method":"Cash","amount":20000},{"method":"KBZPay","amount":36700}]'
create or replace function checkout_job(p_job uuid, p_disc_type text, p_disc_val int, p_promo text, p_payments jsonb, p_cash_given int default null)
returns jobs language plpgsql security definer set search_path = public as $$
declare
  j jobs; v_staff uuid; v_sub int; v_disc int := 0; v_promo int := 0; v_total int;
  pr promo_codes; v_paid int; v_prepaid int; v_cash int; r record;
begin
  select * into j from jobs where id = p_job for update;
  if j.id is null then raise exception 'Job မတွေ့ပါ'; end if;
  if not shop_can(j.shop_id,'checkout') then raise exception 'ငွေရှင်းခွင့် မရှိပါ'; end if;
  if j.status in ('paid','cancelled') then raise exception 'ဒီ Job ကို ငွေရှင်းလို့ မရတော့ပါ'; end if;
  v_staff := my_staff_id(j.shop_id);

  select coalesce(sum(price*qty),0) into v_sub from job_lines where job_id = j.id;
  if v_sub = 0 then raise exception 'ပစ္စည်း/လက်ခ မထည့်ရသေးပါ'; end if;

  if p_disc_type = 'pct' then v_disc := round(v_sub * least(greatest(coalesce(p_disc_val,0),0),100) / 100.0);
  elsif p_disc_type = 'ks' then v_disc := least(greatest(coalesce(p_disc_val,0),0), v_sub); end if;

  if coalesce(p_promo,'') <> '' then
    select * into pr from promo_codes where shop_id = j.shop_id and code = upper(trim(p_promo)) for update;
    if pr.id is null or not pr.active or pr.starts_at > now() or (pr.ends_at is not null and pr.ends_at < now())
      then raise exception 'Promo Code သုံးလို့ မရပါ'; end if;
    v_promo := case pr.kind when 'pct' then round((v_sub - v_disc) * pr.value / 100.0) else least(pr.value, v_sub - v_disc) end;
    update promo_codes set uses = uses + 1 where id = pr.id;
  end if;
  v_total := greatest(v_sub - v_disc - v_promo, 0);

  select coalesce(sum((x->>'amount')::int),0),
         coalesce(sum((x->>'amount')::int) filter (where x->>'method' = 'Prepaid'),0),
         coalesce(sum((x->>'amount')::int) filter (where x->>'method' = 'Cash'),0)
    into v_paid, v_prepaid, v_cash from jsonb_array_elements(p_payments) x;
  if v_paid <> v_total then raise exception 'ပေးချေငွေ (%) နှင့် စုစုပေါင်း (%) မကိုက်ပါ', v_paid, v_total; end if;
  if p_cash_given is not null and p_cash_given < v_cash then raise exception 'ဖောက်သည်ပေးငွေ မလုံလောက်ပါ'; end if;

  if v_prepaid > 0 then
    update customers set balance = balance - v_prepaid where id = j.customer_id and balance >= v_prepaid;
    if not found then raise exception 'ကြိုတင်ငွေ မလုံလောက်ပါ'; end if;
  end if;

  for r in select part_id, sum(qty) q from job_lines where job_id = j.id and kind = 'part' and part_id is not null group by part_id loop
    update parts set stock = stock - r.q where id = r.part_id and stock >= r.q;
    if not found then raise exception 'Stock မလုံလောက်ပါ (%)', (select name from parts where id = r.part_id); end if;
    insert into stock_moves(shop_id, part_id, qty, note, job_id, by_staff) values (j.shop_id, r.part_id, -r.q, 'J-'||j.job_no||' ရောင်း', j.id, v_staff);
  end loop;

  insert into job_line_costs(line_id, shop_id, cost)
    select l.id, j.shop_id, coalesce(c.cost, 0) from job_lines l left join part_costs c on c.part_id = l.part_id
     where l.job_id = j.id and l.kind = 'part'
  on conflict (line_id) do update set cost = excluded.cost;

  insert into job_payments(shop_id, job_id, method, amount)
    select j.shop_id, j.id, x->>'method', (x->>'amount')::int from jsonb_array_elements(p_payments) x where (x->>'amount')::int > 0;

  update jobs set status = 'paid', subtotal = v_sub, discount_amt = v_disc, promo_code = nullif(upper(trim(p_promo)),''), promo_amt = v_promo,
         total = v_total, cash_given = p_cash_given,
         change_amt = case when p_cash_given is null then null else p_cash_given - v_cash end,
         cashier_id = v_staff, paid_at = now()
   where id = j.id returning * into j;
  update vehicles set last_km = j.km where id = j.vehicle_id and j.km is not null;
  insert into activity_logs(shop_id, by_staff, message) values (j.shop_id, v_staff, 'J-'||j.job_no||' ငွေရှင်းသည် '||v_total||' Ks');
  return j;
end $$;

-- Stock အဝင်/ချိန်ညှိ (p_delta: +5 ဝင်၊ -1 ချိန်ညှိ)
create or replace function adjust_stock(p_part uuid, p_delta int, p_note text default null)
returns int language plpgsql security definer set search_path = public as $$
declare p parts;
begin
  select * into p from parts where id = p_part for update;
  if p.id is null or not shop_can(p.shop_id,'stockEdit') then raise exception 'ခွင့်မရှိပါ'; end if;
  if p_delta = 0 then return p.stock; end if;
  if p.stock + p_delta < 0 then raise exception 'Stock 0 အောက် မရောက်ရပါ'; end if;
  update parts set stock = stock + p_delta where id = p.id returning stock into p.stock;
  insert into stock_moves(shop_id, part_id, qty, note, by_staff)
    values (p.shop_id, p.id, p_delta, coalesce(p_note, case when p_delta > 0 then 'Stock ဝင်' else 'ချိန်ညှိ' end), my_staff_id(p.shop_id));
  return p.stock;
end $$;

create or replace function topup_customer(p_customer uuid, p_amount int, p_method text)
returns int language plpgsql security definer set search_path = public as $$
declare c customers; v_staff uuid;
begin
  select * into c from customers where id = p_customer for update;
  if c.id is null or not shop_can(c.shop_id,'checkout') then raise exception 'ခွင့်မရှိပါ'; end if;
  if coalesce(p_amount,0) <= 0 then raise exception 'ပမာဏ မမှန်ပါ'; end if;
  if p_method not in ('Cash','KBZPay','WavePay','AYA Pay') then raise exception 'ငွေပေးချေမှု မမှန်ပါ'; end if;
  v_staff := my_staff_id(c.shop_id);
  update customers set balance = balance + p_amount where id = c.id returning balance into c.balance;
  insert into topups(shop_id, customer_id, amount, method, by_staff) values (c.shop_id, c.id, p_amount, p_method, v_staff);
  insert into activity_logs(shop_id, by_staff, message) values (c.shop_id, v_staff, c.name||' ကြိုတင်ငွေ '||p_amount||' Ks ဖြည့်သည် ('||p_method||')');
  return c.balance;
end $$;

-- =====================================================================
-- ၁၁) RPC — Report များ
-- =====================================================================
create or replace function oil_due(p_shop uuid, p_within_days int default 14)
returns table(vehicle_id uuid, plate text, model text, customer_id uuid, customer_name text, phone text, last_change timestamptz, due_date date, due_km int)
language sql stable security definer set search_path = public as $$
  with last_oil as (
    select distinct on (j.vehicle_id) j.vehicle_id, j.paid_at, j.km
    from jobs j join job_lines l on l.job_id = j.id join services s on s.id = l.service_id
    where j.shop_id = p_shop and j.status = 'paid' and s.is_oil_change and j.vehicle_id is not null
    order by j.vehicle_id, j.paid_at desc)
  select v.id, v.plate, v.model, c.id, c.name, c.phone, lo.paid_at,
         (lo.paid_at + make_interval(months => h.oil_months))::date,
         lo.km + h.oil_km
  from last_oil lo join vehicles v on v.id = lo.vehicle_id join shops h on h.id = p_shop
  left join customers c on c.id = v.customer_id
  where shop_can(p_shop, 'customers')
    and (lo.paid_at + make_interval(months => h.oil_months))::date <= current_date + p_within_days
    and not exists (select 1 from jobs o where o.vehicle_id = v.id and o.status in ('waiting','working','done'))
  order by 8;
$$;

create or replace function daily_totals(p_shop uuid, p_day date default current_date)
returns table(method text, amount bigint) language sql stable security definer set search_path = public as $$
  select p.method, sum(p.amount) from job_payments p join jobs j on j.id = p.job_id
   where j.shop_id = p_shop and shop_can(p_shop,'closing') and (j.paid_at at time zone 'Asia/Yangon')::date = p_day
   group by p.method
  union all
  select t.method || ' (ကြိုတင်ငွေဖြည့်)', sum(t.amount) from topups t
   where t.shop_id = p_shop and shop_can(p_shop,'closing') and (t.created_at at time zone 'Asia/Yangon')::date = p_day
   group by t.method;
$$;

create or replace function customer_stats(p_shop uuid)
returns table(customer_id uuid, visits bigint, spent bigint, last_visit timestamptz)
language sql stable security definer set search_path = public as $$
  select customer_id, count(*), coalesce(sum(total),0), max(paid_at) from jobs
   where shop_id = p_shop and status = 'paid' and customer_id is not null and shop_can(p_shop,'customers')
   group by customer_id;
$$;

-- =====================================================================
-- ၁၂) RPC — ဖောက်သည် website (shop.html) — Login မလိုပါ
-- =====================================================================
create or replace function public_shop(p_slug text) returns json
language sql stable security definer set search_path = public as $$
  select json_build_object(
    'name1', h.name1, 'name2', h.name2, 'address', h.address, 'phone', h.phone, 'about', h.about,
    'hours', h.hours, 'map_url', h.map_url, 'brand_bg', h.brand_bg, 'brand_fg', h.brand_fg, 'oil_km', h.oil_km, 'oil_months', h.oil_months,
    'services', coalesce((select json_agg(json_build_object('name', s.name, 'price', s.price, 'description', s.description) order by s.sort, s.name)
                          from services s where s.shop_id = h.id and s.active and s.public), '[]'::json))
  from shops h
  where h.slug = lower(p_slug) and h.is_public and h.plan <> 'suspended' and h.paid_until >= current_date - 7;
$$;

-- ကားမှတ်တမ်း စစ်ရန် — နံပါတ်ပြား + ဖုန်းနံပါတ် နောက်ဆုံး ၄ လုံး ကိုက်မှ ပြမည်
create or replace function vehicle_history(p_slug text, p_plate text, p_phone4 text) returns json
language plpgsql stable security definer set search_path = public as $$
declare h shops; v vehicles; c customers; res json; lo record;
begin
  if p_phone4 !~ '^\d{4}$' then return null; end if;
  select * into h from shops where slug = lower(p_slug) and is_public and plan <> 'suspended';
  if h.id is null then return null; end if;
  select * into v from vehicles where shop_id = h.id and plate_key = upper(regexp_replace(p_plate, '[^A-Za-z0-9]', '', 'g'));
  if v.id is null then return null; end if;
  select * into c from customers where id = v.customer_id;
  if c.id is null or right(regexp_replace(coalesce(c.phone,''), '\D', '', 'g'), 4) <> p_phone4 then return null; end if;
  select j.paid_at, j.km into lo from jobs j where j.vehicle_id = v.id and j.status = 'paid'
     and exists (select 1 from job_lines l join services s on s.id = l.service_id where l.job_id = j.id and s.is_oil_change)
   order by j.paid_at desc limit 1;
  select json_build_object(
    'plate', v.plate, 'model', v.model, 'last_km', v.last_km,
    'oil_due_date', case when lo.paid_at is null then null else (lo.paid_at + make_interval(months => h.oil_months))::date end,
    'oil_due_km', case when lo.km is null then null else lo.km + h.oil_km end,
    'visits', coalesce((select json_agg(json_build_object('date', j.paid_at, 'km', j.km, 'total', j.total,
                         'items', (select json_agg(l.name || case when l.qty > 1 then ' ×' || l.qty else '' end order by l.id) from job_lines l where l.job_id = j.id))
                         order by j.paid_at desc)
                       from (select * from jobs where vehicle_id = v.id and status = 'paid' order by paid_at desc limit 30) j), '[]'::json))
  into res;
  return res;
end $$;

-- =====================================================================
-- ၁၃) RPC — Garage POS ပိုင်ရှင် (platform admin) — လစဉ်ကြေး စီမံ
-- =====================================================================
create or replace function platform_shops()
returns table(id uuid, slug text, name1 text, name2 text, owner_name text, owner_phone text, owner_email text,
              plan text, paid_until date, monthly_fee int, created_at timestamptz, staff_count bigint, jobs_30d bigint)
language sql stable security definer set search_path = public as $$
  select h.id, h.slug, h.name1, h.name2, o.name, coalesce(o.phone, h.phone), coalesce(o.email, u.email::text),
         h.plan, h.paid_until, h.monthly_fee, h.created_at,
         (select count(*) from shop_staff s where s.shop_id = h.id and s.active),
         (select count(*) from jobs j where j.shop_id = h.id and j.created_at > now() - interval '30 days')
  from shops h
  left join lateral (select * from shop_staff s where s.shop_id = h.id and s.role = 'owner' order by s.created_at limit 1) o on true
  left join auth.users u on u.id = o.user_id
  where is_platform_admin()
  order by h.paid_until;
$$;

create or replace function platform_extend(p_shop uuid, p_months int)
returns date language plpgsql security definer set search_path = public as $$
declare d date;
begin
  if not is_platform_admin() then raise exception 'ခွင့်မရှိပါ'; end if;
  update shops set plan = case when p_months >= 12 then 'yearly' else 'monthly' end,
                   paid_until = greatest(paid_until, current_date) + make_interval(months => p_months)
   where id = p_shop returning paid_until into d;
  return d;
end $$;

create or replace function platform_set_suspended(p_shop uuid, p_suspended boolean)
returns text language plpgsql security definer set search_path = public as $$
declare v text;
begin
  if not is_platform_admin() then raise exception 'ခွင့်မရှိပါ'; end if;
  update shops set plan = case when p_suspended then 'suspended' when paid_until > current_date + 20 then 'monthly' else 'trial' end
   where id = p_shop returning plan into v;
  return v;
end $$;

-- =====================================================================
-- ၁၄) Realtime — ဖုန်းအများကြီးမှာ Job တွေ ချက်ချင်း Update ဖြစ်အောင်
-- =====================================================================
do $$
declare t text;
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    foreach t in array array['jobs','job_lines','parts'] loop
      begin
        execute format('alter publication supabase_realtime add table %I', t);
      exception when duplicate_object then null;
      end;
    end loop;
  end if;
end $$;


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
