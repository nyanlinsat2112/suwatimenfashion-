# SUWATI MEN FASHION — Website ဖိုင်လမ်းညွှန်

Customer Website (`index.html`) ကို Feature အလိုက် ဖိုင်ခွဲထားပါသည်။ Code ကို ပြောင်းလဲခြင်း မရှိဘဲ ဖြတ်ခွဲထားခြင်းသာ ဖြစ်ပါသည်။

## ဖိုင်များ

| ဖိုင် | ပါဝင်သည့်အရာ |
|---|---|
| `index.html` | Page ပုံစံ (HTML) သက်သက် |
| `css/site.css` | ဒီဇိုင်း/အရောင်/Layout အားလုံး |
| `js/site/config.js` | Supabase ချိတ်ဆက်မှု + Share Link ဖတ်ခြင်း |
| `js/site/products.js` | Category၊ Product စာရင်း၊ Search၊ Banner၊ Post |
| `js/site/auto-refresh.js` | Realtime Auto Refresh |
| `js/site/cart.js` | ခြင်း |
| `js/site/wishlist.js` | Wishlist |
| `js/site/checkout.js` | Order တင်ခြင်း၊ KBZPay/Prepaid ငွေပေးချေမှု၊ Gift ထုပ်ပိုး၊ Delivery Zone၊ Promo Code၊ Cashback၊ Receipt၊ Ticker |
| `js/site/account.js` | Login/Signup၊ Profile၊ Order History |
| `js/site/wallet.js` | Prepaid Card / Wallet |
| `js/site/gift-card.js` | Gift Card |
| `js/site/chat.js` | Chat |
| `js/site/order-tracking.js` | Order Track (Guest) |
| `js/site/product-detail.js` | Product Detail၊ ပုံ Slider၊ Share Link |
| `js/site/boot.js` | Website စတင်ခြင်း — **အောက်ဆုံးမှ Load ရမည်** |

`backup/index-before-split.html` — မခွဲခင် မူလဖိုင် (ပြဿနာဖြစ်ရင် ပြန်သုံးရန်)။ **GitHub ပေါ် မတင်ပါနှင့်**။

## ⚠️ စည်းကမ်း ၃ ချက်

1. `index.html` အောက်ဆုံးက `<script>` ဖိုင်များ၏ **အစဉ်ကို မပြောင်းပါနှင့်** (`boot.js` အမြဲ နောက်ဆုံး)။
2. JS/CSS ဖိုင် ပြင်ပြီး တင်တိုင်း `index.html` ထဲက အဲ့ဖိုင်ရဲ့ `?v=20260924` နံပါတ်ကို ပြောင်းပေးရပါမည် (ဥပမာ `?v=20261001`) — မပြောင်းရင် Customer ရဲ့ Browser က ဖိုင်အဟောင်းကို ဆက်သုံးနိုင်ပါသည်။ (Claude က ပြင်ပေးတိုင်း ဒီနံပါတ်ကို ပြောင်းပေးပါမည်)
3. Upload တင်ရင် `css` နှင့် `js` Folder များကို ဖွဲ့စည်းပုံ အတိုင်း တင်ရပါမည် (`js/site/...`)။
