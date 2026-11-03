p='/home/claude/miba-yeik/src/admin-template.html';s=open(p).read()
def R(a,b,cnt=1):
    global s
    assert a in s, 'MISSING: '+a[:90]
    s=s.replace(a,b,cnt)
R('<title>Garage POS</title>','<title>Miba Yeik Admin</title>')
R("Garage POS — Admin App","မိဘရိပ် Auto Service — Admin")
R("const PRODUCT=CFG.PRODUCT||'Garage POS';","const PRODUCT=(CFG.SHOP_NAME1||'မိဘရိပ်')+' Admin';")
R("""    <div class="gbrand"><span class="mark">GP</span><b>${esc(PRODUCT).toUpperCase()}</b></div><div class="gcard">${inner}</div>
    <div class="hint" style="text-align:center"><a href="index.html" style="color:var(--muted)">${esc(PRODUCT)} အကြောင်း</a>""",
"""    <div class="gbrand"><span class="gname"><span class="a">${esc(CFG.SHOP_NAME1||'မိဘရိပ်')}</span><span class="b">${esc(CFG.SHOP_NAME2||'Auto Service')}</span></span></div><div class="gcard">${inner}</div>
    <div class="hint" style="text-align:center"><a href="index.html" style="color:var(--muted)">ဖောက်သည် Website သို့</a>""")
R("signKind='shop';","signKind='staff';")
R("""<button data-a="skind" data-k="shop" aria-pressed="${signKind==='shop'}">ဆိုင်အသစ် ဖွင့်မယ်</button><button data-a="skind" data-k="staff" aria-pressed="${signKind==='staff'}">ဝန်ထမ်းအဖြစ် ဝင်မယ်</button>""",
"""<button data-a="skind" data-k="staff" aria-pressed="${signKind==='staff'}">ဝန်ထမ်း</button><button data-a="skind" data-k="shop" aria-pressed="${signKind==='shop'}">ဆိုင်ပိုင်ရှင် (ပထမဆုံးအကြိမ်)</button>""")
R("""      <div class="hint">${CFG.TRIAL_DAYS||14} ရက် အခမဲ့ — ပြီးရင် တစ်လ ${ks(CFG.PRICE_MONTH||35000)}</div>`:""","""      <div class="hint">ဆိုင်ကို ပထမဆုံး Setup လုပ်ချိန် တစ်ကြိမ်သာ လုပ်ရပါမယ်။</div>`:""")
R("""placeholder="မိဘရိပ်"></label>""","""value="${esc(CFG.SHOP_NAME1||'မိဘရိပ်')}"></label>""")
R("""  ['subscription','Subscription','လစဉ်ကြေး၊ သက်တမ်း',()=>ROLE==='owner',1],
  ['platform','Platform admin','ဆိုင်အားလုံး၏ လစဉ်ကြေး စီမံရန်',()=>isPA]];""",
"""  ['messages','Messages','ဖောက်သည်တွေနဲ့ Chat',()=>can('customers')],
  ['website','Website','Banner၊ Post၊ Booking setting',()=>can('promo')]];""")
R("""['jobs','Job များ',()=>MODE==='app'],""","""['jobs','Job',()=>MODE==='app'],['bookings','Booking',()=>MODE==='app'&&ROLE!=='mechanic'],""")
R("""  more:'<circle""","""  bookings:'<rect x="3" y="5" width="18" height="16" rx="2"/><path d="M3 10h18M8 3v4M16 3v4M8 14h3"/>',
  more:'<circle""")
R("const mapCust=r=>({id:r.id,name:r.name,phone:r.phone||'',balance:r.balance||0});","const mapCust=r=>({id:r.id,name:r.name,phone:r.phone||'',balance:r.balance||0,user_id:r.user_id||null});")
# load
R("await loadDue();if(can('closing'))","await loadDue();if(ROLE!=='mechanic')await loadBookings();await loadThreads();if(can('closing'))")
# realtime extra
R(".on('postgres_changes',{event:'*',table:'parts',...f},onRemote).subscribe();",
  ".on('postgres_changes',{event:'*',table:'parts',...f},onRemote).on('postgres_changes',{event:'*',table:'bookings',...f},onRemote).on('postgres_changes',{event:'*',table:'chat_messages',...f},onRemote).subscribe();")
R("  await reloadParts(true);\n  if($('#sheet').hidden)render();",
  "  await reloadParts(true);\n  const before=(S.bookings||[]).filter(b=>b.status==='pending').length,u0=unread();\n  if(ROLE!=='mechanic')await loadBookings();await loadThreads();\n  if((S.bookings||[]).filter(b=>b.status==='pending').length>before)toast('Booking အသစ် ရောက်လာပါပြီ');else if(unread()>u0)toast('Message အသစ် ရောက်လာပါပြီ');\n  if($('#sheet').hidden)render();")
# home
R("  const closed=S.closingToday===dayKey(now);","  const closed=S.closingToday===dayKey(now);\n  const todayB=(S.bookings||[]).filter(b=>b.booking_date===dayKey(now)&&['pending','confirmed'].includes(b.status)),pendB=(S.bookings||[]).filter(b=>b.status==='pending'&&b.booking_date>=dayKey(now));")
a=s.index("  ${ROLE==='owner'&&left<=5?");b=s.index("\n",a)
s=s[:a]+"""  ${unread()?`<button class="banner" data-a="go" data-k="messages"><span style="flex:1"><b>Message အသစ် ${unread()} စောင်</b>ဖောက်သည်တွေ အကြောင်းပြန်ချက် စောင့်နေပါတယ်</span><span>→</span></button>`:''}
  ${pendB.length?`<button class="banner" data-a="gobook" data-k="pending"><span style="flex:1"><b>Booking ${pendB.length} ခု အတည်ပြုရန် ကျန်</b>ဖောက်သည်ကို ဖုန်းဆက်ပြီး အတည်ပြုပါ</span><span>→</span></button>`:''}"""+s[b:]
R("""    ${mine?`<div class="stat"><span>ကျွန်ုပ်၏ Job</span><b>${mine.length}</b></div>`:''}""",
  """    ${mine?`<div class="stat"><span>ကျွန်ုပ်၏ Job</span><b>${mine.length}</b></div>`:''}
    ${ROLE!=='mechanic'?`<div class="stat"><span>ယနေ့ Booking</span><b>${todayB.length}</b></div>`:''}""")
R("""  ${due.length?`<section class="sec"><h2>ဝိုင်လဲရန် သတိပေးချက်""","""  ${todayB.length?`<section class="sec"><h2>ယနေ့ Booking <span class="count">${todayB.length}</span></h2><div class="list">${todayB.map(b=>bookingCard(b).replace('class="card"','class="card '+BCLS[b.status]+'"')).join('')}</div></section>`:''}
  ${due.length?`<section class="sec"><h2>ဝိုင်လဲရန် သတိပေးချက်""")
# customers online tag
R("""<b>${esc(r.c.name)}</b>${dues.has(r.c.id)""","""<b>${esc(r.c.name)}</b>${r.c.user_id?' <span class="tag">Online</span>':''}${dues.has(r.c.id)""")
R("""<div class="btns"><button class="btn sm dark">သိမ်းမယ်</button><button type="button" class="btn sm" data-a="copy" data-v="${esc(c.phone)}">ဖုန်းနံပါတ် ကူး</button></div></form>""",
  """<div class="btns"><button class="btn sm dark">သိမ်းမယ်</button><button type="button" class="btn sm" data-a="copy" data-v="${esc(c.phone)}">ဖုန်းနံပါတ် ကူး</button>${c.user_id?`<button type="button" class="btn sm" data-a="thread" data-id="${c.id}">Chat</button>`:''}</div></form>""")
# settings
R("""  const s=S.shop,own=ROLE==='owner';const url=publicUrl();""","""  const s=S.shop,own=ROLE==='owner';""")
R("""    <label class="f">Website လိပ်စာ (အင်္ဂလိပ်စာလုံး အသေး၊ ဂဏန်း၊ - သာ)<input id="sslug" value="${esc(s.slug)}" pattern="[a-z0-9\\\\-]{3,40}" required></label>""",
  """    <div class="two"><label class="f">Viber<input id="sviber" value="${esc(s.viber||'')}" placeholder="09 ..."></label><label class="f">Facebook page link<input id="sfb" value="${esc(s.facebook||'')}" placeholder="https://facebook.com/..."></label></div>""")
a=s.index("""  <div class="card"><h3>ဖောက်သည် website link</h3>""");b=s.index("""  <section class="sec"><h2>လက်ခ (ဝန်ဆောင်မှု) ဈေးနှုန်း""")
s=s[:a]+s[b:]
R("""setform:()=>run(async()=>{const slug=v('#sslug').toLowerCase();if(!/^[a-z0-9-]{3,40}$/.test(slug)){toast('Website လိပ်စာမှာ a-z၊ 0-9၊ - သာ သုံးပါ (၃ လုံးမှ ၄၀)');return}""","""setform:()=>run(async()=>{""")
R("""is_public:$('#spub').checked,slug,about""","""is_public:$('#spub').checked,viber:v('#sviber'),facebook:v('#sfb'),about""")
# insert miba code before publicUrl
R("function publicUrl(){", open('/home/claude/miba-yeik/src/miba-admin.js').read()+"\nfunction publicUrl(){")
# close clears thread poll
R("function close(){$('#sheet').hidden=true;openId=null;","function close(){$('#sheet').hidden=true;openId=null;THREAD_ID=null;clearInterval(THREAD_T);")
# newJobForm prefill
R("function newJobForm(){","function newJobForm(bk){PEND_BK=bk?bk.id:null;")
R("""    if(v){const c=cust(v.custId);$('#jm').value=v.model;$('#jc').value=c.name;$('#jt').value=c.phone;$('#jk').placeholder=v.km?'ယခင် '+v.km:'';$('#jfound').textContent='ယခင်ဖောက်သည် — အချက်အလက် ဖြည့်ပေးထားပါတယ်'}else $('#jfound').textContent=''});""",
"""    if(v){const c=cust(v.custId);$('#jm').value=v.model||$('#jm').value;$('#jc').value=c.name;$('#jt').value=c.phone;$('#jk').placeholder=v.km?'ယခင် '+v.km:'';$('#jfound').textContent='ယခင်ဖောက်သည် — အချက်အလက် ဖြည့်ပေးထားပါတယ်'}else $('#jfound').textContent=''});
  if(bk){jp.value=bk.plate||'';$('#jm').value=bk.model||'';$('#jc').value=bk.name;$('#jt').value=bk.phone;$('#jn').value=[bk.services,bk.note].filter(Boolean).join(' · ');jp.dispatchEvent(new Event('input'));$('#jc').value=bk.name;$('#jt').value=bk.phone;
    $('#jfound').textContent='Booking #'+(bk.booking_no||'')+' မှ ဖြည့်ထားပါတယ်'}""")
R("""      const nj=mapJob(r);S.jobs.unshift(nj);""","""      const nj=mapJob(r);S.jobs.unshift(nj);
      if(PEND_BK){const bk=(S.bookings||[]).find(b=>b.id===PEND_BK);PEND_BK=null;
        if(bk){await q(sb.from('bookings').update({status:'done',job_id:nj.id}).eq('id',bk.id));bk.status='done';bk.job_id=nj.id;
          for(const nm of String(bk.services||'').split(/,\\s*/)){const sv=S.services.find(x=>x.active&&x.name===nm.trim());if(sv){const l=await q(sb.from('job_lines').insert({shop_id:SHOP,job_id:nj.id,kind:'svc',service_id:sv.id,name:sv.name,price:sv.price,qty:1}).select().single());nj.lines.push({id:l.id,type:'svc',ref:sv.id,name:sv.name,price:sv.price,qty:1})}}}}""")
# click actions
R("    parefresh:()=>{S.pa=null;render()},","""    parefresh:()=>{S.pa=null;render()},
    bf:()=>{bookFilter=t.dataset.k;render()},gobook:()=>{tab='bookings';sub=null;bookFilter=t.dataset.k||'upcoming';render();scrollTo(0,0)},
    bkrefresh:()=>run(async()=>{await loadBookings();render()}),msgrefresh:()=>run(async()=>{await loadThreads();render()}),
    bk:()=>{const k=t.dataset.k;if(k==='cancelled'&&!dbl(t,'ပယ်မှာ သေချာ?'))return;run(async()=>{const b=S.bookings.find(x=>x.id===id);await q(sb.from('bookings').update({status:k}).eq('id',id));b.status=k;logAct('Booking #'+b.booking_no+' → '+BST[k]);toast(BST[k]);render()})},
    bkjob:()=>{const b=S.bookings.find(x=>x.id===id);newJobForm(b)},
    bknew:()=>{const h=S.shop;const slots=String(h.booking_slots||'').split(',').map(x=>x.trim()).filter(Boolean);sheet(`${head('<h2>Booking ထည့်ရန်</h2>')}<form class="card" id="bkform">
      <div class="two"><label class="f">အမည်<input id="bkn" required></label><label class="f">ဖုန်း<input id="bkp" required inputmode="tel"></label></div>
      <div class="two"><label class="f">နံပါတ်ပြား<input id="bkpl" list="platelist2"></label><label class="f">ကား<input id="bkm"></label></div><datalist id="platelist2">${S.vehicles.map(v=>`<option value="${esc(v.plate)}">`).join('')}</datalist>
      <div class="two"><label class="f">ရက်<input id="bkd" type="date" required value="${dayKey(new Date(Date.now()+864e5))}"></label><label class="f">အချိန်<select id="bkt">${slots.map(x=>`<option>${esc(x)}</option>`).join('')}</select></label></div>
      <label class="f">ဝန်ဆောင်မှု<input id="bks" list="svclist2" placeholder="အင်ဂျင်ဝိုင်လဲ (လက်ခ)"></label><datalist id="svclist2">${S.services.filter(x=>x.active).map(x=>`<option value="${esc(x.name)}">`).join('')}</datalist>
      <label class="f">မှတ်ချက်<input id="bkno"></label><button class="btn primary block">Booking ထည့်မယ်</button></form>`)},
    thread:()=>threadSheet(id),
    bntoggle:()=>run(async()=>{await q(sb.from('banners').update({active:t.dataset.v==='1'}).eq('id',id));render()}),
    bndel:()=>{if(!dbl(t,'?'))return;run(async()=>{await q(sb.from('banners').delete().eq('id',id));logAct('Banner ဖျက်သည်');render()})},
    pstoggle:()=>run(async()=>{await q(sb.from('posts').update({published:t.dataset.v==='1'}).eq('id',id));render()}),
    psdel:()=>{if(!dbl(t,'?'))return;run(async()=>{await q(sb.from('posts').delete().eq('id',id));logAct('Post ဖျက်သည်');render()})},""")
# submit handlers
R("    svcform:()=>run(async()=>{","""    bkform:()=>run(async()=>{const r=await rpc('create_booking',{p_name:v('#bkn'),p_phone:v('#bkp'),p_plate:v('#bkpl'),p_model:v('#bkm'),p_services:v('#bks'),p_date:v('#bkd'),p_slot:v('#bkt'),p_note:v('#bkno')});
      await q(sb.from('bookings').update({status:'confirmed'}).eq('id',r.id));logAct('Booking #'+r.no+' ထည့်သည် (ဖုန်း)');await loadBookings();toast('Booking ထည့်ပြီး');close()}),
    chatform:()=>run(async()=>{const body=v('#chattxt');if(!body)return;await q(sb.from('chat_messages').insert({shop_id:SHOP,customer_id:f.dataset.id,sender:'shop',staff_id:ME,body}));$('#chattxt').value='';threadSheet(f.dataset.id)}),
    bnform:()=>run(async()=>{const fl=$('#bni').files[0];const image_url=fl?await uploadImage(fl):null;await q(sb.from('banners').insert({shop_id:SHOP,title:v('#bnt'),subtitle:v('#bns'),link:v('#bnl'),image_url,sort:Date.now()%100000}));logAct('Banner တင်သည်: '+v('#bnt'));toast('Banner တင်ပြီး');render()}),
    psform:()=>run(async()=>{const fl=$('#psi').files[0];const image_url=fl?await uploadImage(fl):null;await q(sb.from('posts').insert({shop_id:SHOP,title:v('#pst'),body:$('#psb').value.trim(),image_url}));logAct('Post တင်သည်: '+v('#pst'));toast('Post တင်ပြီး');render()}),
    bksetform:()=>run(async()=>{const slots=v('#bkslots').split(',').map(x=>x.trim()).filter(x=>/^\\d{1,2}:\\d{2}$/.test(x)).map(x=>x.padStart(5,'0'));if(!slots.length){toast('အချိန်ကို 09:00 ပုံစံနဲ့ ထည့်ပါ');return}
      const closed=[...document.querySelectorAll('input[name="cd"]:checked')].map(x=>x.value).join(',');
      const r=await q(sb.from('shops').update({booking_slots:slots.join(','),slot_capacity:Math.max(1,+v('#bkcap')||1),booking_days:Math.max(1,+v('#bkdays')||14),closed_days:closed}).eq('id',SHOP).select().single());S.shop=r;logAct('Booking setting ပြင်သည်');toast('သိမ်းပြီးပါပြီ');render()}),
    svcform:()=>run(async()=>{""")
open(p,'w').write(s)
print('ok')
