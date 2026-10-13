// SUWATI MEN FASHION — 🔗 ပစ္စည်း Link ကို Facebook / Messenger / Viber မှာ Share ရင် ပုံ + နာမည် + ဈေး ပေါ်အောင်
// Vercel က အလိုအလျောက် Run ပေးသည် (GitHub မှာ api/share.js အဖြစ် တင်ရုံ) — /p/<ပစ္စည်း ID> Link များအတွက်
const SUPABASE_URL = "https://gfatvhxougswmzrjpqkp.supabase.co";
const SUPABASE_ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdmYXR2aHhvdWdzd216cmpwcWtwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODk0NzQ0NTEsImV4cCI6MjEwNTA1MDQ1MX0.SZDCjKzOyQBZCPXib1EyLEdj9NimYbhvA6PXk-9j42U";
const esc = (s) => String(s == null ? "" : s).replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));

module.exports = async (req, res) => {
  const id = String((req.query && req.query.id) || "").slice(0, 200);
  const host = req.headers["x-forwarded-host"] || req.headers.host || "suwatimenfashion.vercel.app";
  const site = "https://" + host;
  let p = null;
  try {
    const isUuid = /^[0-9a-f-]{36}$/i.test(id);
    const filter = isUuid ? "id=eq." + id : "name=eq." + encodeURIComponent(id);
    const r = await fetch(SUPABASE_URL + "/rest/v1/products?select=id,name,price,description,image_url,images,status,stock_qty,is_gift_card,category&" + filter + "&limit=1", {
      headers: { apikey: SUPABASE_ANON_KEY, Authorization: "Bearer " + SUPABASE_ANON_KEY },
    });
    if (r.ok) p = (await r.json())[0] || null;
  } catch (e) { /* ပစ္စည်း မရလည်း ဆိုင် Link အဖြစ် ပြ */ }

  const target = site + "/?p=" + encodeURIComponent(p ? p.id : id);
  const price = p ? Number(p.price || 0).toLocaleString("en-US") : "";
  const soldOut = p && (p.status === "sold_out" || Number(p.stock_qty) <= 0) && !p.is_gift_card;
  const title = p ? (p.is_gift_card ? p.name + " — 10,000 ကျပ်မှ" : p.name + " — " + price + " ကျပ်" + (soldOut ? " (Sold Out)" : "")) : "SUWATI MEN FASHION";
  const desc = p
    ? ((p.description || "").replace(/\s+/g, " ").slice(0, 150) || (p.category ? p.category + " · " : "") + "SUWATI MEN FASHION — Nay Pyi Taw · KBZPay ဖြင့် Online မှာယူနိုင်ပါသည်")
    : "Streetwear Menswear — Nay Pyi Taw · KBZPay ဖြင့် Online မှာယူနိုင်ပါသည်";
  const firstImg = p ? (p.image_url || String(p.images || "").split(",")[0] || "").trim() : "";
  const image = firstImg || site + "/og-image.png";

  res.setHeader("Content-Type", "text/html; charset=utf-8");
  res.setHeader("Cache-Control", "public, s-maxage=600, stale-while-revalidate=86400");
  res.statusCode = 200;
  res.end(`<!doctype html><html lang="my"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${esc(title)} | SUWATI MEN FASHION</title>
<meta name="description" content="${esc(desc)}">
<meta property="og:type" content="product">
<meta property="og:site_name" content="SUWATI MEN FASHION">
<meta property="og:title" content="${esc(title)}">
<meta property="og:description" content="${esc(desc)}">
<meta property="og:image" content="${esc(image)}">
<meta property="og:image:alt" content="${esc(p ? p.name : "SUWATI MEN FASHION")}">
<meta property="og:url" content="${esc(site + "/p/" + encodeURIComponent(id))}">
${p ? `<meta property="product:price:amount" content="${esc(p.price)}"><meta property="product:price:currency" content="MMK">` : ""}
<meta name="twitter:card" content="summary_large_image">
<meta name="twitter:title" content="${esc(title)}">
<meta name="twitter:description" content="${esc(desc)}">
<meta name="twitter:image" content="${esc(image)}">
<link rel="canonical" href="${esc(target)}">
<meta http-equiv="refresh" content="0;url=${esc(target)}">
<style>body{background:#141412;color:#E9E4D8;font-family:sans-serif;display:grid;place-items:center;min-height:100vh;margin:0}a{color:#D6FF3F}</style>
</head><body><p>SUWATI MEN FASHION — <a href="${esc(target)}">${esc(p ? p.name : "ဆိုင်သို့ သွားရန်")}</a></p>
<script>location.replace(${JSON.stringify(target)});</script></body></html>`);
};
