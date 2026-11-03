# မိဘရိပ် Auto Service — Website + Admin

Garage POS ကနေ ခွဲထွက်ထားတဲ့ မိဘရိပ် ဆိုင်တစ်ဆိုင်တည်းအတွက် Website ပါ (Suwati ပုံစံ — ဖောက်သည် Website + Admin)။

## ဖိုင်များ

| ဖိုင် | ဘာလဲ |
|---|---|
| `index.html` | **ဖောက်သည် Website** — Banner၊ ဝန်ဆောင်မှုဈေးနှုန်း၊ Online Booking၊ သတင်း/Promotion၊ ဖောက်သည် Account (ကားများ၊ ဝိုင်လဲရက်၊ ပြင်ဆင်မှုမှတ်တမ်း၊ Booking)၊ ဆိုင်နဲ့ Chat |
| `admin.html` | **ဆိုင် Admin** — Job card၊ ငွေရှင်း၊ Booking စီမံ၊ Messages (Chat)၊ Website (Banner/Post/Booking setting)၊ Stock၊ ဖောက်သည်၊ Report၊ အမြတ်၊ ဝန်ထမ်း၊ Backup |
| `config.js` | Supabase URL နဲ့ anon key — **ဒီဖိုင်ကိုပဲ ပြင်ရပါမယ်** |
| `demo-backend.js` | Supabase မထည့်ရသေးရင် Demo data နဲ့ ပြရန် |
| `supabase-schema.sql` | Database တစ်ခုလုံး |

## Landing page (Wander style) — React + Tailwind v4

```
miba-yeik/
├─ index.html, src/        ← React landing page (Hero video, inverted "Book Now" cutout, ဝန်ဆောင်မှု၊ Booking အဆင့်၊ Account)
├─ public/app.html         ← ဖောက်သည် Website (မူလ index.html — Booking၊ Account၊ Chat)
├─ public/admin.html       ← ဆိုင် Admin
├─ public/config.js        ← Supabase URL / anon key (ဒီဖိုင်ကိုပဲ ပြင်ပါ)
├─ public/assets/brands/   ← ကား logo များ
├─ database/               ← SQL schema များ
└─ legacy-src/             ← admin.html build script/template
```

- `npm install` → `npm run dev` (စမ်းရန်) / `npm run build` → `dist/` ကို Deploy
- Vercel: Root Directory = `miba-yeik`, Framework = Vite
- စာသား၊ Nav link၊ Video URL၊ Promotion badge နံပါတ် → `src/site.js`
- Landing က `app.html#booking`, `#services`, `#posts`, `#account`, `#chat` နဲ့ တိုက်ရိုက် ချိတ်ထားပါတယ်

## Setup — ၅ ဆင့်

1. **Supabase project အသစ်** ဖွင့်ပါ (Region: Singapore)။ Garage POS၊ Suwati project တွေနဲ့ သီးသန့်ပါ။
2. **SQL Editor** → `database/supabase-schema.sql` တစ်ခုလုံး Paste → **Run**။ ပုံတင်ဖို့ `media` storage bucket ကိုလည်း အလိုအလျောက် ဖန်တီးပေးပါတယ်။
3. **Authentication → URL Configuration** → Site URL ကို `https://သင့်domain/` ထားပါ။ Email confirm ကို ပိတ်ထားရင် ဖောက်သည်တွေ Account ဖွင့်တာနဲ့ ချက်ချင်း ဝင်လို့ရပါတယ်။
4. `config.js` ထဲမှာ **Project URL** နဲ့ **anon public key** ထည့်ပါ။
5. **Vercel** နဲ့ Deploy ပါ (Root Directory `miba-yeik`, build `npm run build`, output `dist`)။

## ပထမဆုံး အသုံးပြုပုံ
1. `admin.html` → **အကောင့်ဖွင့် → ဆိုင်ပိုင်ရှင် (ပထမဆုံးအကြိမ်)** — ပထမဆုံး ဖွင့်တဲ့သူက Owner ဖြစ်ပါမယ် (နောက်ထပ် ဆိုင်ဖွင့်လို့ မရတော့ပါ)
2. **Settings** — လိပ်စာ၊ ဖုန်း၊ Viber၊ Facebook၊ Google Maps၊ ဆိုင်အကြောင်း၊ ဖွင့်ချိန်၊ လက်ခဈေး (🌐 = Website မှာ ပြမည်)
3. **Website** — Banner၊ Post တင်ပါ။ Booking အချိန်၊ အချိန်တစ်ခုမှာ ကားဘယ်နှစ်စီး၊ ပိတ်ရက် သတ်မှတ်ပါ
4. **ဝန်ထမ်း** — Email နဲ့ ထည့်ပါ → ဝန်ထမ်းက `admin.html` မှာ “ဝန်ထမ်း” နဲ့ အကောင့်ဖွင့်ရုံပါ

## Booking အလုပ်လုပ်ပုံ
- ဖောက်သည်က Website မှာ ဝန်ဆောင်မှု → ရက် → အချိန် ရွေးပြီး တင် (Account မရှိလည်း ရ)
- Admin **Booking** tab မှာ “စောင့်ဆဲ” ပေါ်လာ → ဖုန်းဆက်ပြီး **အတည်ပြု**
- ကားရောက်ရင် **ကားရောက်ပြီ → Job ဖွင့်** — နံပါတ်ပြား၊ ဖောက်သည်၊ ဝန်ဆောင်မှုတွေ အလိုအလျောက် ဖြည့်ပေးပါတယ်
- ဖုန်းနဲ့ ချိန်းတာကိုလည်း **ဖုန်းဖြင့် Booking ထည့်** နဲ့ ထည့်လို့ရပါတယ်

## ဖောက်သည် Account
- Account ဖွင့်ချိန် **ဖုန်းနံပါတ် + နံပါတ်ပြား** ကိုက်ရင် ဆိုင်မှာ ယခင်ပြင်ခဲ့တဲ့ မှတ်တမ်းနဲ့ အလိုအလျောက် ချိတ်ပေးပါတယ်
- ဖောက်သည်က ကိုယ့်ကားရဲ့ မှတ်တမ်း၊ နောက်တစ်ကြိမ် ဝိုင်လဲရက်၊ Booking ကို ကြည့်ပြီး ဆိုင်နဲ့ Chat လို့ရပါတယ်
- Admin **ဖောက်သည်** စာရင်းမှာ “Online” tag ပါတဲ့သူတွေက Account ရှိသူတွေပါ

## Demo
`config.js` မှာ Supabase မထည့်ရသေးရင် Demo နဲ့ ပွင့်ပါတယ်။ Website မှာ “ဒေါ်သန္တာ အဖြစ် ဝင်မယ်”၊ Admin မှာ Owner / Manager / Staff / မက္ကင်းနစ် အကောင့်တွေနဲ့ စမ်းလို့ရပါတယ်။


## Home page — ကားအမှတ်တံဆိပ်များ
- ဂျပန်ကား logo တွေက `assets/brands/` ထဲမှာ ရှိပြီး Banner အောက်မှာ တန်းလိုက် ရွေ့နေပါတယ်
- Logo တွေက “ဒီကားတွေ ပြင်ပေးပါတယ်” လို့ ပြတာပါ။ တရားဝင် Dealer လို့ ထင်စရာ စာသား မရေးပါနဲ့
