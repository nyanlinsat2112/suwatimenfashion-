p='/home/claude/miba-yeik/demo-backend.js';s=open(p).read()
def R(a,b):
    global s
    assert a in s, a[:80]
    s=s.replace(a,b,1)
R("Garage POS — Demo backend","မိဘရိပ် Auto Service — Demo backend")
R("const KEY = 'gp-demo-db-v2', SKEY = 'gp-demo-session-v2';","const KEY = 'mby-demo-db-v1', SKEY = 'mby-demo-session-v1';")
R("'activity_logs', 'users'];","'activity_logs', 'users', 'bookings', 'chat_messages', 'banners', 'posts', 'media'];")
R("const IDENT = { stock_moves: 1, topups: 1, job_lines: 1, job_payments: 1, activity_logs: 1 };","const IDENT = { stock_moves: 1, topups: 1, job_lines: 1, job_payments: 1, activity_logs: 1, chat_messages: 1 };")
R("{ id: 'u-mech', email: 'mechanic@demo.mm' }, { id: 'u-admin', email: 'admin@garagepos.mm' }];","{ id: 'u-mech', email: 'mechanic@demo.mm' }, { id: 'u-cust', email: 'customer@demo.mm' }];")
R("    T.platform_admins.push({ user_id: 'u-admin' });\n","")
R("is_public: true, plan: 'monthly',\n      paid_until: dayKey(new Date(+today + 19 * 864e5)), monthly_fee: 35000,","is_public: true, plan: 'yearly',\n      paid_until: '2099-12-31', monthly_fee: 0, booking_slots: '09:00,10:00,11:00,13:00,14:00,15:00,16:00', slot_capacity: 2, booking_days: 14, closed_days: '0', viber: '09 123 456 789', facebook: 'https://facebook.com/',")
a=s.index("    // platform admin panel အတွက် ဆိုင်နမူနာ");b=s.index("    const S = 'shop-miba';")
s=s[:a]+s[b:]
R("    T.vehicles.push({ id: 'v15'","    Object.assign(T.customers.find(c => c.id === 'c1'), { user_id: 'u-cust', email: 'customer@demo.mm' });\n    T.vehicles.push({ id: 'v15'")
R("    T.activity_logs.push({ id: nextId('activity_logs'), shop_id: S, by_staff: 'st2', message: 'ငွေစာရင်းပိတ်သည်'",
"""    // Booking
    const nextOpen = n => { const d = new Date(today); let k = 0; while (true) { d.setDate(d.getDate() + 1); if (d.getDay() !== 0 && ++k >= n) return dayKey(d) } };
    let bno = 100; const bk = (o) => T.bookings.push({ id: uuid(), shop_id: S, booking_no: ++bno, customer_id: null, plate: null, model: null, note: '', status: 'pending', job_id: null, shop_note: '', created_at: new Date(+today - 3600e3 * (5 + bno % 7)).toISOString(), ...o });
    if (today.getDay() !== 0) bk({ name: 'ကိုမင်းခန့်', phone: '09 422 118 335', plate: 'YGN 6K-2031', model: 'Toyota Belta', services: 'အင်ဂျင်ဝိုင်လဲ (လက်ခ)', booking_date: dayKey(today), time_slot: '16:00', status: 'confirmed' });
    bk({ name: 'ဒေါ်သန္တာ', phone: T.customers[0].phone, customer_id: 'c1', plate: 'YGN 4C-7788', model: 'Toyota Probox', services: 'ဘရိတ်စစ်/ပြင်', booking_date: nextOpen(1), time_slot: '10:00', note: 'ဘရိတ်နင်းရင် အသံမြည်' });
    bk({ name: 'မစုစု', phone: '09 785 220 104', plate: 'YGN 3M-7710', model: 'Honda Fit', services: 'AC ဂတ်စ်ဖြည့်, ကားဆေး', booking_date: nextOpen(1), time_slot: '13:00' });
    bk({ name: 'ဦးဘိုဘို', phone: '09 450 330 912', plate: 'MDY 1C-5521', model: 'Toyota Hilux', services: 'ဘီးချိန် (Alignment)', booking_date: nextOpen(2), time_slot: '09:00', status: 'confirmed' });
    // Chat
    const msg = (c, sender, body, minsAgo, read) => T.chat_messages.push({ id: nextId('chat_messages'), shop_id: S, customer_id: c, sender, staff_id: sender === 'shop' ? 'st3' : null, body, image_url: null, read_at: read ? now() : null, created_at: new Date(+today - minsAgo * 60e3).toISOString() });
    msg('c1', 'customer', 'မင်္ဂလာပါ။ Brake pad အရှေ့ ရှိလား?', 300, true); msg('c1', 'shop', 'ရှိပါတယ်ခင်ဗျ။ Probox အတွက် 45,000 Ks ပါ။ မနက်ဖြန် Booking လုပ်ထားလိုက်ပါ။', 290, true);
    msg('c1', 'customer', 'Booking တင်ပြီးပါပြီ။ ကျေးဇူးပါ', 40, false);
    msg('c6', 'customer', 'တနင်္ဂနွေ ဖွင့်လား?', 95, false);
    // Banner / Post
    T.banners.push({ id: uuid(), shop_id: S, title: 'ဝိုင်လဲရင် ကားဆေး အခမဲ့', subtitle: 'နိုဝင်ဘာ တစ်လလုံး · Engine Oil 4L ဝယ်ရင်', image_url: null, link: '#booking', active: true, sort: 1, created_at: now() });
    T.banners.push({ id: uuid(), shop_id: S, title: 'Online Booking ရပြီ', subtitle: 'စောင့်စရာမလို — အချိန်ကြိုရွေးပြီး လာခဲ့ပါ', image_url: null, link: '#booking', active: true, sort: 2, created_at: now() });
    T.posts.push({ id: uuid(), shop_id: S, title: 'မိုးရာသီ မတိုင်ခင် ဘရိတ်နဲ့ Wiper စစ်ပါ', body: 'မိုးတွင်း လမ်းချော်တတ်လို့ Brake pad ပါးနေရင် အန္တရာယ်များပါတယ်။ ဆိုင်ကို လာပြရင် ဘရိတ်စစ်ဆေးမှုကို အခမဲ့ ကြည့်ပေးပါတယ်။', image_url: null, published: true, created_at: new Date(+today - 3 * 864e5).toISOString() });
    T.posts.push({ id: uuid(), shop_id: S, title: 'OBD Scanner အသစ် ရောက်ပြီ', body: 'Toyota၊ Honda၊ Nissan၊ Suzuki အားလုံးရဲ့ Engine error code တွေကို ၁၀ မိနစ်အတွင်း ဖတ်ပေးနိုင်ပါပြီ။ Check engine မီးလင်းနေရင် လာခဲ့ပါ။', image_url: null, published: true, created_at: new Date(+today - 12 * 864e5).toISOString() });
    T.activity_logs.push({ id: nextId('activity_logs'), shop_id: S, by_staff: 'st2', message: 'ငွေစာရင်းပိတ်သည်'""")
R("const isMember = shop => { const r = myRole(shop), h = shopOf(shop); return !!r && h && h.plan !== 'suspended' && h.paid_until >= dayKey(new Date()) };",
  "const isMember = shop => { const r = myRole(shop), h = shopOf(shop); return !!r && h && h.plan !== 'suspended' };\n  const myCust = () => (T().customers.find(c => c.user_id && c.user_id === uid()) || {}).id || null;\n  const theShop = () => (T().shops[0] || {}).id;")
R("    if (t === 'users') return false;","    if (t === 'users' || t === 'media') return false;\n    if (t === 'chat_messages') return isMember(row.shop_id) || (!!myCust() && row.customer_id === myCust());\n    if (t === 'customers' && row.user_id && row.user_id === uid()) return true;")
R("    if (t === 'shops') return op === 'update' && myRole(sh) === 'owner';",
  "    if (t === 'shops') return op === 'update' && myRole(sh) === 'owner';\n    if (t === 'chat_messages') return op === 'insert' ? ((isMember(sh) && row.sender === 'shop') || (row.sender === 'customer' && !!myCust() && row.customer_id === myCust() && !row.read_at)) : isMember(sh);\n    if (t === 'bookings') return op !== 'insert' && isMember(sh);\n    if (['banners', 'posts'].includes(t)) return can(sh, 'promo');")
R("    if (['shop_staff', 'parts', 'customers', 'jobs', 'expenses', 'cash_closings', 'activity_logs', 'stock_moves', 'topups', 'job_line_costs'].includes(t) && !r.created_at) r.created_at = now();",
  "    if (['shop_staff', 'parts', 'customers', 'jobs', 'expenses', 'cash_closings', 'activity_logs', 'stock_moves', 'topups', 'job_line_costs', 'chat_messages', 'banners', 'posts', 'bookings'].includes(t) && !r.created_at) r.created_at = now();\n    if (t === 'chat_messages') Object.assign(r, { read_at: null, image_url: null, staff_id: null, ...r });\n    if (t === 'banners') Object.assign(r, { active: true, sort: 0, ...r });\n    if (t === 'posts') Object.assign(r, { published: true, ...r });")
R("active: h.plan !== 'suspended' && h.paid_until >= dayKey(new Date()) } });","active: h.plan !== 'suspended' } });")
R("      if (!uid()) throw 'Login ဝင်ပါ'; if (!String(p_name1 || '').trim()) throw 'ဆိုင်နာမည် ထည့်ပါ';",
  "      if (!uid()) throw 'Login ဝင်ပါ'; if (T().shops.length) throw 'ဆိုင် ရှိပြီးသားပါ — ဆိုင်ပိုင်ရှင်ကို ဝန်ထမ်းအဖြစ် Email နဲ့ ထည့်ခိုင်းပါ';")
R("    platform_shops() {", open('/home/claude/miba-yeik/src/demo_rpcs.js').read()+"    platform_shops() {")
R("      channel() { const c = { on() { return c }, subscribe() { return c } }; return c },",
"""      channel() { const c = { on() { return c }, subscribe() { return c } }; return c },
      storage: { from() { return {
        async upload(path, file) { if (!uid()) return err('Login ဝင်ပါ'); const url = await new Promise((res, rej) => { const r = new FileReader(); r.onload = () => res(r.result); r.onerror = rej; r.readAsDataURL(file) });
          T().media.push({ path, url }); persist(); return { data: { path }, error: null } },
        getPublicUrl(path) { const m = T().media.find(x => x.path === path); return { data: { publicUrl: m ? m.url : '' } } } } } },""")
open(p,'w').write(s)
print('patched')
