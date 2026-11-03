import { ClipboardList, CalendarCheck, MessageCircle, ArrowUpRight } from 'lucide-react'
import { APP } from '../site'

const PERKS = [
  { icon: ClipboardList, title: 'ပြင်ဆင်မှု မှတ်တမ်း', desc: 'ဘယ်နေ့ ဘာလဲခဲ့လဲ၊ ဘယ်လောက်ကျလဲ — ကားတစ်စီးချင်း မှတ်တမ်း အကုန်ကြည့်နိုင်ပါတယ်။' },
  { icon: CalendarCheck, title: 'Booking အခြေအနေ', desc: 'တင်ထားတဲ့ Booking အတည်ပြုပြီးလား၊ ဆိုင်က ဘာမှတ်ချက်ပေးလဲ ကြည့်နိုင်ပါတယ်။' },
  { icon: MessageCircle, title: 'ဆိုင်နဲ့ Chat', desc: 'အသံဖိုင်၊ ပုံနဲ့ ပို့ပြီး ကားမှာ ဖြစ်နေတာကို တိုက်ရိုက် မေးနိုင်ပါတယ်။' },
]

export default function AccountPerks() {
  return (
    <section className="grid gap-4 lg:grid-cols-[1.1fr_2fr]">
      <div className="flex flex-col justify-between rounded-[32px] md:rounded-[40px] bg-wander-blue p-8 md:p-12">
        <div>
          <p className="text-sm font-bold uppercase tracking-widest text-wander-dark">Customer account</p>
          <h2 className="mt-3 text-3xl md:text-4xl font-medium leading-[1.05] tracking-tight text-wander-dark">
            Your car’s service book, always in your pocket.
          </h2>
          <p className="mt-4 text-base leading-relaxed text-wander-text/90">
            ဖုန်းနံပါတ် + နံပါတ်ပြား ကိုက်ရင် ဆိုင်မှာ ယခင်ပြင်ခဲ့တဲ့ မှတ်တမ်းနဲ့ အလိုအလျောက် ချိတ်ပေးပါတယ်။
          </p>
        </div>
        <a
          href={`${APP}#account`}
          className="mt-8 self-start inline-flex items-center gap-2 rounded-full border-2 border-wander-dark px-7 py-3 text-sm font-semibold uppercase tracking-wide text-wander-dark hover:bg-wander-dark hover:text-white transition-colors"
        >
          Account ဖွင့်မယ် <ArrowUpRight size={18} />
        </a>
      </div>

      <div className="grid gap-4 sm:grid-cols-3">
        {PERKS.map(({ icon: Icon, title, desc }) => (
          <div key={title} className="flex flex-col rounded-[32px] bg-white/60 p-7 ring-1 ring-black/5 shadow-sm">
            <span className="flex h-12 w-12 items-center justify-center rounded-full bg-wander-orange/15 text-wander-orange">
              <Icon size={22} />
            </span>
            <h3 className="mt-6 text-lg font-medium leading-relaxed text-wander-dark">{title}</h3>
            <p className="mt-2 text-sm leading-relaxed text-wander-text/80">{desc}</p>
          </div>
        ))}
      </div>
    </section>
  )
}
