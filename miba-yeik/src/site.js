// Landing page content — edit text/links here.
// app.html  = customer website (services & prices, booking, account, chat)
// admin.html = shop admin
export const APP = 'app.html'

// Hero background video — put your garage video at public/videos/garage.mp4
// (landscape, 1920x1080 or 1280x720, under ~10MB, no sound needed).
// A full https:// URL to an .mp4 also works here.
export const HERO_VIDEO = 'videos/garage.mp4'

// Number shown on the bell badge (current promotions on the customer site)
export const PROMO_COUNT = 2

export const NAV_LINKS = [
  { label: 'ဝိုင်လဲ', href: '#services' },
  { label: 'ဘရိတ်', href: '#services' },
  { label: 'AC', href: '#services' },
  { label: 'ဘီးချိန်', href: '#services' },
  { label: 'ဈေးနှုန်း', href: `${APP}#services` },
  { label: 'Booking', href: `${APP}#booking` },
  { label: 'Promotion', href: `${APP}#posts`, accent: true },
]

export const BRANDS = ['toyota', 'honda', 'nissan', 'mazda', 'mitsubishi', 'suzuki', 'subaru', 'isuzu']
