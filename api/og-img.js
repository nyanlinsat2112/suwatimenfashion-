// SUWATI MEN FASHION — 🖼️ Share Link ပုံကို suwatimenfashion.vercel.app Domain ကနေ ပေး (Supabase ပစ္စည်းပုံ သာ)
// Facebook / Messenger / Viber က ပုံကို ပိုသေချာ ဆွဲယူနိုင်အောင်
// 🔒 Supabase Storage "public" ပုံ Folder ကလွဲပြီး ဘာမှ မယူ (../ ဖြင့် တခြားနေရာ မရောက်အောင်) · ပုံမဟုတ်ရင် မပို့
const HOST = "https://gfatvhxougswmzrjpqkp.supabase.co";
const PREFIX = "/storage/v1/object/public/";
module.exports = async (req, res) => {
  const raw = String((req.query && req.query.u) || "");
  let url = null;
  try{ url = new URL(raw); }catch(e){}
  if(!url || url.origin !== HOST || !url.pathname.startsWith(PREFIX) || /%2e|%2f|\.\./i.test(raw.slice(HOST.length))){
    res.statusCode = 400; return res.end("bad image");
  }
  try{
    const r = await fetch(url.href);
    const type = (r.headers.get("content-type") || "").split(";")[0].trim();
    if(!r.ok || !/^image\//i.test(type)){ res.statusCode = 302; res.setHeader("Location", "/og-image.png"); return res.end(); }
    const buf = Buffer.from(await r.arrayBuffer());
    res.setHeader("Content-Type", type);
    res.setHeader("Content-Length", buf.length);
    res.setHeader("X-Content-Type-Options", "nosniff");
    res.setHeader("Cache-Control", "public, max-age=86400, s-maxage=604800, immutable");
    res.statusCode = 200; res.end(buf);
  }catch(e){ res.statusCode = 302; res.setHeader("Location", "/og-image.png"); res.end(); }
};
