-- =====================================================================
-- 🛡️ လုံခြုံရေး စနစ် — SUWATI MEN FASHION
--   ① နေ့တိုင်း ည ၁၁ နာရီ အလိုအလျောက် Data Backup (Storage + Email)
--   ② Admin App ပိတ်ထားလည်း Customer ဖုန်းဆီ Notification အမြဲပို့ (Database ကနေ တိုက်ရိုက်)
-- Supabase → SQL Editor မှာ ဒီဖိုင်တစ်ခုလုံး Run ပါ (ထပ် Run လည်း ဘေးမရှိ)
-- ⚠️ မ Run ခင် — Edge Function "auto-backup" နဲ့ "send-push" ကို Deploy ပြီးသား ဖြစ်ရမည်
-- =====================================================================

-- လိုအပ်တဲ့ Extension များ (Cron = အချိန်ဇယား၊ pg_net = အင်တာနက် ခေါ်ရန်)
create extension if not exists pg_net;
create extension if not exists pg_cron;

-- ---------- လျှို့ဝှက် Setting (ဘယ်သူမှ မဖတ်နိုင် — Server ကသာ သုံး) ----------
create table if not exists app_private_config (
  key text primary key,
  value text not null
);
alter table app_private_config enable row level security;   -- Policy မရှိ = Customer/Staff လုံးဝ မဖတ်နိုင်
revoke all on app_private_config from anon, authenticated;

insert into app_private_config (key, value) values
  ('project_url', 'https://gfatvhxougswmzrjpqkp.supabase.co'),
  ('anon_key', 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdmYXR2aHhvdWdzd216cmpwcWtwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODk0NzQ0NTEsImV4cCI6MjEwNTA1MDQ1MX0.SZDCjKzOyQBZCPXib1EyLEdj9NimYbhvA6PXk-9j42U')
on conflict (key) do update set value = excluded.value;
-- Backup ခေါ်ခွင့် လျှို့ဝှက် Key (တစ်ခါပဲ ထုတ် — ထပ် Run ရင် မပြောင်း)
insert into app_private_config (key, value) values ('backup_secret', md5(random()::text || clock_timestamp()::text) || md5(random()::text))
on conflict (key) do nothing;

-- ---------- ① Backup ဖိုင် သိမ်းမည့် Private Storage ----------
insert into storage.buckets (id, name, public) values ('backups', 'backups', false)
on conflict (id) do update set public = false;
drop policy if exists "Owner can view backups" on storage.objects;
create policy "Owner can view backups" on storage.objects for select
  using (bucket_id = 'backups' and public.is_owner());

-- နေ့တိုင်း ည ၁၁:၀၀ (မြန်မာစံတော်ချိန်) = 16:30 UTC
do $$ begin
  perform cron.unschedule('suwati-daily-backup');
exception when others then null; end $$;
select cron.schedule('suwati-daily-backup', '30 16 * * *', $cron$
  select net.http_post(
    url := (select value from public.app_private_config where key = 'project_url') || '/functions/v1/auto-backup',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || (select value from public.app_private_config where key = 'anon_key'),
      'x-backup-secret', (select value from public.app_private_config where key = 'backup_secret')),
    body := '{"source":"cron"}'::jsonb,
    timeout_milliseconds := 120000);
$cron$);

-- ---------- ② Admin စာ ထွက်တာနဲ့ ဖုန်း Notification ချက်ချင်းပို့ ----------
create or replace function push_on_admin_chat()
returns trigger as $$
declare u text; k text;
begin
  if not exists (select 1 from new_rows where sender = 'admin') then return null; end if;
  select value into u from public.app_private_config where key = 'project_url';
  select value into k from public.app_private_config where key = 'anon_key';
  if u is null then return null; end if;
  begin
    perform net.http_post(
      url := u || '/functions/v1/send-push',
      headers := jsonb_build_object('Content-Type', 'application/json', 'Authorization', 'Bearer ' || coalesce(k, '')),
      body := '{"source":"db"}'::jsonb,
      timeout_milliseconds := 15000);
  exception when others then
    null;   -- Notification မပို့နိုင်လည်း Chat စာ သိမ်းတာ မပျက်စေရ
  end;
  return null;
end;
$$ language plpgsql security definer set search_path = public, extensions;
drop trigger if exists trg_push_on_admin_chat on chat_messages;
create trigger trg_push_on_admin_chat after insert on chat_messages
  referencing new table as new_rows
  for each statement execute function push_on_admin_chat();

-- ✅ စစ်ရန် — Cron Job ပေါ်ရမည်
select jobname, schedule, active from cron.job where jobname = 'suwati-daily-backup';
