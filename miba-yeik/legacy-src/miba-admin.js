/* ---------- မိဘရိပ်: Booking / Chat / Website ---------- */
const BST={pending:'စောင့်ဆဲ',confirmed:'အတည်ပြုပြီး',done:'ကားရောက်ပြီး',cancelled:'ပယ်ဖျက်',noshow:'မလာ'};
const BCLS={pending:'s-waiting',confirmed:'s-ok',done:'s-paid',cancelled:'s-bad',noshow:'s-bad'};
const WD=['တနင်္ဂနွေ','တနင်္လာ','အင်္ဂါ','ဗုဒ္ဓဟူး','ကြာသပတေး','သောကြာ','စနေ'];
let bookFilter='upcoming',PEND_BK=null,THREAD_T=null,THREAD_ID=null;
async function loadBookings(){const from=dayKey(new Date(Date.now()-30*864e5));S.bookings=(await all('bookings',{f:x=>x.eq('shop_id',SHOP).gte('booking_date',from)})).sort((a,b)=>(a.booking_date+a.time_slot)<(b.booking_date+b.time_slot)?-1:1)}
async function loadThreads(){S.threads=can('customers')?(await rpc('chat_threads',{p_shop:SHOP})||[]):[]}
const unread=()=>(S.threads||[]).reduce((a,t)=>a+(+t.unread||0),0);
const bday=d=>{const x=new Date(d+'T12:00:00'),t=dayKey(new Date()),tm=dayKey(new Date(Date.now()+864e5));return d===t?'ယနေ့':d===tm?'မနက်ဖြန်':WD[x.getDay()]+' '+dm(x)};
function bookingCard(b){
  const act=b.status==='pending'?`<button class="btn sm primary" data-a="bk" data-id="${b.id}" data-k="confirmed">အတည်ပြု</button><button class="btn sm danger" data-a="bk" data-id="${b.id}" data-k="cancelled">ပယ်</button>`
    :b.status==='confirmed'?`<button class="btn sm primary" data-a="bkjob" data-id="${b.id}">ကားရောက်ပြီ → Job ဖွင့်</button><button class="btn sm" data-a="bk" data-id="${b.id}" data-k="noshow">မလာ</button><button class="btn sm danger" data-a="bk" data-id="${b.id}" data-k="cancelled">ပယ်</button>`
    :b.job_id&&job(b.job_id)?`<button class="btn sm" data-a="open" data-id="${b.job_id}">Job ကြည့်ရန်</button>`:'';
  return `<div class="card ${BCLS[b.status]}" style="gap:6px;border-left:5px solid var(--st,var(--line))"><div style="display:flex;gap:10px;align-items:baseline;flex-wrap:wrap">
    <b class="num" style="font-size:22px">${esc(b.time_slot)}</b><b>${bday(b.booking_date)}</b><span class="pill ${BCLS[b.status]}">${BST[b.status]}</span><span class="hint" style="margin-left:auto">#${b.booking_no||''}</span></div>
    <div style="display:flex;gap:8px;align-items:center;flex-wrap:wrap">${b.plate?plate(b.plate,1):''}<span>${esc(b.model||'')}</span></div>
    <div><b>${esc(b.name)}</b> · <span class="num" style="font-size:15px">${esc(b.phone)}</span> <button class="tlink" data-a="copy" data-v="${esc(b.phone)}">ကူး</button>${b.customer_id?' <span class="tag">Online</span>':''}</div>
    ${b.services?`<div class="sub">🔧 ${esc(b.services)}</div>`:''}${b.note?`<div class="sub">“${esc(b.note)}”</div>`:''}
    ${act?`<div class="btns">${act}</div>`:''}</div>`}
async function shrink(file,max=1280){
  if(!/^image\//.test(file.type))throw new Error('ပုံဖိုင် ရွေးပါ');
  const img=await new Promise((res,rej)=>{const i=new Image();i.onload=()=>res(i);i.onerror=()=>rej(new Error('ပုံ ဖွင့်လို့ မရပါ'));i.src=URL.createObjectURL(file)});
  const k=Math.min(1,max/Math.max(img.width,img.height));const c=document.createElement('canvas');c.width=Math.round(img.width*k);c.height=Math.round(img.height*k);
  c.getContext('2d').drawImage(img,0,0,c.width,c.height);return await new Promise(r=>c.toBlob(r,'image/jpeg',.82))}
async function uploadImage(file){const blob=await shrink(file);const path=SHOP+'/'+Date.now()+'-'+Math.random().toString(36).slice(2,7)+'.jpg';
  const {error}=await sb.storage.from('media').upload(path,blob,{contentType:'image/jpeg'});if(error)throw error;return sb.storage.from('media').getPublicUrl(path).data.publicUrl}

Object.assign(VIEWS,{
bookings(){
  const t=dayKey(new Date()),tm=dayKey(new Date(Date.now()+864e5));const B=S.bookings||[];const live=b=>['pending','confirmed'].includes(b.status);
  const fs={upcoming:'လာမည့်',today:'ယနေ့',tomorrow:'မနက်ဖြန်',pending:'စောင့်ဆဲ',past:'ပြီး/ပယ်'};
  const list=B.filter(b=>bookFilter==='today'?b.booking_date===t:bookFilter==='tomorrow'?b.booking_date===tm:bookFilter==='pending'?b.status==='pending':bookFilter==='past'?(!live(b)||b.booking_date<t):live(b)&&b.booking_date>=t);
  if(bookFilter==='past')list.reverse();
  const nP=B.filter(b=>b.status==='pending'&&b.booking_date>=t).length,nT=B.filter(b=>b.booking_date===t&&live(b)).length;
  return `<div class="stats"><div class="stat ${nP?'alert':''}"><span>အတည်ပြုရန် စောင့်ဆဲ</span><b>${nP}</b></div><div class="stat"><span>ယနေ့ Booking</span><b>${nT}</b></div></div>
  <div class="btns"><button class="btn primary" data-a="bknew">＋ ဖုန်းဖြင့် Booking ထည့်</button><button class="btn" data-a="bkrefresh">Refresh</button></div>
  ${chips('bf',fs,bookFilter)}
  <div class="list">${list.map(b=>{const tok=BCLS[b.status];return bookingCard(b).replace('class="card"','class="card '+tok+'"')}).join('')||'<div class="empty">Booking မရှိပါ</div>'}</div>`},
async messages(){
  if(!S.threads)await loadThreads();
  return `${back('ဖောက်သည် Messages',`<button class="btn sm" style="margin-left:auto" data-a="msgrefresh">Refresh</button>`)}
  <div class="hint">Website မှာ Account ဖွင့်ထားတဲ့ ဖောက်သည်တွေ ပို့တဲ့ စာများ</div>
  <div class="list">${(S.threads||[]).map(t=>`<button class="row" data-a="thread" data-id="${t.customer_id}"><span class="grow"><b>${esc(t.name||'')}</b> ${+t.unread?`<span class="pill s-bad">${t.unread} အသစ်</span>`:''}
    <div class="sub" style="white-space:nowrap;overflow:hidden;text-overflow:ellipsis">${t.last_sender==='shop'?'ဆိုင်: ':''}${esc(t.last_body||'📷 ပုံ')}</div></span><span class="sub num" style="font-size:13px;white-space:nowrap">${sameDay(t.last_at,new Date())?hm(t.last_at):dm(t.last_at)}</span></button>`).join('')||'<div class="empty">Message မရှိသေးပါ</div>'}</div>`},
async website(){
  const [bn,ps]=await Promise.all([q(sb.from('banners').select('*').eq('shop_id',SHOP).order('sort')),q(sb.from('posts').select('*').eq('shop_id',SHOP).order('created_at',{ascending:false}).limit(50))]);
  const s=S.shop,own=ROLE==='owner',closed=String(s.closed_days||'').split(',').map(x=>x.trim());const url=siteUrl();
  const thumb=u=>u?`<img src="${esc(u)}" alt="" style="width:64px;height:44px;object-fit:cover;border-radius:6px;flex:none">`:`<span style="width:64px;height:44px;border-radius:6px;flex:none;background:${esc(s.brand_bg||'#1d4fa3')}"></span>`;
  return `${back('Website')}
  <div class="card"><h3>ဖောက်သည် Website</h3><div class="copyrow"><code>${esc(url)}</code><button class="btn sm" data-a="copy" data-v="${esc(url)}">ကူး</button><a class="btn sm" href="${esc(url)}" target="_blank" rel="noopener">ဖွင့်ကြည့်</a></div></div>
  <section class="sec"><h2>Banner <span class="count">${bn.length}</span> <span class="hint">Website ထိပ်ဆုံးမှာ လှည့်ပြမည်</span></h2>
    <div class="list">${bn.map(b=>`<div class="row" style="${b.active?'':'opacity:.55'}">${thumb(b.image_url)}<span class="grow"><b>${esc(b.title||'(ခေါင်းစဉ်မရှိ)')}</b><div class="sub">${esc(b.subtitle||'')}</div></span>
      <button class="btn sm" data-a="bntoggle" data-id="${b.id}" data-v="${b.active?0:1}">${b.active?'ဖျောက်':'ပြ'}</button><button class="link" data-a="bndel" data-id="${b.id}">ဖျက်</button></div>`).join('')||'<div class="empty">Banner မရှိသေးပါ</div>'}</div>
    <form class="card" id="bnform"><h3>Banner အသစ်</h3><div class="two"><label class="f">ခေါင်းစဉ်<input id="bnt" required placeholder="ဝိုင်လဲရင် ကားဆေး အခမဲ့"></label><label class="f">စာတို<input id="bns" placeholder="နိုဝင်ဘာ တစ်လလုံး"></label></div>
      <div class="two"><label class="f">နှိပ်ရင် သွားမည့်နေရာ<select id="bnl"><option value="#booking">Booking</option><option value="#services">ဈေးနှုန်း</option><option value="#posts">သတင်း</option><option value="">မသွား</option></select></label><label class="f">ပုံ (မထည့်လည်းရ)<input id="bni" type="file" accept="image/*" class="inp"></label></div>
      <button class="btn dark">Banner တင်မယ်</button></form></section>
  <section class="sec"><h2>Post / သတင်း <span class="count">${ps.length}</span></h2>
    <div class="list">${ps.map(p=>`<div class="row" style="${p.published?'':'opacity:.55'};align-items:flex-start">${thumb(p.image_url)}<span class="grow"><b>${esc(p.title)}</b><div class="sub">${dmy(p.created_at)} · ${esc(String(p.body||'').slice(0,80))}</div></span>
      <button class="btn sm" data-a="pstoggle" data-id="${p.id}" data-v="${p.published?0:1}">${p.published?'ဖျောက်':'ပြ'}</button><button class="link" data-a="psdel" data-id="${p.id}">ဖျက်</button></div>`).join('')||'<div class="empty">Post မရှိသေးပါ</div>'}</div>
    <form class="card" id="psform"><h3>Post အသစ်</h3><label class="f">ခေါင်းစဉ်<input id="pst" required></label><label class="f">စာသား<textarea id="psb" rows="4" class="inp"></textarea></label>
      <label class="f">ပုံ (မထည့်လည်းရ)<input id="psi" type="file" accept="image/*" class="inp"></label><button class="btn dark">Post တင်မယ်</button></form></section>
  <form class="card" id="bksetform"><h3>Booking Setting</h3>${own?'':'<div class="hint">ဆိုင်ပိုင်ရှင်သာ ပြင်လို့ရပါတယ်</div>'}
    <fieldset ${own?'':'disabled'} style="border:0;padding:0;margin:0;display:grid;gap:10px;min-width:0">
    <label class="f">လက်ခံမည့် အချိန်များ (ကော်မာခံ)<input id="bkslots" value="${esc(s.booking_slots||'')}" placeholder="09:00,10:00,11:00"></label>
    <div class="two"><label class="f">အချိန်တစ်ခုမှာ ကားအရေအတွက်<input id="bkcap" type="number" min="1" max="20" value="${s.slot_capacity||2}"></label><label class="f">ကြိုတင်ယူနိုင်သည့် ရက်<input id="bkdays" type="number" min="1" max="60" value="${s.booking_days||14}"></label></div>
    <div class="f" style="font-size:13px;color:var(--muted)">ပိတ်ရက်<div class="seg">${WD.map((w,i)=>`<label class="check" style="border:1px solid var(--line);border-radius:6px;padding:4px 8px"><input type="checkbox" name="cd" value="${i}" ${closed.includes(String(i))?'checked':''}>${w}</label>`).join('')}</div></div>
    <button class="btn dark">သိမ်းမယ်</button></fieldset></form>`}
});
function siteUrl(){try{return new URL('index.html',location.href).href}catch(e){return 'index.html'}}
async function threadSheet(cid){
  THREAD_ID=cid;const c=cust(cid);
  const draw=async(first)=>{
    let msgs=[];try{msgs=await q(sb.from('chat_messages').select('*').eq('customer_id',cid).order('created_at',{ascending:true}).limit(300))}catch(e){toast(errMsg(e));return}
    if(THREAD_ID!==cid||(!first&&$('#sheet').hidden))return;
    const box=$('#chatbox');const keep=$('#chattxt')?$('#chattxt').value:'';
    const html=msgs.map(m=>`<div style="display:flex;justify-content:${m.sender==='shop'?'flex-end':'flex-start'}"><div style="max-width:80%;padding:7px 11px;border-radius:12px;font-size:14px;line-height:1.55;${m.sender==='shop'?'background:var(--hdr-bg,#1d4fa3);color:#fff;border-bottom-right-radius:3px':'background:var(--surface);border:1px solid var(--line);border-bottom-left-radius:3px'}">
      ${m.image_url?`<a href="${esc(m.image_url)}" target="_blank" rel="noopener"><img src="${esc(m.image_url)}" alt="ပုံ" style="max-width:220px;border-radius:8px;display:block;margin-bottom:${m.body?'4px':'0'}"></a>`:''}${esc(m.body||'')}
      <div style="font-size:10px;opacity:.7;text-align:right">${dm(m.created_at)} ${hm(m.created_at)}${m.sender==='shop'&&m.staff_id?' · '+esc(staffName(m.staff_id)):''}</div></div></div>`).join('')||'<div class="empty">စာ မရှိသေးပါ</div>';
    if(first||!box){sheet(`${head(`<h2>${esc(c.name)}</h2>`,`<span class="num muted" style="font-size:15px">${esc(c.phone)}</span>`)}
      <div id="chatbox" style="display:grid;gap:8px;max-height:52vh;overflow-y:auto;padding:4px 2px">${html}</div>
      <form id="chatform" data-id="${cid}" style="display:flex;gap:8px;align-items:center"><label class="btn sm" style="cursor:pointer" title="ပုံပို့">📷<input id="chatimg" type="file" accept="image/*" hidden></label><input id="chattxt" class="inp" placeholder="စာရေးရန်..." autocomplete="off"><button class="btn primary sm">ပို့</button></form>`);
      $('#chatimg').addEventListener('change',e=>{const f=e.target.files[0];if(f)run(async()=>{const u=await uploadImage(f);await q(sb.from('chat_messages').insert({shop_id:SHOP,customer_id:cid,sender:'shop',staff_id:ME,image_url:u}));draw()})})}
    else{box.innerHTML=html}
    const b2=$('#chatbox');if(b2)b2.scrollTop=b2.scrollHeight;if(!first&&$('#chattxt'))$('#chattxt').value=keep;
    if(msgs.some(m=>m.sender==='customer'&&!m.read_at)){await sb.from('chat_messages').update({read_at:new Date().toISOString()}).eq('customer_id',cid).eq('sender','customer').is('read_at',null);
      const t=(S.threads||[]).find(x=>x.customer_id===cid);if(t)t.unread=0}
  };
  await draw(true);clearInterval(THREAD_T);THREAD_T=setInterval(()=>{if($('#sheet').hidden||THREAD_ID!==cid){clearInterval(THREAD_T);return}draw()},DEMO?5000:12000);
}
