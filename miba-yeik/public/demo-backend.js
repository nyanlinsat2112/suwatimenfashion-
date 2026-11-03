/* =====================================================================
   မိဘရိပ် Auto Service — Demo backend
   config.js ထဲမှာ Supabase မထည့်ရသေးရင် (သို့) ?demo နဲ့ ဖွင့်ရင် ဒီဖိုင်ကို သုံးပါတယ်။
   Supabase client ရဲ့ ပုံစံအတိုင်း browser ထဲမှာပဲ အလုပ်လုပ်ပါတယ် — ဆိုင်ရှင်တွေကို ပြသဖို့ / စမ်းဖို့။
   ===================================================================== */
(function () {
  const KEY = 'mby-demo-db-v1', SKEY = 'mby-demo-session-v1';
  const uuid = () => (crypto.randomUUID ? crypto.randomUUID() : 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, c => { const r = Math.random() * 16 | 0; return (c === 'x' ? r : (r & 3 | 8)).toString(16) }));
  const now = () => new Date().toISOString();
  const dayKey = d => { const x = new Date(d); return x.getFullYear() + '-' + String(x.getMonth() + 1).padStart(2, '0') + '-' + String(x.getDate()).padStart(2, '0') };
  const plateKey = p => String(p || '').toUpperCase().replace(/[^A-Z0-9]/g, '');
  const addMonths = (d, m) => { const x = new Date(d); x.setMonth(x.getMonth() + m); return x };
  const TABLES = ['shops', 'platform_admins', 'shop_staff', 'services', 'categories', 'parts', 'part_costs', 'stock_moves', 'customers', 'vehicles', 'topups', 'jobs', 'job_lines', 'job_line_costs', 'job_payments', 'promo_codes', 'expenses', 'cash_closings', 'activity_logs', 'users', 'bookings', 'chat_messages', 'banners', 'posts', 'media'];
  const IDENT = { stock_moves: 1, topups: 1, job_lines: 1, job_payments: 1, activity_logs: 1, chat_messages: 1 };

  /* ---------- seed ---------- */
  function seed() {
    const T = {}; TABLES.forEach(t => T[t] = []); const seq = {};
    let r = 20261030; const rnd = () => (r = (r * 16807) % 2147483647) / 2147483647; const pick = a => a[Math.floor(rnd() * a.length)]; const ri = (a, b) => a + Math.floor(rnd() * (b - a + 1));
    const nextId = t => (seq[t] = (seq[t] || 0) + 1);
    const today = new Date();
    const users = [
      { id: 'u-owner', email: 'owner@demo.mm' }, { id: 'u-manager', email: 'manager@demo.mm' }, { id: 'u-staff', email: 'staff@demo.mm' },
      { id: 'u-mech', email: 'mechanic@demo.mm' }, { id: 'u-cust', email: 'customer@demo.mm' }];
    T.users = users.map(u => ({ ...u, user_metadata: {} }));
    const shop = { id: 'shop-miba', slug: 'miba-yeik', name1: 'မိဘရိပ်', name2: 'Auto Service', address: 'အမှတ် ၁၂၊ ပြည်ထောင်စုလမ်း၊ မင်္ဂလာဒုံ၊ ရန်ကုန်', phone: '09 123 456 789',
      about: 'အင်ဂျင်ဝိုင်လဲခြင်းမှ ဘရိတ်၊ AC၊ ဘီးချိန်အထိ — ကျွမ်းကျင်ဆရာ ၃ ဦးနဲ့ ယုံကြည်စိတ်ချစွာ ပြင်ပေးပါတယ်။ ပြင်ပြီးတိုင်း ပြေစာနဲ့ နောက်တစ်ကြိမ် ဝိုင်လဲရမယ့်ရက်ကို မှတ်ပေးထားပါတယ်။',
      hours: 'တနင်္လာ – စနေ  ၈:၀၀ – ၆:၀၀ · တနင်္ဂနွေ ပိတ်', map_url: 'https://maps.google.com/?q=Mingaladon+Yangon', brand_bg: '#1d4fa3', brand_fg: '#e3121b',
      receipt_footer: 'ကျေးဇူးတင်ပါသည်။ နောက်လည်း လာခဲ့ပါဦး။', oil_km: 5000, oil_months: 3, is_public: true, plan: 'yearly',
      paid_until: '2099-12-31', monthly_fee: 0, booking_slots: '09:00,10:00,11:00,13:00,14:00,15:00,16:00', slot_capacity: 2, booking_days: 14, closed_days: '0', viber: '09 123 456 789', facebook: 'https://facebook.com/', created_at: new Date(+today - 120 * 864e5).toISOString() };
    T.shops.push(shop);
    const S = 'shop-miba';
    const staff = [
      { id: 'st1', user_id: 'u-owner', email: 'owner@demo.mm', name: 'ဦးမင်းထက်', role: 'owner', phone: '09 420 111 222' },
      { id: 'st2', user_id: 'u-manager', email: 'manager@demo.mm', name: 'မနှင်းဝေ', role: 'manager', phone: '09 795 330 118' },
      { id: 'st3', user_id: 'u-staff', email: 'staff@demo.mm', name: 'ကိုသက်ပိုင်', role: 'staff', phone: '09 254 887 100' },
      { id: 'st4', user_id: 'u-mech', email: 'mechanic@demo.mm', name: 'ဆရာကျော်', role: 'mechanic', phone: '09 450 662 731' },
      { id: 'st5', user_id: null, email: '', name: 'ဆရာဇော်', role: 'mechanic', phone: '09 785 004 219' },
      { id: 'st6', user_id: null, email: '', name: 'ကိုရဲ', role: 'mechanic', phone: '09 977 120 345' }];
    staff.forEach(s => T.shop_staff.push({ shop_id: S, active: true, created_at: shop.created_at, ...s }));
    const services = [
      ['sv1', 'အင်ဂျင်ဝိုင်လဲ (လက်ခ)', 15000, true, true, 'ဝိုင်ဟောင်းစစ်ထုတ်ပြီး Filter စစ်ပေး'], ['sv2', 'ဘရိတ်စစ်/ပြင်', 25000, false, true, 'Brake pad၊ disc နှင့် ဘရိတ်ဆီ စစ်ဆေး'],
      ['sv3', 'ဘီးချိန် (Alignment)', 20000, false, false, 'ကွန်ပျူတာ ဘီးချိန်စက်ဖြင့်'], ['sv4', 'AC ဂတ်စ်ဖြည့်', 35000, false, false, 'ယိုစိမ့်မှုစစ်ပြီး ဂတ်စ်ဖြည့်'],
      ['sv5', 'အင်ဂျင်စစ်ဆေး (Scan)', 10000, false, true, 'OBD Scanner ဖြင့် Error code ဖတ်'], ['sv6', 'ကားဆေး', 8000, false, false, 'အပြင်/အတွင်း'],
      ['sv7', 'ဘီးလဲ/ဖာ', 5000, false, false, ''], ['sv8', 'ဘက်ထရီ လဲ (လက်ခ)', 5000, false, false, '']];
    services.forEach(([id, name, price, oil, fav, description], i) => T.services.push({ id, shop_id: S, name, price, is_oil_change: oil, fav, public: true, active: true, sort: i + 1, description }));
    const cats = ['အင်ဂျင်ဝိုင်', 'Filter', 'ဘရိတ်', 'လျှပ်စစ်', 'အအေးခံ', 'ဘီး/တာယာ'].map((n, i) => ({ id: 'cat' + (i + 1), shop_id: S, name: n }));
    T.categories.push(...cats);
    const cid = n => cats.find(c => c.name === n).id;
    const parts = [
      ['p1', 'Engine Oil 5W-30 (4L)', 'အင်ဂျင်ဝိုင်', 52000, 68000, 14, 4, true], ['p2', 'Oil Filter (Toyota)', 'Filter', 6000, 9500, 3, 5, true],
      ['p3', 'Brake Pad အရှေ့', 'ဘရိတ်', 32000, 45000, 6, 2, false], ['p4', 'Air Filter', 'Filter', 11000, 18000, 2, 3, false],
      ['p5', 'Spark Plug', 'လျှပ်စစ်', 4500, 7500, 20, 8, false], ['p6', 'Coolant (1L)', 'အအေးခံ', 7500, 12000, 8, 3, false],
      ['p7', 'Battery 12V 45Ah', 'လျှပ်စစ်', 118000, 150000, 0, 1, false], ['p8', 'Engine Oil 10W-40 (4L)', 'အင်ဂျင်ဝိုင်', 41000, 55000, 9, 4, false],
      ['p9', 'Tyre Tube', 'ဘီး/တာယာ', 9000, 14000, 5, 2, false], ['p10', 'Brake Fluid DOT4', 'ဘရိတ်', 6500, 10000, 7, 2, false]];
    parts.forEach(([id, name, cat, cost, price, stock, min, fav]) => { T.parts.push({ id, shop_id: S, category_id: cid(cat), name, price, stock, min_stock: min, fav, active: true, created_at: shop.created_at }); T.part_costs.push({ part_id: id, shop_id: S, cost }) });
    const pmap = Object.fromEntries(parts.map(p => [p[0], { name: p[1], cost: p[3], price: p[4] }]));
    const smap = Object.fromEntries(services.map(s => [s[0], { name: s[1], price: s[2] }]));
    const names = ['ဒေါ်သန္တာ', 'ဦးကျော်ဇင်', 'ကိုအောင်မင်း', 'မမေသူ', 'ဦးဝင်းနိုင်', 'ကိုဇော်လင်း', 'မဖြူဖြူ', 'ဦးသိန်းဌေး', 'ကိုနေလင်း', 'ဒေါ်ခင်မာ', 'ကိုပြည့်ဖြိုး', 'မဆုမွန်', 'ဦးအေးကို', 'ကိုထက်အောင်'];
    const models = ['Toyota Probox', 'Honda Fit 2012', 'Toyota Mark II', 'Suzuki Swift', 'Toyota Hilux', 'Toyota Belta', 'Nissan AD Van', 'Toyota Wish', 'Honda Vezel', 'Toyota Corolla Axio', 'Suzuki Ertiga', 'Toyota Fielder', 'Mazda Demio', 'Toyota Alphard'];
    const plates = ['YGN 4C-7788', 'YGN 9K-3021', 'MDY 2A-1150', 'YGN 7F-5512', 'YGN 3B-9044', 'YGN 6H-2207', 'YGN 1D-6630', 'YGN 8E-4471', 'MDY 5G-0912', 'YGN 2J-7345', 'YGN 5A-3388', 'YGN 3K-1902', 'YGN 9B-5560', 'YGN 7C-0018'];
    names.forEach((n, i) => {
      T.customers.push({ id: 'c' + (i + 1), shop_id: S, name: n, phone: '09 ' + ri(250, 990) + ' ' + ri(100, 999) + ' ' + ri(100, 999), balance: 0, note: '', created_at: shop.created_at });
      T.vehicles.push({ id: 'v' + (i + 1), shop_id: S, customer_id: 'c' + (i + 1), plate: plates[i], plate_key: plateKey(plates[i]), model: models[i], last_km: ri(40, 190) * 1000 });
    });
    Object.assign(T.customers.find(c => c.id === 'c1'), { user_id: 'u-cust', email: 'customer@demo.mm' });
    T.vehicles.push({ id: 'v15', shop_id: S, customer_id: 'c2', plate: 'YGN 2M-4410', plate_key: 'YGN2M4410', model: 'Toyota Town Ace', last_km: 156000 });
    const mechs = ['st4', 'st5', 'st6'];
    const kinds = [
      () => [['svc', 'sv1'], ['part', pick(['p1', 'p8'])], ['part', 'p2']], () => [['svc', 'sv1'], ['part', 'p1'], ['part', 'p2'], ['part', 'p4']],
      () => [['svc', 'sv2'], ['part', 'p3']], () => [['svc', 'sv2'], ['part', 'p10']], () => [['svc', 'sv3']], () => [['svc', 'sv4']],
      () => [['svc', 'sv5']], () => [['svc', 'sv6']], () => [['svc', 'sv7'], ['part', 'p9']], () => [['svc', 'sv8'], ['part', 'p7']],
      () => [['svc', 'sv5'], ['part', 'p5', 4]], () => [['svc', 'sv3'], ['svc', 'sv6']]];
    let jobNo = 1000;
    const addJob = (v, created, status, lines, mech, extra = {}) => {
      const j = { id: uuid(), shop_id: S, job_no: ++jobNo, vehicle_id: v.id, customer_id: v.customer_id, km: v.last_km, note: '', status, mechanic_id: mech || null,
        subtotal: null, discount_amt: 0, promo_code: null, promo_amt: 0, total: null, cash_given: null, change_amt: null, cashier_id: null, created_at: created.toISOString(), paid_at: null, ...extra };
      T.jobs.push(j);
      lines.forEach(([k, ref, q]) => { const src = k === 'svc' ? smap[ref] : pmap[ref]; const id = nextId('job_lines');
        T.job_lines.push({ id, shop_id: S, job_id: j.id, kind: k, service_id: k === 'svc' ? ref : null, part_id: k === 'part' ? ref : null, name: src.name, price: src.price, qty: q || 1 });
        if (status === 'paid' && k === 'part') T.job_line_costs.push({ line_id: id, shop_id: S, cost: src.cost, created_at: j.paid_at }) });
      return j;
    };
    for (let d = 80; d >= 0; d--) {
      const day = new Date(today); day.setDate(day.getDate() - d); if (day.getDay() === 0 && d > 0) continue;
      const n = d === 0 ? 3 : ri(2, 7);
      for (let k = 0; k < n; k++) {
        const v = pick(T.vehicles); v.last_km += ri(300, 1800);
        const t = new Date(day); t.setHours(ri(8, 15), ri(0, 59), 0, 0); if (d === 0 && t > today) t.setTime(+today - ri(3, 6) * 3600e3);
        const paidAt = new Date(+t + ri(1, 3) * 3600e3); if (paidAt > today) paidAt.setTime(+today - 600e3);
        const j = addJob(v, t, 'paid', pick(kinds)(), pick(mechs), { paid_at: paidAt.toISOString(), cashier_id: pick(['st2', 'st3']) });
        T.job_line_costs.forEach(c => { if (!c.created_at) c.created_at = j.paid_at });
        const sub = T.job_lines.filter(l => l.job_id === j.id).reduce((a, l) => a + l.price * l.qty, 0);
        const disc = rnd() < .15 ? pick([2000, 3000, 5000]) : 0; const total = sub - disc;
        Object.assign(j, { subtotal: sub, discount_amt: disc, total });
        const m = rnd(); const pay = (method, amount) => T.job_payments.push({ id: nextId('job_payments'), shop_id: S, job_id: j.id, method, amount });
        if (m < .45) pay('Cash', total); else if (m < .75) pay('KBZPay', total); else if (m < .85) pay('WavePay', total); else if (m < .92) pay('AYA Pay', total);
        else { const c = Math.round(total * .4 / 1000) * 1000; pay('Cash', c); pay('KBZPay', total - c) }
      }
    }
    const v = id => T.vehicles.find(x => x.id === id);
    addJob(v('v2'), new Date(+today - .5 * 3600e3), 'waiting', [['svc', 'sv5']], null, { note: 'ACအေးမှုနည်း' });
    addJob(v('v1'), new Date(+today - 1.4 * 3600e3), 'working', [['svc', 'sv1'], ['part', 'p1'], ['part', 'p2']], 'st4', { note: 'ဝိုင်လဲရန်' });
    addJob(v('v3'), new Date(+today - 2.6 * 3600e3), 'done', [['svc', 'sv2'], ['part', 'p3']], 'st5', { note: 'ဘရိတ်အသံမြည်' });
    // ကြိုတင်ငွေ
    [['c1', 100000, 'KBZPay', 30], ['c6', 50000, 'Cash', 12], ['c11', 80000, 'WavePay', 3]].forEach(([c, amt, m, ago]) => {
      T.topups.push({ id: nextId('topups'), shop_id: S, customer_id: c, amount: amt, method: m, by_staff: 'st3', created_at: new Date(+today - ago * 864e5).toISOString() });
      T.customers.find(x => x.id === c).balance += amt });
    // promo
    T.promo_codes.push({ id: uuid(), shop_id: S, code: 'MIBA10', kind: 'pct', value: 10, starts_at: new Date(+today - 20 * 864e5).toISOString(), ends_at: new Date(+today + 10 * 864e5).toISOString(), uses: 7, active: true });
    T.promo_codes.push({ id: uuid(), shop_id: S, code: 'NEW5000', kind: 'ks', value: 5000, starts_at: new Date(+today - 60 * 864e5).toISOString(), ends_at: null, uses: 12, active: true });
    T.promo_codes.push({ id: uuid(), shop_id: S, code: 'THINGYAN', kind: 'pct', value: 15, starts_at: new Date(+today - 200 * 864e5).toISOString(), ends_at: new Date(+today - 190 * 864e5).toISOString(), uses: 31, active: true });
    // စရိတ်
    for (let m = 2; m >= 0; m--) {
      const b = new Date(today.getFullYear(), today.getMonth() - m, 1, 10);
      T.expenses.push({ id: uuid(), shop_id: S, spent_on: dayKey(b), category: 'ဆိုင်ခ', amount: 800000, note: 'လစဉ်ဆိုင်ခန်းခ', by_staff: 'st1', created_at: b.toISOString() });
      if (m > 0) T.expenses.push({ id: uuid(), shop_id: S, spent_on: dayKey(new Date(b.getFullYear(), b.getMonth(), 28)), category: 'လစာ', amount: 1650000, note: 'ဝန်ထမ်း ၅ ဦး', by_staff: 'st1', created_at: b.toISOString() });
      const el = new Date(b.getFullYear(), b.getMonth(), m === 0 ? Math.max(1, today.getDate() - 1) : 15, 12);
      T.expenses.push({ id: uuid(), shop_id: S, spent_on: dayKey(el), category: 'မီး/ရေ', amount: ri(95, 140) * 1000, note: 'မီတာခ + ဂျင်နရေတာဆီ', by_staff: 'st1', created_at: el.toISOString() });
    }
    // စာရင်းပိတ်
    for (let d = 7; d >= 1; d--) {
      const day = new Date(today); day.setDate(day.getDate() - d); if (day.getDay() === 0) continue;
      const k = dayKey(day);
      const cash = T.job_payments.filter(p => p.method === 'Cash' && (() => { const j = T.jobs.find(x => x.id === p.job_id); return j && dayKey(j.paid_at) === k })()).reduce((a, p) => a + p.amount, 0);
      const counted = cash + (d === 3 ? -2000 : 0);
      T.cash_closings.push({ id: uuid(), shop_id: S, close_date: k, expected: cash, counted, diff: counted - cash, by_staff: 'st2', created_at: new Date(day.setHours(19, 5)).toISOString() });
    }
    // Booking
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
    T.activity_logs.push({ id: nextId('activity_logs'), shop_id: S, by_staff: 'st2', message: 'ငွေစာရင်းပိတ်သည်', created_at: new Date(+today - 86400e3).toISOString() });
    T.activity_logs.push({ id: nextId('activity_logs'), shop_id: S, by_staff: 'st3', message: 'Job J-' + (jobNo - 2) + ' ဖွင့်သည်', created_at: new Date(+today - 2.6 * 3600e3).toISOString() });
    return { T, seq };
  }

  let DB;
  try { DB = JSON.parse(localStorage.getItem(KEY)) } catch (e) { DB = null }
  if (!DB || !DB.T || !DB.T.jobs) DB = seed();
  const T = () => DB.T;
  let saveT = null;
  const persist = () => { clearTimeout(saveT); saveT = setTimeout(() => { try { localStorage.setItem(KEY, JSON.stringify(DB)) } catch (e) { } }, 300) };
  const nextId = t => (DB.seq[t] = (DB.seq[t] || 0) + 1);

  /* ---------- auth ---------- */
  let session = null;
  try { const uid = localStorage.getItem(SKEY); const u = uid && T().users.find(x => x.id === uid); if (u) session = { user: u } } catch (e) { }
  const listeners = [];
  const uid = () => session && session.user.id;
  const email = () => session && session.user.email;
  const emit = (ev) => listeners.forEach(f => { try { f(ev, session) } catch (e) { } });

  /* ---------- access rules (Supabase RLS နှင့် တူအောင်) ---------- */
  const shopOf = id => T().shops.find(s => s.id === id);
  const myRole = shop => { const s = T().shop_staff.find(x => x.shop_id === shop && x.user_id === uid() && x.active); return s ? s.role : null };
  const isMember = shop => { const r = myRole(shop), h = shopOf(shop); return !!r && h && h.plan !== 'suspended' };
  const myCust = () => (T().customers.find(c => c.user_id && c.user_id === uid()) || {}).id || null;
  const theShop = () => (T().shops[0] || {}).id;
  const PERM = { manager: ['checkout', 'money', 'stockEdit', 'customers', 'reports', 'closing', 'promo', 'logs', 'settings'], staff: ['checkout', 'money', 'stockEdit', 'customers', 'closing'], mechanic: ['jobEdit'] };
  const can = (shop, a) => { const r = myRole(shop); if (!isMember(shop)) return false; return r === 'owner' || (PERM[r] || []).includes(a) };
  const isPA = () => T().platform_admins.some(p => p.user_id === uid());
  const myStaffId = shop => (T().shop_staff.find(x => x.shop_id === shop && x.user_id === uid()) || {}).id || null;
  function canRead(t, row) {
    if (t === 'users' || t === 'media') return false;
    if (t === 'chat_messages') return isMember(row.shop_id) || (!!myCust() && row.customer_id === myCust());
    if (t === 'customers' && row.user_id && row.user_id === uid()) return true;
    if (t === 'shops') return !!myRole(row.id) || isPA();
    if (t === 'platform_admins') return row.user_id === uid();
    if (t === 'shop_staff') return isMember(row.shop_id) || row.user_id === uid();
    const sh = row.shop_id;
    if (['job_payments', 'topups'].includes(t)) return can(sh, 'money');
    if (t === 'cash_closings') return can(sh, 'closing');
    if (t === 'stock_moves') return can(sh, 'stockEdit');
    if (t === 'activity_logs') return can(sh, 'logs');
    if (t === 'part_costs') return ['owner', 'manager'].includes(myRole(sh)) && isMember(sh);
    if (['job_line_costs', 'expenses'].includes(t)) return myRole(sh) === 'owner' && isMember(sh);
    return isMember(sh);
  }
  function canWrite(t, row, op) {
    const sh = t === 'shops' ? row.id : row.shop_id;
    if (t === 'shops') return op === 'update' && myRole(sh) === 'owner';
    if (t === 'chat_messages') return op === 'insert' ? ((isMember(sh) && row.sender === 'shop') || (row.sender === 'customer' && !!myCust() && row.customer_id === myCust() && !row.read_at)) : isMember(sh);
    if (t === 'bookings') return op !== 'insert' && isMember(sh);
    if (['banners', 'posts'].includes(t)) return can(sh, 'promo');
    if (t === 'shop_staff') return myRole(sh) === 'owner';
    if (t === 'services') return can(sh, 'settings');
    if (['categories', 'parts'].includes(t)) return can(sh, 'stockEdit');
    if (t === 'part_costs') return ['owner', 'manager'].includes(myRole(sh)) && isMember(sh);
    if (t === 'customers') return op === 'insert' ? isMember(sh) : can(sh, 'customers');
    if (['vehicles', 'jobs', 'job_lines', 'activity_logs'].includes(t)) return isMember(sh);
    if (t === 'promo_codes') return can(sh, 'promo');
    if (t === 'expenses') return myRole(sh) === 'owner' && isMember(sh);
    if (t === 'cash_closings') return can(sh, 'closing');
    return false;
  }
  const err = (message, code) => ({ data: null, error: { message, code: code || 'P0001' } });
  const clone = o => JSON.parse(JSON.stringify(o));

  function defaults(t, row) {
    const r = { ...row };
    if (IDENT[t]) r.id = nextId(t); else if (!r.id && !['part_costs', 'job_line_costs', 'platform_admins'].includes(t)) r.id = uuid();
    if (['shop_staff', 'parts', 'customers', 'jobs', 'expenses', 'cash_closings', 'activity_logs', 'stock_moves', 'topups', 'job_line_costs', 'chat_messages', 'banners', 'posts', 'bookings'].includes(t) && !r.created_at) r.created_at = now();
    if (t === 'chat_messages') Object.assign(r, { read_at: null, image_url: null, staff_id: null, ...r });
    if (t === 'banners') Object.assign(r, { active: true, sort: 0, ...r });
    if (t === 'posts') Object.assign(r, { published: true, ...r });
    if (t === 'jobs') {
      Object.assign(r, { status: r.status || 'waiting', discount_amt: 0, promo_amt: 0, paid_at: null, ...r });
      if (!r.job_no) r.job_no = Math.max(1000, ...T().jobs.filter(j => j.shop_id === r.shop_id).map(j => j.job_no)) + 1;
    }
    if (t === 'vehicles') r.plate_key = plateKey(r.plate);
    if (t === 'cash_closings') r.diff = r.counted - r.expected;
    if (t === 'parts') Object.assign(r, { stock: 0, min_stock: 3, fav: false, active: true, ...r });
    if (t === 'services') Object.assign(r, { fav: false, public: true, active: true, is_oil_change: false, sort: 99, ...r });
    if (t === 'customers') Object.assign(r, { balance: 0, ...r });
    if (t === 'promo_codes') Object.assign(r, { uses: 0, active: true, starts_at: now(), ...r });
    if (t === 'shop_staff') Object.assign(r, { active: true, ...r });
    return r;
  }
  const UNIQUE = { vehicles: ['shop_id', 'plate_key'], categories: ['shop_id', 'name'], promo_codes: ['shop_id', 'code'], cash_closings: ['shop_id', 'close_date'], part_costs: ['part_id'], shops: ['slug'] };
  function uniqueClash(t, row, selfRow) {
    const k = UNIQUE[t]; if (!k) return false;
    return T()[t].some(x => x !== selfRow && k.every(c => x[c] === row[c]));
  }
  function checkRow(t, r) {
    if (t === 'parts' && r.stock < 0) return 'new row for relation "parts" violates check constraint "parts_stock_check"';
    if (t === 'jobs' && r.status === 'paid') return 'new row violates row-level security policy for table "jobs"';
    return null;
  }

  /* ---------- query builder ---------- */
  class Q {
    constructor(t) { this.t = t; this.f = []; this.op = 'select'; this.cols = '*'; this.ord = []; this.rng = null; this.lim = null; this.one = null; this.ret = false }
    select(c) { if (this.op === 'select') this.cols = c || '*'; else { this.ret = true; this.retCols = c || '*' } return this }
    eq(c, v) { this.f.push(r => r[c] === v || (r[c] != null && v != null && String(r[c]) === String(v))); return this }
    neq(c, v) { this.f.push(r => r[c] !== v); return this }
    gt(c, v) { this.f.push(r => r[c] != null && r[c] > v); return this }
    gte(c, v) { this.f.push(r => r[c] != null && r[c] >= v); return this }
    lt(c, v) { this.f.push(r => r[c] != null && r[c] < v); return this }
    lte(c, v) { this.f.push(r => r[c] != null && r[c] <= v); return this }
    in(c, a) { const s = new Set(a.map(String)); this.f.push(r => s.has(String(r[c]))); return this }
    is(c, v) { this.f.push(r => (r[c] ?? null) === v); return this }
    order(c, o) { this.ord.push([c, !(o && o.ascending === false)]); return this }
    range(a, b) { this.rng = [a, b]; return this }
    limit(n) { this.lim = n; return this }
    single() { this.one = 'single'; return this }
    maybeSingle() { this.one = 'maybe'; return this }
    insert(v) { this.op = 'insert'; this.val = v; return this }
    update(v) { this.op = 'update'; this.val = v; return this }
    upsert(v, o) { this.op = 'upsert'; this.val = v; this.conflict = o && o.onConflict; return this }
    delete() { this.op = 'delete'; return this }
    then(res, rej) { return new Promise(r => setTimeout(r, 15)).then(() => this.exec()).then(res, rej) }
    rows() { return T()[this.t].filter(r => this.f.every(fn => fn(r))) }
    shape(list, cols) {
      const embeds = [...String(cols).matchAll(/(\w+)\(\*\)/g)].map(m => m[1]);
      const fk = this.t.replace(/s$/, '') + '_id';
      return list.map(r => { const o = clone(r); embeds.forEach(e => { o[e] = (T()[e] || []).filter(c => c[fk] === r.id && canRead(e, c)).map(clone) }); return o });
    }
    finish(list, cols) {
      let out = this.shape(list, cols || '*');
      if (this.one) { if (out.length > 1 && this.one === 'single') return err('JSON object requested, multiple (or no) rows returned', 'PGRST116'); if (!out.length) return this.one === 'single' ? err('JSON object requested, multiple (or no) rows returned', 'PGRST116') : { data: null, error: null }; return { data: out[0], error: null } }
      return { data: out, error: null };
    }
    exec() {
      const t = this.t;
      if (!T()[t]) return err('relation "' + t + '" does not exist');
      if (this.op === 'select') {
        let list = this.rows().filter(r => canRead(t, r));
        if (this.ord.length) list = list.slice().sort((a, b) => { for (const [c, asc] of this.ord) { const x = a[c], y = b[c]; if (x === y) continue; if (x == null) return 1; if (y == null) return -1; return (x < y ? -1 : 1) * (asc ? 1 : -1) } return 0 });
        if (this.rng) list = list.slice(this.rng[0], this.rng[1] + 1);
        if (this.lim != null) list = list.slice(0, this.lim);
        return this.finish(list, this.cols);
      }
      if (this.op === 'insert' || this.op === 'upsert') {
        const vals = Array.isArray(this.val) ? this.val : [this.val]; const out = [];
        for (const v of vals) {
          if (this.op === 'upsert') {
            const keys = (this.conflict || (UNIQUE[t] || ['id']).join(',')).split(',');
            const row0 = defaults(t, v);
            const ex = T()[t].find(x => keys.every(k => x[k] === row0[k]));
            if (ex) { if (!canWrite(t, { ...ex, ...v }, 'update')) return err('new row violates row-level security policy for table "' + t + '"', '42501'); Object.assign(ex, v); if (t === 'cash_closings') ex.diff = ex.counted - ex.expected; out.push(ex); continue }
          }
          const row = defaults(t, v);
          if (!canWrite(t, row, 'insert')) return err('new row violates row-level security policy for table "' + t + '"', '42501');
          if (t === 'parts' && row.stock !== 0) return err('new row violates row-level security policy for table "parts"', '42501');
          const c = checkRow(t, row); if (c) return err(c, '23514');
          if (uniqueClash(t, row)) return err('duplicate key value violates unique constraint', '23505');
          T()[t].push(row); out.push(row);
        }
        persist();
        return this.ret ? this.finish(out, this.retCols) : { data: null, error: null };
      }
      if (this.op === 'update') {
        const list = this.rows().filter(r => canRead(t, r)); const out = [];
        for (const r of list) {
          const nr = { ...r, ...this.val };
          if (t === 'vehicles') nr.plate_key = plateKey(nr.plate);
          if (!canWrite(t, nr, 'update')) return err('new row violates row-level security policy for table "' + t + '"', '42501');
          if (t === 'jobs' && ['paid', 'cancelled'].includes(r.status)) continue;
          if (t === 'jobs' && nr.status === 'cancelled' && !can(r.shop_id, 'checkout')) return err('new row violates row-level security policy for table "jobs"', '42501');
          const c = checkRow(t, nr); if (c) return err(c, '23514');
          if (uniqueClash(t, nr, r)) return err('duplicate key value violates unique constraint', '23505');
          Object.assign(r, nr); out.push(r);
        }
        persist();
        return this.ret ? this.finish(out, this.retCols) : { data: null, error: null };
      }
      if (this.op === 'delete') {
        const list = this.rows().filter(r => canRead(t, r) && canWrite(t, r, 'delete'));
        if (t === 'job_lines') { const bad = list.find(l => { const j = T().jobs.find(x => x.id === l.job_id); return !j || ['paid', 'cancelled'].includes(j.status) }); if (bad) return { data: null, error: null } }
        T()[t] = T()[t].filter(r => !list.includes(r));
        if (t === 'job_lines') T().job_line_costs = T().job_line_costs.filter(c => !list.some(l => l.id === c.line_id));
        persist(); return { data: null, error: null };
      }
    }
  }

  /* ---------- RPC ---------- */
  const log = (shop, msg) => T().activity_logs.push({ id: nextId('activity_logs'), shop_id: shop, by_staff: myStaffId(shop), message: msg, created_at: now() });
  const RPC = {
    my_shops() {
      return T().shop_staff.filter(s => s.user_id === uid() && s.active).map(s => { const h = shopOf(s.shop_id);
        return { shop_id: h.id, staff_id: s.id, role: s.role, name1: h.name1, name2: h.name2, slug: h.slug, plan: h.plan, paid_until: h.paid_until, monthly_fee: h.monthly_fee, active: h.plan !== 'suspended' } });
    },
    claim_staff_invite() {
      let n = 0; const e = (email() || '').toLowerCase(); if (!e) return 0;
      T().shop_staff.forEach(s => { if (!s.user_id && s.active && (s.email || '').toLowerCase() === e && !T().shop_staff.some(x => x.shop_id === s.shop_id && x.user_id === uid())) { s.user_id = uid(); n++ } });
      return n;
    },
    create_shop({ p_name1, p_name2, p_owner_name, p_phone }) {
      if (!uid()) throw 'Login ဝင်ပါ'; if (T().shops.length) throw 'ဆိုင် ရှိပြီးသားပါ — ဆိုင်ပိုင်ရှင်ကို ဝန်ထမ်းအဖြစ် Email နဲ့ ထည့်ခိုင်းပါ';
      const id = uuid();
      T().shops.push({ id, slug: 'shop-' + id.slice(0, 6), name1: p_name1.trim(), name2: (p_name2 || '').trim() || 'Auto Service', address: '', phone: p_phone, about: '', hours: 'တနင်္လာ – စနေ  ၈:၀၀ – ၆:၀၀', map_url: '',
        brand_bg: '#1d4fa3', brand_fg: '#e3121b', receipt_footer: 'ကျေးဇူးတင်ပါသည်။ နောက်လည်း လာခဲ့ပါဦး။', oil_km: 5000, oil_months: 3, is_public: true, plan: 'trial',
        paid_until: dayKey(new Date(Date.now() + 14 * 864e5)), monthly_fee: 35000, created_at: now() });
      T().shop_staff.push({ id: uuid(), shop_id: id, user_id: uid(), email: email(), name: p_owner_name || 'Owner', phone: p_phone, role: 'owner', active: true, created_at: now() });
      [['အင်ဂျင်ဝိုင်လဲ (လက်ခ)', 15000, true, true], ['ဘရိတ်စစ်/ပြင်', 25000, false, true], ['ဘီးချိန် (Alignment)', 20000, false, false], ['AC ဂတ်စ်ဖြည့်', 35000, false, false], ['အင်ဂျင်စစ်ဆေး (Scan)', 10000, false, true], ['ကားဆေး', 8000, false, false]]
        .forEach(([name, price, oil, fav], i) => T().services.push({ id: uuid(), shop_id: id, name, price, is_oil_change: oil, fav, public: true, active: true, sort: i + 1, description: '' }));
      ['အင်ဂျင်ဝိုင်', 'Filter', 'ဘရိတ်', 'လျှပ်စစ်', 'အအေးခံ', 'ဘီး/တာယာ'].forEach(n => T().categories.push({ id: uuid(), shop_id: id, name: n }));
      log(id, 'ဆိုင်အသစ် ဖွင့်သည်');
      return id;
    },
    checkout_job({ p_job, p_disc_type, p_disc_val, p_promo, p_payments, p_cash_given }) {
      const j = T().jobs.find(x => x.id === p_job); if (!j) throw 'Job မတွေ့ပါ';
      if (!can(j.shop_id, 'checkout')) throw 'ငွေရှင်းခွင့် မရှိပါ';
      if (['paid', 'cancelled'].includes(j.status)) throw 'ဒီ Job ကို ငွေရှင်းလို့ မရတော့ပါ';
      const lines = T().job_lines.filter(l => l.job_id === j.id);
      const sub = lines.reduce((a, l) => a + l.price * l.qty, 0); if (!sub) throw 'ပစ္စည်း/လက်ခ မထည့်ရသေးပါ';
      let disc = 0; if (p_disc_type === 'pct') disc = Math.round(sub * Math.min(Math.max(+p_disc_val || 0, 0), 100) / 100); else if (p_disc_type === 'ks') disc = Math.min(Math.max(+p_disc_val || 0, 0), sub);
      let promo = 0, pr = null;
      if (String(p_promo || '').trim()) {
        pr = T().promo_codes.find(p => p.shop_id === j.shop_id && p.code === String(p_promo).trim().toUpperCase());
        const n = now(); if (!pr || !pr.active || pr.starts_at > n || (pr.ends_at && pr.ends_at < n)) throw 'Promo Code သုံးလို့ မရပါ';
        promo = pr.kind === 'pct' ? Math.round((sub - disc) * pr.value / 100) : Math.min(pr.value, sub - disc);
      }
      const total = Math.max(sub - disc - promo, 0);
      const pays = (typeof p_payments === 'string' ? JSON.parse(p_payments) : p_payments) || [];
      const paid = pays.reduce((a, p) => a + (+p.amount || 0), 0), pre = pays.filter(p => p.method === 'Prepaid').reduce((a, p) => a + p.amount, 0), cash = pays.filter(p => p.method === 'Cash').reduce((a, p) => a + p.amount, 0);
      if (paid !== total) throw `ပေးချေငွေ (${paid}) နှင့် စုစုပေါင်း (${total}) မကိုက်ပါ`;
      if (p_cash_given != null && p_cash_given < cash) throw 'ဖောက်သည်ပေးငွေ မလုံလောက်ပါ';
      const c = T().customers.find(x => x.id === j.customer_id);
      if (pre > 0 && (!c || c.balance < pre)) throw 'ကြိုတင်ငွေ မလုံလောက်ပါ';
      const need = {}; lines.filter(l => l.kind === 'part' && l.part_id).forEach(l => need[l.part_id] = (need[l.part_id] || 0) + l.qty);
      for (const [pid, q] of Object.entries(need)) { const p = T().parts.find(x => x.id === pid); if (!p || p.stock < q) throw 'Stock မလုံလောက်ပါ (' + (p ? p.name : '') + ')' }
      if (pr) pr.uses++;
      if (pre > 0) c.balance -= pre;
      const st = myStaffId(j.shop_id);
      for (const [pid, q] of Object.entries(need)) { T().parts.find(x => x.id === pid).stock -= q; T().stock_moves.push({ id: nextId('stock_moves'), shop_id: j.shop_id, part_id: pid, qty: -q, note: 'J-' + j.job_no + ' ရောင်း', job_id: j.id, by_staff: st, created_at: now() }) }
      lines.filter(l => l.kind === 'part').forEach(l => { const pc = T().part_costs.find(x => x.part_id === l.part_id); T().job_line_costs = T().job_line_costs.filter(x => x.line_id !== l.id); T().job_line_costs.push({ line_id: l.id, shop_id: j.shop_id, cost: pc ? pc.cost : 0, created_at: now() }) });
      pays.filter(p => p.amount > 0).forEach(p => T().job_payments.push({ id: nextId('job_payments'), shop_id: j.shop_id, job_id: j.id, method: p.method, amount: p.amount }));
      Object.assign(j, { status: 'paid', subtotal: sub, discount_amt: disc, promo_code: pr ? pr.code : null, promo_amt: promo, total, cash_given: p_cash_given ?? null, change_amt: p_cash_given == null ? null : p_cash_given - cash, cashier_id: st, paid_at: now() });
      const v = T().vehicles.find(x => x.id === j.vehicle_id); if (v && j.km) v.last_km = j.km;
      log(j.shop_id, 'J-' + j.job_no + ' ငွေရှင်းသည် ' + total + ' Ks');
      return clone(j);
    },
    adjust_stock({ p_part, p_delta, p_note }) {
      const p = T().parts.find(x => x.id === p_part); if (!p || !can(p.shop_id, 'stockEdit')) throw 'ခွင့်မရှိပါ';
      if (!p_delta) return p.stock; if (p.stock + p_delta < 0) throw 'Stock 0 အောက် မရောက်ရပါ';
      p.stock += p_delta; T().stock_moves.push({ id: nextId('stock_moves'), shop_id: p.shop_id, part_id: p.id, qty: p_delta, note: p_note || (p_delta > 0 ? 'Stock ဝင်' : 'ချိန်ညှိ'), job_id: null, by_staff: myStaffId(p.shop_id), created_at: now() });
      return p.stock;
    },
    topup_customer({ p_customer, p_amount, p_method }) {
      const c = T().customers.find(x => x.id === p_customer); if (!c || !can(c.shop_id, 'checkout')) throw 'ခွင့်မရှိပါ';
      if (!(p_amount > 0)) throw 'ပမာဏ မမှန်ပါ';
      c.balance += p_amount; T().topups.push({ id: nextId('topups'), shop_id: c.shop_id, customer_id: c.id, amount: p_amount, method: p_method, by_staff: myStaffId(c.shop_id), created_at: now() });
      log(c.shop_id, c.name + ' ကြိုတင်ငွေ ' + p_amount + ' Ks ဖြည့်သည် (' + p_method + ')');
      return c.balance;
    },
    oil_due({ p_shop, p_within_days }) {
      if (!can(p_shop, 'customers')) return [];
      const h = shopOf(p_shop); const oil = new Set(T().services.filter(s => s.shop_id === p_shop && s.is_oil_change).map(s => s.id));
      const last = {};
      T().jobs.filter(j => j.shop_id === p_shop && j.status === 'paid' && j.vehicle_id).forEach(j => {
        if (!T().job_lines.some(l => l.job_id === j.id && oil.has(l.service_id))) return;
        if (!last[j.vehicle_id] || j.paid_at > last[j.vehicle_id].paid_at) last[j.vehicle_id] = j });
      const lim = dayKey(new Date(Date.now() + (p_within_days ?? 14) * 864e5));
      return Object.values(last).map(j => { const v = T().vehicles.find(x => x.id === j.vehicle_id), c = T().customers.find(x => x.id === v.customer_id) || {};
        return { vehicle_id: v.id, plate: v.plate, model: v.model, customer_id: c.id || null, customer_name: c.name || '', phone: c.phone || '', last_change: j.paid_at, due_date: dayKey(addMonths(j.paid_at, h.oil_months)), due_km: (j.km || 0) + h.oil_km } })
        .filter(x => x.due_date <= lim && !T().jobs.some(o => o.vehicle_id === x.vehicle_id && ['waiting', 'working', 'done'].includes(o.status))).sort((a, b) => a.due_date < b.due_date ? -1 : 1);
    },
    daily_totals({ p_shop, p_day }) {
      if (!can(p_shop, 'closing')) return []; const d = p_day || dayKey(new Date()); const o = {};
      T().jobs.filter(j => j.shop_id === p_shop && j.status === 'paid' && dayKey(j.paid_at) === d).forEach(j => T().job_payments.filter(p => p.job_id === j.id).forEach(p => o[p.method] = (o[p.method] || 0) + p.amount));
      T().topups.filter(t => t.shop_id === p_shop && dayKey(t.created_at) === d).forEach(t => { const k = t.method + ' (ကြိုတင်ငွေဖြည့်)'; o[k] = (o[k] || 0) + t.amount });
      return Object.entries(o).map(([method, amount]) => ({ method, amount }));
    },
    customer_stats({ p_shop }) {
      if (!can(p_shop, 'customers')) return []; const o = {};
      T().jobs.filter(j => j.shop_id === p_shop && j.status === 'paid' && j.customer_id).forEach(j => { const x = o[j.customer_id] = o[j.customer_id] || { customer_id: j.customer_id, visits: 0, spent: 0, last_visit: null }; x.visits++; x.spent += j.total || 0; if (!x.last_visit || j.paid_at > x.last_visit) x.last_visit = j.paid_at });
      return Object.values(o);
    },
    public_shop({ p_slug }) {
      const h = T().shops.find(s => s.slug === String(p_slug || '').toLowerCase() && s.is_public && s.plan !== 'suspended'); if (!h) return null;
      return { name1: h.name1, name2: h.name2, address: h.address, phone: h.phone, about: h.about, hours: h.hours, map_url: h.map_url, brand_bg: h.brand_bg, brand_fg: h.brand_fg, oil_km: h.oil_km, oil_months: h.oil_months,
        services: T().services.filter(s => s.shop_id === h.id && s.active && s.public).sort((a, b) => a.sort - b.sort).map(s => ({ name: s.name, price: s.price, description: s.description })) };
    },
    vehicle_history({ p_slug, p_plate, p_phone4 }) {
      if (!/^\d{4}$/.test(p_phone4 || '')) return null;
      const h = T().shops.find(s => s.slug === String(p_slug || '').toLowerCase() && s.is_public && s.plan !== 'suspended'); if (!h) return null;
      const v = T().vehicles.find(x => x.shop_id === h.id && x.plate_key === plateKey(p_plate)); if (!v) return null;
      const c = T().customers.find(x => x.id === v.customer_id); if (!c || String(c.phone || '').replace(/\D/g, '').slice(-4) !== p_phone4) return null;
      const oil = new Set(T().services.filter(s => s.shop_id === h.id && s.is_oil_change).map(s => s.id));
      const js = T().jobs.filter(j => j.vehicle_id === v.id && j.status === 'paid').sort((a, b) => a.paid_at < b.paid_at ? 1 : -1);
      const lo = js.find(j => T().job_lines.some(l => l.job_id === j.id && oil.has(l.service_id)));
      return { plate: v.plate, model: v.model, last_km: v.last_km, oil_due_date: lo ? dayKey(addMonths(lo.paid_at, h.oil_months)) : null, oil_due_km: lo && lo.km ? lo.km + h.oil_km : null,
        visits: js.slice(0, 30).map(j => ({ date: j.paid_at, km: j.km, total: j.total, items: T().job_lines.filter(l => l.job_id === j.id).map(l => l.name + (l.qty > 1 ? ' ×' + l.qty : '')) })) };
    },
    site_info() {
      const h = T().shops[0]; if (!h || !h.is_public) return null;
      return { name1: h.name1, name2: h.name2, address: h.address, phone: h.phone, viber: h.viber, facebook: h.facebook, about: h.about, hours: h.hours, map_url: h.map_url, brand_bg: h.brand_bg, brand_fg: h.brand_fg, oil_km: h.oil_km, oil_months: h.oil_months,
        booking: { slots: h.booking_slots, capacity: h.slot_capacity, days: h.booking_days, closed: h.closed_days },
        services: T().services.filter(s => s.shop_id === h.id && s.active && s.public).sort((a, b) => a.sort - b.sort).map(s => ({ id: s.id, name: s.name, price: s.price, description: s.description })),
        banners: T().banners.filter(b => b.shop_id === h.id && b.active).sort((a, b) => a.sort - b.sort).map(b => ({ title: b.title, subtitle: b.subtitle, image_url: b.image_url, link: b.link })),
        posts: T().posts.filter(p => p.shop_id === h.id && p.published).sort((a, b) => a.created_at < b.created_at ? 1 : -1).slice(0, 20).map(p => ({ id: p.id, title: p.title, body: p.body, image_url: p.image_url, created_at: p.created_at })) };
    },
    booked_counts({ p_from, p_to }) {
      const o = {}; T().bookings.filter(b => b.shop_id === theShop() && b.booking_date >= p_from && b.booking_date <= p_to && ['pending', 'confirmed'].includes(b.status)).forEach(b => { const k = b.booking_date + '|' + b.time_slot; o[k] = (o[k] || 0) + 1 });
      return Object.entries(o).map(([k, n]) => { const [booking_date, time_slot] = k.split('|'); return { booking_date, time_slot, n } });
    },
    create_booking({ p_name, p_phone, p_plate, p_model, p_services, p_date, p_slot, p_note }) {
      const h = T().shops[0]; if (!h || !h.is_public) throw 'Booking လက်မခံသေးပါ';
      if (!String(p_name || '').trim() || String(p_phone || '').replace(/\D/g, '').length < 7) throw 'အမည်နဲ့ ဖုန်းနံပါတ် ထည့်ပါ';
      const t0 = dayKey(new Date()), tMax = dayKey(new Date(Date.now() + h.booking_days * 864e5));
      if (p_date < t0 || p_date > tMax) throw 'ဒီရက်ကို Booking လုပ်လို့ မရပါ';
      if (String(h.closed_days || '').split(',').map(x => x.trim()).includes(String(new Date(p_date + 'T12:00:00').getDay()))) throw 'ဒီနေ့ ဆိုင်ပိတ်ပါတယ်';
      if (!String(h.booking_slots).replace(/ /g, '').split(',').includes(p_slot)) throw 'အချိန် မမှန်ပါ';
      const n = T().bookings.filter(b => b.booking_date === p_date && b.time_slot === p_slot && ['pending', 'confirmed'].includes(b.status)).length;
      if (n >= h.slot_capacity) throw 'ဒီအချိန် ပြည့်သွားပါပြီ — တခြားအချိန် ရွေးပါ';
      const no = Math.max(100, ...T().bookings.map(b => b.booking_no || 0)) + 1;
      const b = { id: uuid(), shop_id: h.id, booking_no: no, customer_id: myCust(), name: p_name.trim(), phone: p_phone.trim(), plate: (p_plate || '').trim().toUpperCase() || null, model: (p_model || '').trim() || null, services: p_services, booking_date: p_date, time_slot: p_slot, note: p_note || '', status: 'pending', job_id: null, shop_note: '', created_at: now() };
      T().bookings.push(b); return { id: b.id, no, date: p_date, slot: p_slot };
    },
    customer_register({ p_name, p_phone, p_plate }) {
      if (!uid()) throw 'Login ဝင်ပါ'; const ex = myCust(); if (ex) return ex;
      const dg = String(p_phone || '').replace(/\D/g, ''); if (dg.length < 7) throw 'ဖုန်းနံပါတ် ထည့်ပါ';
      let c = null;
      if (String(p_plate || '').trim()) { const pk = plateKey(p_plate); c = T().customers.find(x => !x.user_id && String(x.phone || '').replace(/\D/g, '') === dg && T().vehicles.some(v => v.customer_id === x.id && v.plate_key === pk)) }
      if (c) { c.user_id = uid(); c.email = email() }
      else { c = { id: uuid(), shop_id: theShop(), name: String(p_name || '').trim() || 'ဖောက်သည်', phone: p_phone.trim(), balance: 0, note: '', user_id: uid(), email: email(), created_at: now() }; T().customers.push(c);
        if (String(p_plate || '').trim() && !T().vehicles.some(v => v.plate_key === plateKey(p_plate))) T().vehicles.push({ id: uuid(), shop_id: theShop(), customer_id: c.id, plate: p_plate.trim().toUpperCase(), plate_key: plateKey(p_plate), model: '', last_km: null }) }
      T().activity_logs.push({ id: nextId('activity_logs'), shop_id: theShop(), by_staff: null, message: 'ဖောက်သည် Account ဖွင့်သည်: ' + (p_name || ''), created_at: now() });
      return c.id;
    },
    my_profile() {
      const c = T().customers.find(x => x.user_id && x.user_id === uid()); if (!c) return null; const h = shopOf(c.shop_id);
      const oil = new Set(T().services.filter(s => s.is_oil_change).map(s => s.id));
      const paid = T().jobs.filter(j => j.customer_id === c.id && j.status === 'paid').sort((a, b) => a.paid_at < b.paid_at ? 1 : -1);
      return { id: c.id, name: c.name, phone: c.phone, balance: c.balance,
        vehicles: T().vehicles.filter(v => v.customer_id === c.id).map(v => { const lo = T().jobs.filter(j => j.vehicle_id === v.id && j.status === 'paid' && T().job_lines.some(l => l.job_id === j.id && oil.has(l.service_id))).sort((a, b) => a.paid_at < b.paid_at ? 1 : -1)[0];
          return { plate: v.plate, model: v.model, last_km: v.last_km, oil_due_date: lo ? dayKey(addMonths(lo.paid_at, h.oil_months)) : null, oil_due_km: lo && lo.km ? lo.km + h.oil_km : null } }),
        jobs: paid.slice(0, 40).map(j => ({ no: j.job_no, date: j.paid_at, km: j.km, total: j.total, plate: (T().vehicles.find(v => v.id === j.vehicle_id) || {}).plate, items: T().job_lines.filter(l => l.job_id === j.id).map(l => l.name + (l.qty > 1 ? ' ×' + l.qty : '')) })),
        bookings: T().bookings.filter(b => b.customer_id === c.id).sort((a, b) => (a.booking_date + a.time_slot) < (b.booking_date + b.time_slot) ? 1 : -1).slice(0, 20).map(b => ({ id: b.id, booking_no: b.booking_no, booking_date: b.booking_date, time_slot: b.time_slot, plate: b.plate, services: b.services, status: b.status, shop_note: b.shop_note })) };
    },
    cancel_my_booking({ p_id }) { const b = T().bookings.find(x => x.id === p_id && x.customer_id === myCust() && ['pending', 'confirmed'].includes(x.status)); if (!b) return false; b.status = 'cancelled'; return true },
    chat_threads({ p_shop }) {
      if (!isMember(p_shop)) return [];
      const by = {}; T().chat_messages.filter(m => m.shop_id === p_shop).forEach(m => { const x = by[m.customer_id]; if (!x || m.created_at > x.created_at) by[m.customer_id] = m });
      return Object.values(by).map(m => { const c = T().customers.find(x => x.id === m.customer_id) || {};
        return { customer_id: m.customer_id, name: c.name, phone: c.phone, last_body: m.body || '📷 ပုံ', last_at: m.created_at, last_sender: m.sender, unread: T().chat_messages.filter(u => u.customer_id === m.customer_id && u.sender === 'customer' && !u.read_at).length } })
        .sort((a, b) => a.last_at < b.last_at ? 1 : -1);
    },
    platform_shops() {
      if (!isPA()) return [];
      const since = new Date(Date.now() - 30 * 864e5).toISOString();
      return T().shops.map(h => { const o = T().shop_staff.find(s => s.shop_id === h.id && s.role === 'owner') || {};
        return { id: h.id, slug: h.slug, name1: h.name1, name2: h.name2, owner_name: o.name, owner_phone: o.phone || h.phone, owner_email: o.email, plan: h.plan, paid_until: h.paid_until, monthly_fee: h.monthly_fee, created_at: h.created_at,
          staff_count: T().shop_staff.filter(s => s.shop_id === h.id && s.active).length, jobs_30d: T().jobs.filter(j => j.shop_id === h.id && j.created_at > since).length } })
        .sort((a, b) => a.paid_until < b.paid_until ? -1 : 1);
    },
    platform_extend({ p_shop, p_months }) {
      if (!isPA()) throw 'ခွင့်မရှိပါ'; const h = shopOf(p_shop); const base = h.paid_until > dayKey(new Date()) ? h.paid_until : dayKey(new Date());
      h.paid_until = dayKey(addMonths(base + 'T12:00:00', p_months)); h.plan = p_months >= 12 ? 'yearly' : 'monthly'; return h.paid_until;
    },
    platform_set_suspended({ p_shop, p_suspended }) {
      if (!isPA()) throw 'ခွင့်မရှိပါ'; const h = shopOf(p_shop);
      h.plan = p_suspended ? 'suspended' : (h.paid_until > dayKey(new Date(Date.now() + 20 * 864e5)) ? 'monthly' : 'trial'); return h.plan;
    }
  };

  function createClient() {
    return {
      demo: true,
      from: t => new Q(t),
      async rpc(name, args) {
        await new Promise(r => setTimeout(r, 20));
        if (!RPC[name]) return err('function ' + name + ' does not exist');
        try { const d = RPC[name](args || {}); persist(); return { data: clone(d === undefined ? null : d), error: null } }
        catch (e) { return err(typeof e === 'string' ? e : (e && e.message) || 'error') }
      },
      channel() { const c = { on() { return c }, subscribe() { return c } }; return c },
      storage: { from() { return {
        async upload(path, file) { if (!uid()) return err('Login ဝင်ပါ'); const url = await new Promise((res, rej) => { const r = new FileReader(); r.onload = () => res(r.result); r.onerror = rej; r.readAsDataURL(file) });
          T().media.push({ path, url }); persist(); return { data: { path }, error: null } },
        getPublicUrl(path) { const m = T().media.find(x => x.path === path); return { data: { publicUrl: m ? m.url : '' } } } } } },
      removeChannel() { },
      auth: {
        async getSession() { return { data: { session }, error: null } },
        async getUser() { return { data: { user: session && session.user }, error: null } },
        onAuthStateChange(fn) { listeners.push(fn); return { data: { subscription: { unsubscribe() { } } } } },
        async signInWithPassword({ email: e }) {
          const u = T().users.find(x => x.email.toLowerCase() === String(e || '').trim().toLowerCase());
          if (!u) return err('Invalid login credentials');
          session = { user: u }; try { localStorage.setItem(SKEY, u.id) } catch (x) { }
          emit('SIGNED_IN'); return { data: { session, user: u }, error: null };
        },
        async signUp({ email: e, password, options }) {
          e = String(e || '').trim().toLowerCase(); if (!/^\S+@\S+\.\S+$/.test(e)) return err('Unable to validate email address: invalid format');
          if ((password || '').length < 6) return err('Password should be at least 6 characters.');
          if (T().users.some(x => x.email === e)) return err('User already registered');
          const u = { id: 'u-' + uuid().slice(0, 8), email: e, user_metadata: (options && options.data) || {} };
          T().users.push(u); session = { user: u }; try { localStorage.setItem(SKEY, u.id) } catch (x) { } persist();
          emit('SIGNED_IN'); return { data: { session, user: u }, error: null };
        },
        async signOut() { session = null; try { localStorage.removeItem(SKEY) } catch (x) { } emit('SIGNED_OUT'); return { error: null } },
        async updateUser() { return { data: { user: session && session.user }, error: null } },
        async resetPasswordForEmail() { return { data: {}, error: null } }
      }
    };
  }
  function reset() { DB = seed(); session = null; try { localStorage.removeItem(KEY); localStorage.removeItem(SKEY) } catch (e) { } }
  window.GPDemo = { createClient, reset, accounts: [
    { email: 'owner@demo.mm', name: 'ဦးမင်းထက်', role: 'Owner' }, { email: 'manager@demo.mm', name: 'မနှင်းဝေ', role: 'Manager' },
    { email: 'staff@demo.mm', name: 'ကိုသက်ပိုင်', role: 'Staff' }, { email: 'mechanic@demo.mm', name: 'ဆရာကျော်', role: 'မက္ကင်းနစ်' },
    ],
    customer: { email: 'customer@demo.mm', name: 'ဒေါ်သန္တာ' },
    hint: { slug: 'miba-yeik', plate: 'YGN 4C-7788', phone4: () => { const c = T().customers.find(x => x.id === 'c1'); return c ? c.phone.replace(/\D/g, '').slice(-4) : '' } } };
})();
