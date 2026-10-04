// SUWATI MEN FASHION — Order Email Receipt
// ဒီ code ကို Supabase Dashboard > Edge Functions > New Function ("send-order-email") ထဲမှာ paste လုပ်ပြီး Deploy လုပ်ပါ

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY");
const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

function buildReceiptHtml(orders, storeName) {
  const rows = orders.map(o => `
    <tr>
      <td style="padding:8px; border:1px solid #ddd;">${o.product_name}</td>
      <td style="padding:8px; border:1px solid #ddd;">${o.size || "-"}</td>
      <td style="padding:8px; border:1px solid #ddd;">${o.color || "-"}</td>
      <td style="padding:8px; border:1px solid #ddd;">${o.quantity}</td>
      <td style="padding:8px; border:1px solid #ddd;">${Number(o.unit_price).toLocaleString()} ကျပ်</td>
      <td style="padding:8px; border:1px solid #ddd;">${Number(o.total_amount).toLocaleString()} ကျပ်</td>
    </tr>`).join("");

  const total = orders.reduce((s, o) => s + Number(o.total_amount), 0);
  const first = orders[0];

  return `
  <div style="font-family:Arial,sans-serif; max-width:600px; margin:auto; color:#141412;">
    <h2 style="margin-bottom:4px;">${storeName}</h2>
    <p style="color:#666; margin-top:0;">Order Confirmation</p>
    <p>ကျေးဇူးတင်ပါသည်, <b>${first.customer_name}</b>!</p>
    <p><b>Order ID:</b> ${first.id.slice(0,8).toUpperCase()}<br>
       <b>Order Date:</b> ${new Date(first.created_at).toLocaleString()}</p>

    <table style="width:100%; border-collapse:collapse; margin:16px 0;">
      <tr style="background:#141412; color:#fff;">
        <th style="padding:8px; text-align:left;">ပစ္စည်း</th>
        <th style="padding:8px; text-align:left;">Size</th>
        <th style="padding:8px; text-align:left;">Color</th>
        <th style="padding:8px; text-align:left;">Qty</th>
        <th style="padding:8px; text-align:left;">ဈေး</th>
        <th style="padding:8px; text-align:left;">စုစုပေါင်း</th>
      </tr>
      ${rows}
    </table>

    <p style="font-size:18px;"><b>Total: ${total.toLocaleString()} ကျပ်</b></p>
    <p><b>ပို့ဆောင်ရမည့်လိပ်စာ:</b> ${first.address}<br>
       <b>ဖုန်း:</b> ${first.phone}</p>
    <p><b>Payment Status:</b> ငွေပေးချေမှု စစ်ဆေးဆဲ (Pending Verification)</p>
    <hr style="margin:20px 0; border:none; border-top:1px solid #ddd;">
    <p style="font-size:12px; color:#999;">ဒီ email ကို ${storeName} ကနေ automatic ပို့ထားခြင်းဖြစ်ပါသည်။</p>
  </div>`;
}

const statusLabelsEn = {
  pending_verification: "Pending Payment Verification",
  confirmed: "Payment Confirmed ✅",
  processing: "Processing",
  shipped: "Shipped 🚚",
  delivered: "Delivered 📦",
  cancelled: "Cancelled",
};

function buildStatusUpdateHtml(orders, storeName, status, cancellationReason) {
  const label = statusLabelsEn[status] || status;
  const first = orders[0];
  const total = orders.reduce((s, o) => s + Number(o.total_amount), 0);
  const itemsList = orders.map(o =>
    `<li>${o.product_name} ${o.size?'('+o.size+(o.color?', '+o.color:'')+')':''} x${o.quantity} — ${Number(o.total_amount).toLocaleString()} ကျပ်</li>`
  ).join("");

  return `
  <div style="font-family:Arial,sans-serif; max-width:600px; margin:auto; color:#141412;">
    <h2 style="margin-bottom:4px;">${storeName}</h2>
    <p style="color:#666; margin-top:0;">Order Status Update</p>
    <p>မင်္ဂလာပါ <b>${first.customer_name}</b>,</p>
    <p>သင့် Order <b>#${first.id.slice(0,8).toUpperCase()}</b> ရဲ့ Status ကို
       <b style="color:#C13B1F;">${label}</b> အဖြစ် Update လုပ်လိုက်ပါပြီ။</p>
    ${cancellationReason ? `<div style="background:#fdf0ee; border:2px solid #C13B1F; padding:12px; margin:14px 0;"><b style="color:#C13B1F;">အကြောင်းရင်း:</b> ${cancellationReason}</div>` : ''}
    <ul>${itemsList}</ul>
    <p><b>စုစုပေါင်း:</b> ${total.toLocaleString()} ကျပ်</p>
    <hr style="margin:20px 0; border:none; border-top:1px solid #ddd;">
    <p style="font-size:12px; color:#999;">ဒီ email ကို ${storeName} ကနေ automatic ပို့ထားခြင်းဖြစ်ပါသည်။</p>
  </div>`;
}

async function sendEmail(to, subject, html) {
  return fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${RESEND_API_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      from: "SUWATI MEN FASHION <onboarding@resend.dev>",
      to,
      subject,
      html,
    }),
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const body = await req.json();
    const { order_ids, type, status, cancellation_reason } = body;
    if (!order_ids || !order_ids.length) throw new Error("order_ids required");

    const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

    const { data: orders, error } = await supabase
      .from("orders")
      .select("*")
      .in("id", order_ids);
    if (error || !orders || orders.length === 0) throw new Error("Order not found");

    const { data: settings } = await supabase
      .from("settings")
      .select("*")
      .eq("id", 1)
      .single();

    const storeName = "SUWATI MEN FASHION";
    const orderIdShort = orders[0].id.slice(0, 8).toUpperCase();

    if (type === "status_update") {
      // Group ထဲက ပစ္စည်းအားလုံး customer တူညီစွာ share လို့ combined email တစ်စောင်တည်း ပို့မယ်
      if (orders[0].email) {
        const html = buildStatusUpdateHtml(orders, storeName, status, cancellation_reason);
        const label = statusLabelsEn[status] || status;
        await sendEmail(orders[0].email, `Order Update: ${label} - ${orderIdShort}`, html);
      }
    } else {
      // Default: New order receipt
      const html = buildReceiptHtml(orders, storeName);
      if (orders[0].email) {
        await sendEmail(orders[0].email, `Order Confirmation - ${orderIdShort}`, html);
      }
      if (settings?.admin_email) {
        await sendEmail(settings.admin_email, `🛎️ New Order - ${orderIdShort}`, html);
      }
    }

    return new Response(JSON.stringify({ success: true }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (e) {
    return new Response(JSON.stringify({ error: e.message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
