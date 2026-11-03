// Landing page content — edit text/links here.
// app.html  = customer website (services & prices, booking, account, chat)
// admin.html = shop admin
export const APP = 'app.html'

// Hero background video. public/videos/garage.mp4 is an animated car-on-lift
// scene (made with tools/scene.html). Swap in your own shop video with the same
// name, or put a full https:// URL to an .mp4 here.
export const HERO_VIDEO = 'videos/garage.mp4'

// Number shown on the bell badge (current promotions on the customer site)
export const PROMO_COUNT = 2

export const NAV_LINKS = [
  { label: 'ရှော့ဘာ', href: '#services' },
  { label: 'ဂျွိုင့်/ဘုရှ်', href: '#services' },
  { label: 'စတီယာရင်', href: '#services' },
  { label: 'ဘရိတ်', href: '#services' },
  { label: 'ဘီးချိန်', href: '#services' },
  { label: 'ရောဂါလက္ခဏာ', href: '#symptoms' },
  { label: 'Promotion', href: `${APP}#posts`, accent: true },
]

export const BRANDS = ['toyota', 'honda', 'nissan', 'mazda', 'mitsubishi', 'suzuki', 'subaru', 'isuzu']
