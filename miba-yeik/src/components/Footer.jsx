import { CarFront } from 'lucide-react'
import { APP } from '../site'

const LINKS = [
  { label: 'ဝန်ဆောင်မှု ဈေးနှုန်း', href: `${APP}#services` },
  { label: 'Online Booking', href: `${APP}#booking` },
  { label: 'သတင်းနှင့် Promotion', href: `${APP}#posts` },
  { label: 'Account', href: `${APP}#account` },
  { label: 'ဆိုင်နဲ့ Chat', href: `${APP}#chat` },
  { label: 'ဝန်ထမ်း Login', href: 'admin.html' },
]

export default function Footer() {
  return (
    <footer className="px-2 pt-6 pb-4 md:px-6">
      <div className="flex flex-col gap-8 border-t border-wander-dark/10 pt-10 md:flex-row md:items-start md:justify-between">
        <div className="max-w-sm">
          <a href="#" className="flex items-center gap-2.5 text-wander-dark hover:text-orange-500 transition-colors">
            <CarFront size={28} />
            <span className="font-bold text-xl uppercase tracking-widest">Miba Yeik</span>
          </a>
          <p className="mt-3 text-sm leading-relaxed text-wander-text/70">
            မိဘရိပ် Auto Service — ဆိုင်လိပ်စာ၊ ဖုန်း၊ ဖွင့်ချိန်ကို ဖောက်သည် Website မှာ ကြည့်နိုင်ပါတယ်။
          </p>
        </div>
        <ul className="grid grid-cols-2 gap-x-10 gap-y-3 text-sm">
          {LINKS.map((l) => (
            <li key={l.label}>
              <a href={l.href} className="text-wander-dark/90 hover:text-orange-500 transition-colors">
                {l.label}
              </a>
            </li>
          ))}
        </ul>
      </div>
      <p className="mt-10 text-xs text-wander-text/50">© {new Date().getFullYear()} Miba Yeik Auto Service</p>
    </footer>
  )
}
