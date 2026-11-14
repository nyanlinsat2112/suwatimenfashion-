// SUWATI MEN FASHION — Order Email Receipt
// ဒီ code ကို Supabase Dashboard > Edge Functions > New Function ("send-order-email") ထဲမှာ paste လုပ်ပြီး Deploy လုပ်ပါ
// 🛡️ Nov 14 (Bug M3): Status/Cancel အကြောင်းရင်း ကို Request ကနေ မယုံ — Database ထဲက အမှန်ကိုသာ ပို့ · HTML Escape အကုန် ·
//    Receipt = Order တင်ပြီး ၃၀ မိနစ်အတွင်းသာ · Order ID ၅၀ ခုထိ · Order Group တစ်ခုတည်း

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY");
const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
// Resend မှာ Domain Verify လုပ်ပြီးရင် Supabase Secret "EMAIL_FROM" ကို "SUWATI MEN FASHION <order@yourdomain.com>" ထည့်ပါ
const EMAIL_FROM = Deno.env.get("EMAIL_FROM") || "SUWATI MEN FASHION <onboarding@resend.dev>";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

// ── Receipt Email (Nov 10 · Website Receipt ပုံစံ) ──
const SITE_URL = "https://suwatimenfashion.vercel.app";
const CHAT_URL = "https://www.facebook.com/share/18bLyybwC4";
const F_MONO = "'Space Mono','Courier New',Courier,monospace";
const F_HEAD = "Anton,Impact,'Arial Narrow Bold','Helvetica Neue',Arial,sans-serif";
const F_MM = "'Noto Sans Myanmar','Myanmar Text',Pyidaungsu,Arial,sans-serif";
const RECEIPT_WINDOW_MS = 30 * 60 * 1000;
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function esc(v) {
  return String(v ?? "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

function infoRow(label, value) {
  if (!value) return "";
  return `<p style="margin:0 0 6px; font-size:13px; line-height:1.7;"><b>${label}</b>&nbsp; ${value}</p>`;
}

function buildReceiptHtml(orders, storeName) {
  const first = orders[0];
  const total = orders.reduce((s, o) => s + Number(o.total_amount), 0);
  const orderId = first.id.slice(0, 8).toUpperCase();
  const orderDate = new Date(first.created_at).toLocaleString("en-US", { timeZone: "Asia/Yangon" });

  const rows = orders.map(o => {
    const variant = [o.size, o.color].filter(Boolean).map(esc).join(" / ");
    return `
      <tr>
        <td style="padding:14px 0; border-bottom:1px dashed #bdbdbd; font-size:14px; vertical-align:top;">
          <b>${esc(o.product_name)}</b>
          ${variant ? `<br><span style="font-size:11px; color:#5a5a5a;">${variant}</span>` : ""}
        </td>
        <td width="60" style="padding:14px 0; border-bottom:1px dashed #bdbdbd; font-size:14px; text-align:center; vertical-align:top;">x${esc(o.quantity)}</td>
        <td width="90" style="padding:14px 0; border-bottom:1px dashed #bdbdbd; font-size:14px; text-align:right; vertical-align:top;">${Number(o.total_amount).toLocaleString()}</td>
      </tr>`;
  }).join("");

  let delivery = "";
  if (first.delivery_zone || first.delivery_fee_range) {
    delivery = [first.delivery_zone, first.delivery_fee_range].filter(Boolean).map(esc).join(" · ");
    if (first.delivery_fee_range) delivery += " (ပစ္စည်းရောက်မှ Delivery သမားကို ပေးရန် – စုစုပေါင်းထဲ မပါ)";
  }

  const paid = ["confirmed", "verified", "paid"].includes(first.payment_status);
  const payText = (first.payment_method ? esc(first.payment_method) + " – " : "") +
    (paid ? "ငွေချေပြီး" : "ငွေချေမှု စစ်ဆေးဆဲ");

  return `<!doctype html>
<html lang="my">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Anton&family=Space+Mono:wght@400;700&family=Noto+Sans+Myanmar:wght@400;600&display=swap">
</head>
<body style="margin:0; padding:0; background:#161616;">
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" bgcolor="#161616" style="background:#161616;">
<tr><td align="center" style="padding:24px 12px 32px;">

  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" bgcolor="#ffffff" style="max-width:420px; background:#ffffff; color:#161616; font-family:${F_MONO};">
  <tr><td style="padding:26px 22px 28px;">

    <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
      <tr><td align="center" style="font-family:${F_HEAD}; font-size:44px; line-height:1.1; font-weight:bold; color:#161616;">SUWATI<span style="color:#C4391C;">.</span>MEN</td></tr>
      <tr><td align="center" style="font-size:12px; letter-spacing:6px; color:#5a5a5a; padding-top:2px;">FASHION</td></tr>
      <tr><td align="center" style="font-family:${F_MM}; font-size:13px; color:#5a5a5a; padding-top:10px;">နေပြည်တော်၊ ပုဗ္ဗသီရိမြို့</td></tr>
      <tr><td align="center" style="padding-top:14px;">
        <span style="display:inline-block; border:2px solid #161616; padding:6px 18px; font-size:12px; letter-spacing:3px;">ORDER RECEIPT</span>
      </td></tr>
    </table>

    <div style="border-top:3px solid #161616; margin:16px 0; font-size:0; line-height:0;">&nbsp;</div>

    ${infoRow("Order #", orderId)}
    ${infoRow("Date", esc(orderDate))}
    ${infoRow("Customer", esc(first.customer_name))}
    ${infoRow("Phone", esc(first.phone))}
    ${infoRow("Address", esc(first.address))}
    ${infoRow("Delivery", delivery)}

    <div style="border-top:1px dashed #8a8a8a; margin:16px 0; font-size:0; line-height:0;">&nbsp;</div>

    <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
      <tr>
        <td style="padding-bottom:8px; border-bottom:2px solid #161616; font-size:11px; letter-spacing:2px; color:#5a5a5a;">ITEM</td>
        <td width="60" style="padding-bottom:8px; border-bottom:2px solid #161616; font-size:11px; letter-spacing:2px; color:#5a5a5a; text-align:center;">QTY</td>
        <td width="90" style="padding-bottom:8px; border-bottom:2px solid #161616; font-size:11px; letter-spacing:2px; color:#5a5a5a; text-align:right;">AMOUNT</td>
      </tr>
      ${rows}
    </table>

    <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="margin-top:18px; border:4px solid #161616;">
      <tr>
        <td style="padding:16px; font-family:${F_HEAD}; font-size:20px; font-weight:bold;">TOTAL</td>
        <td style="padding:16px; text-align:right; font-family:${F_HEAD}; font-size:32px; font-weight:bold; white-space:nowrap;">${total.toLocaleString()} <span style="font-family:${F_MM}; font-size:14px; font-weight:normal;">ကျပ်</span></td>
      </tr>
    </table>

    <div style="margin-top:16px;">
      <span style="display:inline-block; border:2px solid #161616; padding:8px 14px; font-size:13px;">${payText}</span>
    </div>

    <div style="border-top:3px solid #161616; margin:18px 0 16px; font-size:0; line-height:0;">&nbsp;</div>

    <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
      <tr><td align="center" style="font-family:${F_MM}; font-size:22px; font-weight:600;">ကျေးဇူးတင်ပါသည်!</td></tr>
      <tr><td align="center" style="font-size:10px; letter-spacing:2px; color:#5a5a5a; padding-top:8px;">${esc(storeName)} · @menfashion321</td></tr>
    </table>

  </td></tr>
  </table>

  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="max-width:420px; margin-top:20px; font-family:${F_MONO};">
    <tr>
      <td width="66%" bgcolor="#D8FF3E" align="center" style="background:#D8FF3E;">
        <a href="${SITE_URL}" style="display:block; padding:16px 8px; color:#161616; text-decoration:none; font-size:14px; font-weight:bold;">Order ကြည့်မည်</a>
      </td>
      <td width="10" style="font-size:0; line-height:0;">&nbsp;</td>
      <td bgcolor="#C4391C" align="center" style="background:#C4391C;">
        <a href="${CHAT_URL}" style="display:block; padding:16px 8px; color:#ffffff; text-decoration:none; font-size:14px; font-weight:bold;">Chat</a>
      </td>
    </tr>
    <tr><td colspan="3" align="center" style="padding-top:18px; font-family:${F_MM}; font-size:11px; line-height:1.6; color:#a8a8a8;">ဒီ email ကို ${esc(storeName)} ကနေ automatic ပို့ထားခြင်းဖြစ်ပါသည်။</td></tr>
  </table>

</td></tr>
</table>
</body>
</html>`;
}

const statusLabelsEn = {
  awaiting_payment: "Awaiting Payment",
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
    `<li>${esc(o.product_name)} ${o.size ? "(" + esc(o.size) + (o.color ? ", " + esc(o.color) : "") + ")" : ""} x${esc(o.quantity)} — ${Number(o.total_amount).toLocaleString()} ကျပ်</li>`
  ).join("");

  return `
  <div style="font-family:Arial,sans-serif; max-width:600px; margin:auto; color:#141412;">
    <h2 style="margin-bottom:4px;">${esc(storeName)}</h2>
    <p style="color:#666; margin-top:0;">Order Status Update</p>
    <p>မင်္ဂလာပါ <b>${esc(first.customer_name)}</b>,</p>
    <p>သင့် Order <b>#${esc(first.id.slice(0,8).toUpperCase())}</b> ရဲ့ Status ကို
       <b style="color:#C13B1F;">${esc(label)}</b> အဖြစ် Update လုပ်လိုက်ပါပြီ။</p>
    ${cancellationReason ? `<div style="background:#fdf0ee; border:2px solid #C13B1F; padding:12px; margin:14px 0;"><b style="color:#C13B1F;">အကြောင်းရင်း:</b> ${esc(cancellationReason)}</div>` : ''}
    <ul>${itemsList}</ul>
    <p><b>စုစုပေါင်း:</b> ${total.toLocaleString()} ကျပ်</p>
    <hr style="margin:20px 0; border:none; border-top:1px solid #ddd;">
    <p style="font-size:12px; color:#999;">ဒီ email ကို ${esc(storeName)} ကနေ automatic ပို့ထားခြင်းဖြစ်ပါသည်။</p>
  </div>`;
}

async function sendEmail(to, subject, html) {
  return fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${RESEND_API_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ from: EMAIL_FROM, to, subject, html }),
  });
}

function json(body, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const body = await req.json();
    const { type } = body;
    const order_ids = Array.isArray(body.order_ids) ? body.order_ids.filter((x) => typeof x === "string" && UUID_RE.test(x)) : [];
    if (!order_ids.length) return json({ error: "order_ids required" }, 400);
    if (order_ids.length > 50) return json({ error: "too many order_ids" }, 400);

    const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

    const { data: orders, error } = await supabase
      .from("orders")
      .select("*")
      .in("id", order_ids);
    if (error || !orders || orders.length === 0) return json({ error: "Order not found" }, 404);

    // Order Group တစ်ခုတည်းသာ (တခြားသူ့ Order နဲ့ ရောမပို့)
    const groups = new Set(orders.map((o) => String(o.order_group_id || o.id)));
    if (groups.size !== 1) return json({ error: "orders must belong to one group" }, 400);
    orders.sort((a, b) => String(a.created_at).localeCompare(String(b.created_at)));

    const storeName = "SUWATI MEN FASHION";
    const orderIdShort = orders[0].id.slice(0, 8).toUpperCase();

    if (type === "status_update") {
      // 🛡️ Status / Cancel အကြောင်းရင်း = Database ထဲက အမှန် (Request ထဲက စာကို မယုံ)
      const status = orders[0].order_status;
      const reason = status === "cancelled" ? (orders.find((o) => o.cancellation_reason)?.cancellation_reason || null) : null;
      if (orders[0].email) {
        const html = buildStatusUpdateHtml(orders, storeName, status, reason);
        const label = statusLabelsEn[status] || status;
        await sendEmail(orders[0].email, `Order Update: ${label} - ${orderIdShort}`, html);
      }
    } else {
      // Default: New order receipt — Order အသစ် (၃၀ မိနစ်အတွင်း) သာ
      if (Date.now() - Date.parse(orders[0].created_at) > RECEIPT_WINDOW_MS) return json({ skipped: "old_order" });
      const { data: settings } = await supabase
        .from("settings")
        .select("admin_email")
        .eq("id", 1)
        .single();
      const html = buildReceiptHtml(orders, storeName);
      if (orders[0].email) {
        await sendEmail(orders[0].email, `Order Confirmation - ${orderIdShort}`, html);
      }
      if (settings?.admin_email) {
        await sendEmail(settings.admin_email, `🛎️ New Order - ${orderIdShort}`, html);
      }
    }

    return json({ success: true });
  } catch (e) {
    return json({ error: String(e?.message || e) }, 500);
  }
});
