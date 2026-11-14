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
