// SUWATI MEN FASHION — 🤖 AI (Google Gemini · Free Tier)
// Vercel က အလိုအလျောက် Run ပေးသည် (GitHub မှာ api/ai.js အဖြစ် တင်ရုံ)
// Vercel › Project › Settings › Environment Variables မှာ ထည့်ရန်:
//   GEMINI_API_KEY            — Google AI Studio က API Key (မဖြစ်မနေ)
//   SUPABASE_SERVICE_ROLE_KEY — Website Chat ကို AI က အလိုလို ပြန်ဖြေဖို့ (Chat ဖြေမှ လို)
//   GEMINI_MODEL              — (Optional) Model နာမည် ပြောင်းချင်ရင်
// 🔒 Key တွေကို ဒီဖိုင်ထဲ / GitHub ပေါ် မရေးပါနဲ့ — Vercel Environment Variables ထဲမှာသာ
//
// Tasks:  caption · describe · summary · chat_test (Admin သာ)  ·  chat (Login ဝင်ထားသော Customer)

const SUPABASE_URL = "https://gfatvhxougswmzrjpqkp.supabase.co";
const SUPABASE_ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdmYXR2aHhvdWdzd216cmpwcWtwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODk0NzQ0NTEsImV4cCI6MjEwNTA1MDQ1MX0.SZDCjKzOyQBZCPXib1EyLEdj9NimYbhvA6PXk-9j42U";
const BOT = "🤖 ";                               // AI ဖြေတဲ့ Chat စာ အစ (Admin စာနဲ့ ခွဲသိရန်)
const SHOP = "SUWATI MEN FASHION — နေပြည်တော်ရှိ အမျိုးသား အဝတ်အထည်ဆိုင် (Online Shop: suwatimenfashion.vercel.app)";

const env = (k) => (process.env[k] || "").trim();
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const clip = (s, n) => String(s == null ? "" : s).slice(0, n);
const ks = (n) => Number(n || 0).toLocaleString("en-US");
const noHtml = (s) => String(s || "").replace(/<[^>]*>/g, "").replace(/[<>]/g, "").trim();
// Customer ကိုယ်ရေး အချက်အလက် (ဖုန်း/Email/Card) ကို AI ဆီ မပို့
const mask = (s) => String(s || "")
  .replace(/[\w.+-]+@[\w-]+\.[\w.]+/g, "[email]")
  .replace(/(?:\+?95|0)?[\s-]?9[\d\s-]{6,12}\d/g, "[phone]")
  .replace(/\b\d{4}[\s-]?\d{4}[\s-]?\d{4}[\s-]?\d{4}\b/g, "[card]");

function send(res, code, obj){
  res.statusCode = code;
  res.setHeader("Content-Type", "application/json; charset=utf-8");
  res.setHeader("Cache-Control", "no-store");
  res.end(JSON.stringify(obj));
}

// ---------- Supabase ----------
async function sbUser(token){
  if(!token) return null;
  const r = await fetch(SUPABASE_URL + "/auth/v1/user", { headers: { apikey: SUPABASE_ANON_KEY, Authorization: "Bearer " + token } });
  if(!r.ok) return null;
  const u = await r.json();
  return u && u.id ? u : null;
}
async function sbAdminRole(token, uid){
  const r = await fetch(`${SUPABASE_URL}/rest/v1/admins?select=role&user_id=eq.${encodeURIComponent(uid)}`, { headers: { apikey: SUPABASE_ANON_KEY, Authorization: "Bearer " + token } });
  if(!r.ok) return null;
  const a = await r.json();
  return Array.isArray(a) && a[0] ? a[0].role : null;
}
async function sbAnon(path){
  const r = await fetch(SUPABASE_URL + "/rest/v1/" + path, { headers: { apikey: SUPABASE_ANON_KEY } });
  return r.ok ? r.json() : [];
}
async function sbService(path, opts = {}){
  const key = env("SUPABASE_SERVICE_ROLE_KEY");
  const r = await fetch(SUPABASE_URL + "/rest/v1/" + path, {
    ...opts,
    headers: { apikey: key, Authorization: "Bearer " + key, "Content-Type": "application/json", Prefer: "return=representation", ...(opts.headers || {}) },
  });
  if(!r.ok) throw new Error("db " + r.status + " " + clip(await r.text(), 200));
  const t = await r.text();
  return t ? JSON.parse(t) : null;
}

// ---------- Gemini ----------
async function gemini(system, prompt, { json = true, temperature = 0.8, maxTokens = 2048 } = {}){
  const key = env("GEMINI_API_KEY");
  if(!key){ const e = new Error("AI_NOT_CONFIGURED"); e.code = "AI_NOT_CONFIGURED"; throw e; }
  const models = [...new Set([env("GEMINI_MODEL"), "gemini-flash-latest", "gemini-flash-lite-latest", "gemini-2.5-flash", "gemini-2.0-flash"].filter(Boolean))];
  const body = {
    systemInstruction: { parts: [{ text: system }] },
    contents: [{ role: "user", parts: [{ text: prompt }] }],
    generationConfig: { temperature, maxOutputTokens: maxTokens, ...(json ? { responseMimeType: "application/json" } : {}) },
  };
  let last = null;
  for(const m of models){
    for(let attempt = 0; attempt < 2; attempt++){
      const r = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(m)}:generateContent`, {
        method: "POST", headers: { "Content-Type": "application/json", "x-goog-api-key": key }, body: JSON.stringify(body),
      });
      if(r.status === 404){ last = new Error("model " + m + " not found"); break; }            // နောက် Model စမ်း
      if(r.status === 429){ if(attempt === 0){ await sleep(1500); continue; } const e = new Error("AI_RATE_LIMIT"); e.code = "AI_RATE_LIMIT"; throw e; }
      if(r.status >= 500){ last = new Error("gemini " + r.status); if(attempt === 0){ await sleep(800); continue; } break; }
      if(!r.ok){ const t = await r.text(); const e = new Error("gemini " + r.status + " " + clip(t, 300)); e.code = r.status === 400 || r.status === 403 ? "AI_KEY_ERROR" : "AI_ERROR"; throw e; }
      const d = await r.json();
      const text = ((d.candidates && d.candidates[0] && d.candidates[0].content && d.candidates[0].content.parts) || []).map((p) => p.text || "").join("").trim();
      if(!text){ last = new Error("empty answer"); break; }
      if(!json) return text;
      const raw = text.replace(/^```(?:json)?\s*/i, "").replace(/```\s*$/i, "");
      try{ return JSON.parse(raw); }catch(e){
        const m2 = raw.match(/\{[\s\S]*\}/); if(m2){ try{ return JSON.parse(m2[0]); }catch(_){} }
        last = new Error("bad json"); break;
      }
    }
  }
  const e = last || new Error("AI_ERROR"); e.code = e.code || "AI_ERROR"; throw e;
}

// ---------- Prompts ----------
const VOICE = "မြန်မာစာကို သဘာဝကျကျ၊ နူးနူးညံ့ညံ့၊ ယဉ်ကျေးစွာ ရေးပါ။ ဆိုင်ဘက်က ပြောသူမှာ မိန်းကလေး (\"ရှင့်\"၊ \"နော်\") လေသံ။ Customer ကို \"အကိုလေး\"/\"Customer\" ဟု ခေါ်ပါ။";
function productLine(p){
  const pr = Number(p.price) || 0, sp = Number(p.sale_price) || 0;
  const now = Date.now(), onSale = sp > 0 && sp < pr && (!p.sale_start || Date.parse(p.sale_start) <= now) && (!p.sale_end || Date.parse(p.sale_end) >= now);
  let stock = "";
  if(p.variant_stock && typeof p.variant_stock === "object"){
    const parts = [];
    for(const [sz, cols] of Object.entries(p.variant_stock)){
      if(cols && typeof cols === "object") for(const [cl, q] of Object.entries(cols)){ if(Number(q) > 0) parts.push(`${sz === "_" ? "" : sz}${cl === "_" ? "" : "/" + cl}:${q}`); }
    }
    stock = parts.length ? parts.slice(0, 24).join(", ") : "ကုန်";
  } else stock = p.status === "sold_out" ? "ကုန်" : String(p.stock_qty ?? "?");
  return `- ${clip(p.name, 60).trim()} | ${p.category || ""}${p.subcategory ? "/" + p.subcategory : ""} | ${onSale ? `${ks(sp)} ကျပ် (Sale · မူလ ${ks(pr)})` : ks(pr) + " ကျပ်"} | Size: ${p.sizes || "-"} | အရောင်: ${p.colors || "-"} | လက်ကျန်: ${stock}${p.preorder ? " | Pre-order ရ" : ""}${p.is_gift_card ? " | Gift Card" : ""}${p.description ? " | " + clip(String(p.description).replace(/\s+/g, " "), 140) : ""}`;
}
async function shopContext(priv){
  const [prods, sets] = await Promise.all([
    sbAnon("products?select=name,category,subcategory,price,sale_price,sale_start,sale_end,sizes,colors,variant_stock,stock_qty,status,description,preorder,is_gift_card&visible=eq.true&order=created_at.desc&limit=80"),
    sbAnon("settings?select=delivery_zones,delivery_note,gift_wrap_price,pay_later_enabled,unpaid_cancel_hours,topup_bonus&id=eq.1"),
  ]);
  const s = (Array.isArray(sets) && sets[0]) || {};
  let zones = s.delivery_zones; if(typeof zones === "string"){ try{ zones = JSON.parse(zones); }catch(e){ zones = null; } }
  const zoneTxt = Array.isArray(zones) && zones.length ? zones.map((z) => `${z.name}: ${ks(z.min)}${z.max ? "–" + ks(z.max) : ""} ကျပ်`).join("၊ ") : "Delivery ခ — ပစ္စည်းရောက်မှ Delivery သမားကို ပေးချေ";
  return [
    "## ဆိုင်အကြောင်း", SHOP,
    "## Delivery", zoneTxt + (s.delivery_note ? " · " + s.delivery_note : "") + " (Delivery ခ ကို ပစ္စည်းရောက်မှ ပေးရ)",
    "## ငွေပေးချေမှု", "KBZPay (Website မှာ QR Scan ပြီး Screenshot တင်) · Prepaid Card · Gift Card" + (s.pay_later_enabled ? ` · Login ဝင်ထားရင် Order အရင်တင်ပြီး ${s.unpaid_cancel_hours || 24} နာရီအတွင်း ငွေလွှဲလို့ရ` : ""),
    s.gift_wrap_price ? `Gift ထုပ်ပိုး ဝန်ဆောင်မှု: ${ks(s.gift_wrap_price)} ကျပ်` : "",
    "## Website သုံးပုံ", "ပစ္စည်းနှိပ် → Size/အရောင်ရွေး → ခြင်းထဲထည့် (သို့) Order မှာယူမည် → အချက်အလက်ဖြည့် → ငွေချေ။ Order ID + ဖုန်းနဲ့ Menu › Order Track မှာ ကြည့်လို့ရ။",
    priv && priv.ai_shop_info ? "## ဆိုင်ရှင် ထည့်ထားတဲ့ အချက်အလက် (အရေးကြီး — ဒါကို အရင်ယုံပါ)\n" + clip(priv.ai_shop_info, 3000) : "",
    "## ပစ္စည်းစာရင်း (လက်ရှိ)", (Array.isArray(prods) ? prods : []).map(productLine).join("\n").slice(0, 9000),
  ].filter(Boolean).join("\n");
}

// ---------- Tasks ----------
async function taskCaption(b){
  const p = b.product || {};
  const tone = { soft: "နူးညံ့ ချစ်စရာ", happy: "ပျော်ရွှင် တက်ကြွ", prem: "Premium ခန့်ညား", cute: "Cute ချစ်စရာ" }[b.tone] || "နူးညံ့";
  const lang = { mm: "မြန်မာလို", mix: "မြန်မာ + English ရောပြီး", en: "English လို" }[b.lang] || "မြန်မာလို";
  const plat = b.platform === "tt" ? "TikTok (တိုတို · စာကြောင်း ၃–၄ ကြောင်း · #fyp #foryou #tiktokmyanmar ပါ)" : "Facebook (အပြည့်အစုံ · စာကြောင်း ၆–၁၀ · Emoji သင့်တော်သလောက်)";
  const items = Array.isArray(b.items) && b.items.length > 1 ? "\nPost ထဲပါ ပစ္စည်းများ:\n" + b.items.slice(0, 6).map((x) => `- ${clip(x.name, 60)} — ${ks(x.price)} ကျပ်`).join("\n") : "";
  const out = await gemini(
    `သင်က ${SHOP} အတွက် Social Media Caption ရေးသူ ဖြစ်ပါတယ်။ ${VOICE} ဈေးနှုန်း/Size ကို ပေးထားတာအတိုင်းသာ ရေးပါ — မသိတာ မထွင်ပါနဲ့။ ပစ္စည်းအရည်အသွေး (Cotton % စသည်) မပေးထားရင် မရေးပါနဲ့။`,
    `ပစ္စည်း: ${clip(p.name, 80)}\nဈေး: ${ks(p.price)} ကျပ်${b.pct ? ` → Sale ${b.pct}% လျှော့ (${ks(p.sale)} ကျပ်)` : ""}\nSize: ${clip(p.sizes, 80) || "-"}\nအရောင်: ${clip(p.colors, 80) || "-"}\nအမျိုးအစား: ${clip(p.category, 40)}\nဖော်ပြချက်: ${clip(b.desc || p.description, 300)}${items}\n\nလေသံ: ${tone}\nဘာသာ: ${lang}\nPlatform: ${plat}\nအဆုံးမှာ "🌐 suwatimenfashion.vercel.app" နဲ့ Hashtag (#SUWATI #SuwatiMenFashion အပါအဝင်) ထည့်ပါ။\n\nမတူညီတဲ့ Caption ၃ မျိုး ရေးပါ။ JSON: {"captions":["...","...","..."]}`,
    { temperature: 1 }
  );
  const caps = (out && Array.isArray(out.captions) ? out.captions : []).map((c) => noHtml(c)).filter(Boolean).slice(0, 3);
  if(!caps.length) throw Object.assign(new Error("empty"), { code: "AI_ERROR" });
  return { captions: caps };
}
async function taskDescribe(b){
  const p = b.product || {};
  const out = await gemini(
    `သင်က ${SHOP} ရဲ့ Website ပစ္စည်း ဖော်ပြချက် ရေးသူပါ။ ${VOICE} ပေးထားတဲ့ အချက်အလက်ကနေသာ ရေးပါ — အထည်အမျိုးအစား၊ Brand အစစ်/အတု စတာတွေ မသိရင် မထွင်ပါနဲ့။`,
    `ပစ္စည်း: ${clip(p.name, 80)}\nအမျိုးအစား: ${clip(p.category, 40)} ${clip(p.subcategory, 40)}\nဈေး: ${ks(p.price)} ကျပ်\nSize: ${clip(p.sizes, 80) || "-"}\nအရောင်: ${clip(p.colors, 80) || "-"}\nဆိုင်ရှင် မှတ်ချက်: ${clip(p.note || p.description, 300) || "-"}\n\nWebsite မှာ ပြမယ့် ဖော်ပြချက် စာကြောင်း ၃–၅ ကြောင်း (ဘယ်လိုဝတ်လို့ကောင်းလဲ၊ ဘာနဲ့တွဲလို့ရလဲ၊ Size ရွေးနည်း အကြံ) ရေးပါ။ Hashtag မထည့်ပါ။ JSON: {"description":"..."}`,
    { temperature: 0.8, maxTokens: 1200 }
  );
  const d = noHtml(out && out.description);
  if(!d) throw Object.assign(new Error("empty"), { code: "AI_ERROR" });
  return { description: clip(d, 1500) };
}
async function taskSummary(b){
  const stats = clip(JSON.stringify(b.stats || {}), 12000);
  const out = await gemini(
    `သင်က ${SHOP} ရဲ့ အရောင်း အကြံပေးပါ။ ဆိုင်ရှင်ကို မြန်မာလို တိုတို ရှင်းရှင်း ပြောပါ။ ပေးထားတဲ့ ဂဏန်းတွေကနေသာ ပြောပါ — မထွင်ပါနဲ့။ ငွေကို "ကျပ်" နဲ့ ရေးပါ။`,
    `Data (JSON):\n${stats}\n\nရေးရန်:\n1) "headline" — တစ်ကြောင်းတည်း အနှစ်ချုပ်\n2) "points" — တွေ့ရှိချက် ၃–၅ ခု (ရောင်းကောင်း/မကောင်း၊ ဘာတိုး/ကျ)\n3) "actions" — ဆိုင်ရှင် ဒီအပတ် လုပ်သင့်တာ ၂–၄ ခု (Stock ဖြည့်၊ Sale ချ၊ Post တင် စသည်)\nJSON: {"headline":"...","points":["..."],"actions":["..."]}`,
    { temperature: 0.5, maxTokens: 1500 }
  );
  return {
    headline: noHtml(out && out.headline),
    points: (out && Array.isArray(out.points) ? out.points : []).map(noHtml).filter(Boolean).slice(0, 6),
    actions: (out && Array.isArray(out.actions) ? out.actions : []).map(noHtml).filter(Boolean).slice(0, 5),
  };
}
async function answerChat(question, history, priv){
  const ctx = await shopContext(priv);
  const hist = (history || []).slice(-8).map((m) => `${m.sender === "customer" ? "Customer" : "ဆိုင်"}: ${clip(mask(m.message), 400)}`).join("\n");
  const out = await gemini(
    `သင်က ${SHOP} ရဲ့ Website Chat မှာ Customer မေးခွန်းကို ဖြေပေးတဲ့ AI လက်ထောက်ပါ။ ${VOICE}
စည်းကမ်း:
- အောက်က "ဆိုင်အချက်အလက်" ထဲမှာ ပါတာကိုသာ အခြေခံ ဖြေပါ။ မသေချာရင်/မပါရင် ထွင်မဖြေဘဲ handoff=true ပေးပါ။
- ဈေးလျှော့ပေးမယ်၊ Order ပယ်ပေးမယ်၊ ငွေပြန်အမ်းမယ်၊ Stock ချန်ထားပေးမယ် စတဲ့ ကတိ လုံးဝ မပေးပါနဲ့ — handoff=true။
- Order အခြေအနေ၊ ငွေလွှဲပြီးကြောင်း၊ Prepaid Card လက်ကျန် မေးရင် — Website Menu › Order Track / Profile မှာ ကြည့်နည်း ပြောပြပြီး handoff=true။
- စာ တိုတိုနဲ့ (စာကြောင်း ၁–၄) ဖြေပါ။ HTML/Markdown မသုံးပါ။
- ဆိုင်နဲ့ မဆိုင်တဲ့ မေးခွန်းဆို ယဉ်ကျေးစွာ ငြင်းပါ။
JSON: {"answer":"...","handoff":true|false}

# ဆိုင်အချက်အလက်
${ctx}`,
    `${hist ? "ယခင် စကားဝိုင်း:\n" + hist + "\n\n" : ""}Customer ရဲ့ နောက်ဆုံး မေးခွန်း: ${clip(mask(question), 800)}`,
    { temperature: 0.4, maxTokens: 900 }
  );
  let answer = noHtml(out && out.answer);
  const handoff = !!(out && out.handoff) || !answer;
  if(!answer) answer = "မေးထားတာလေးကို ဆိုင်က Admin ကနေ မကြာခင် ပြန်ဖြေပေးပါမယ်ရှင့် 🙏";
  else if(handoff) answer += "\n(အသေးစိတ်ကို Admin ကနေ မကြာခင် ပြန်ဖြေပေးပါမယ်ရှင့် 🙏)";
  return { answer: clip(answer, 1200), handoff };
}

// Myanmar Time (UTC+6:30) — ဆိုင်ဖွင့်ချိန်အတွင်း ဟုတ်/မဟုတ်
function inShopHours(open, close){
  const now = new Date(Date.now() + 390 * 60000);
  const mins = now.getUTCHours() * 60 + now.getUTCMinutes();
  const t = (s, d) => { const m = /^(\d{1,2}):(\d{2})$/.exec(String(s || "")); return m ? (+m[1]) * 60 + (+m[2]) : d; };
  const o = t(open, 9 * 60), c = t(close, 21 * 60);
  return o <= c ? mins >= o && mins < c : mins >= o || mins < c;
}

async function taskChat(user){
  if(!env("SUPABASE_SERVICE_ROLE_KEY")) return { skipped: "no_service_key" };
  const privRows = await sbService("admin_private_settings?select=ai_chat_mode,ai_open,ai_close,ai_shop_info&id=eq.1");
  const priv = (privRows && privRows[0]) || {};
  const mode = priv.ai_chat_mode || "off";
  if(mode === "off") return { skipped: "off" };
  if(mode === "hours" && inShopHours(priv.ai_open, priv.ai_close)) return { skipped: "shop_open" };
  const uid = encodeURIComponent(user.id);
  const msgs = await sbService(`chat_messages?select=id,sender,message,image_url,created_at,customer_name&user_id=eq.${uid}&order=created_at.desc&limit=20`);
  if(!Array.isArray(msgs) || !msgs.length) return { skipped: "no_message" };
  const lastCustomerIdx = msgs.findIndex((m) => m.sender === "customer");
  if(lastCustomerIdx !== 0) return { skipped: "already_answered" };          // နောက်ဆုံးစာက Customer စာ ဖြစ်မှ
  const q = msgs[0];
  if(!q.message || !String(q.message).trim()) return { skipped: "image_only" };
  if(Date.now() - Date.parse(q.created_at) > 3 * 60000) return { skipped: "old" };
  const human = msgs.find((m) => m.sender === "admin" && !String(m.message || "").startsWith(BOT));
  if(human && Date.now() - Date.parse(human.created_at) < 20 * 60000) return { skipped: "human_active" };   // Admin ကိုယ်တိုင် ဖြေနေဆဲ
  const since10 = new Date(Date.now() - 10 * 60000).toISOString(), since24 = new Date(Date.now() - 864e5).toISOString();
  const recentBot = await sbService(`chat_messages?select=id,created_at&user_id=eq.${uid}&sender=eq.admin&message=like.${encodeURIComponent(BOT + "*")}&created_at=gte.${since24}&limit=60`);
  const n10 = (recentBot || []).filter((m) => m.created_at >= since10).length;
  if(n10 >= 5 || (recentBot || []).length >= 30) return { skipped: "rate" };
  await sleep(1200);                                                          // ဆက်တိုက် ပို့နေရင် နောက်ဆုံးစာကိုသာ ဖြေ
  const again = await sbService(`chat_messages?select=id,sender&user_id=eq.${uid}&order=created_at.desc&limit=1`);
  if(again && again[0] && again[0].id !== q.id) return { skipped: "newer" };
  const hist = msgs.slice(1, 9).reverse().filter((m) => m.message);
  const { answer, handoff } = await answerChat(q.message, hist, priv);
  await sbService("chat_messages", { method: "POST", body: JSON.stringify({
    user_id: user.id, customer_name: q.customer_name || null, sender: "admin", message: BOT + answer, read_by_admin: !handoff, read_by_customer: false,
  }) });
  return { ok: true, handoff };
}

// ---------- Handler ----------
module.exports = async (req, res) => {
  try{
    if(req.method === "GET") return send(res, 200, { configured: !!env("GEMINI_API_KEY"), chat: !!(env("GEMINI_API_KEY") && env("SUPABASE_SERVICE_ROLE_KEY")) });
    if(req.method !== "POST") return send(res, 405, { error: "method" });
    let b = req.body;
    if(typeof b === "string"){ try{ b = JSON.parse(b); }catch(e){ b = {}; } }
    b = b || {};
    if(JSON.stringify(b).length > 20000) return send(res, 413, { error: "too_large" });
    const token = String(req.headers.authorization || "").replace(/^Bearer\s+/i, "");
    const user = await sbUser(token);
    if(!user) return send(res, 401, { error: "login_required" });
    const task = String(b.task || "");
    if(task === "chat") return send(res, 200, await taskChat(user));
    const role = await sbAdminRole(token, user.id);
    if(!role || role === "delivery") return send(res, 403, { error: "admin_only" });
    if(task === "caption") return send(res, 200, await taskCaption(b));
    if(task === "describe") return send(res, 200, await taskDescribe(b));
    if(task === "summary") return send(res, 200, await taskSummary(b));
    if(task === "chat_test"){
      let priv = {};
      if(env("SUPABASE_SERVICE_ROLE_KEY")){ try{ const r = await sbService("admin_private_settings?select=ai_shop_info&id=eq.1"); priv = (r && r[0]) || {}; }catch(e){} }
      if(b.shop_info != null) priv.ai_shop_info = String(b.shop_info);
      return send(res, 200, await answerChat(String(b.question || ""), [], priv));
    }
    return send(res, 400, { error: "unknown_task" });
  }catch(e){
    const code = e.code || "AI_ERROR";
    return send(res, code === "AI_NOT_CONFIGURED" ? 503 : code === "AI_RATE_LIMIT" ? 429 : 500, { error: code, detail: clip(e.message, 200) });
  }
};
