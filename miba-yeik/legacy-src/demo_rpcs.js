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
