// SUWATI MEN FASHION — 🖼️ Share Link ပုံကို suwatimenfashion.vercel.app Domain ကနေ ပေး (Supabase ပစ္စည်းပုံ သာ)
// Facebook / Messenger / Viber က ပုံကို ပိုသေချာ ဆွဲယူနိုင်အောင်
const ALLOW = /^https:\/\/gfatvhxougswmzrjpqkp\.supabase\.co\/storage\/v1\/object\/public\//i;
module.exports = async (req, res) => {
  const u = String((req.query && req.query.u) || "");
  if(!ALLOW.test(u)){ res.statusCode = 400; return res.end("bad image"); }
  try{
    const r = await fetch(u);
    if(!r.ok){ res.statusCode = 302; res.setHeader("Location", "/og-image.png"); return res.end(); }
    const buf = Buffer.from(await r.arrayBuffer());
    res.setHeader("Content-Type", r.headers.get("content-type") || "image/jpeg");
    res.setHeader("Content-Length", buf.length);
    res.setHeader("Cache-Control", "public, max-age=86400, s-maxage=604800, immutable");
    res.statusCode = 200; res.end(buf);
  }catch(e){ res.statusCode = 302; res.setHeader("Location", "/og-image.png"); res.end(); }
};
