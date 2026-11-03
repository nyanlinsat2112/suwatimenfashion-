import { ListChecks, CalendarDays, PhoneCall, ArrowUpRight } from 'lucide-react'
import { APP } from '../site'

const STEPS = [
  { icon: ListChecks, title: 'ဝန်ဆောင်မှု ရွေးပါ', desc: 'ဝိုင်လဲ၊ ဘရိတ်၊ AC… လိုချင်တာ ရွေးပါ။ ဈေးနှုန်းကို ကြိုသိရပါမယ်။' },
  { icon: CalendarDays, title: 'ရက်နဲ့ အချိန် ရွေးပါ', desc: 'လွတ်နေတဲ့ အချိန်ကိုပဲ ပြပေးပါတယ်။ Account မရှိလည်း Booking တင်လို့ရပါတယ်။' },
  { icon: PhoneCall, title: 'ဆိုင်က အတည်ပြုပေးမယ်', desc: 'ဆိုင်က ဖုန်းဆက်ပြီး အတည်ပြုပေးပါမယ်။ ရောက်တာနဲ့ ချက်ချင်း စလုပ်ပေးပါတယ်။' },
]

export default function HowItWorks() {
  return (
    <section className="relative rounded-[32px] md:rounded-[40px] bg-wander-dark text-white overflow-hidden px-8 py-14 md:px-14 md:py-20">
      <div className="pointer-events-none absolute -right-24 -top-24 h-72 w-72 rounded-full bg-wander-blue/25 blur-3xl" />
      <p className="text-sm font-bold uppercase tracking-widest text-wander-blue">Online booking</p>
      <h2 className="mt-3 max-w-2xl text-3xl md:text-4xl lg:text-5xl font-medium leading-[1.05] tracking-tight">
        Skip the queue in three easy steps.
      </h2>

      <ol className="mt-12 grid gap-8 md:grid-cols-3">
        {STEPS.map(({ icon: Icon, title, desc }, i) => (
          <li key={title} className="flex flex-col">
            <div className="flex items-center gap-4">
              <span className="flex h-12 w-12 items-center justify-center rounded-full bg-white/10">
                <Icon size={22} />
              </span>
              <span className="font-serif text-5xl font-medium text-white/15">0{i + 1}</span>
            </div>
            <h3 className="mt-5 text-xl font-medium leading-relaxed">{title}</h3>
            <p className="mt-2 text-sm leading-relaxed text-white/70">{desc}</p>
          </li>
        ))}
      </ol>

      <a
        href={`${APP}#booking`}
        className="mt-12 inline-flex items-center gap-2 rounded-full bg-wander-orange px-8 py-3.5 text-sm font-semibold uppercase tracking-wide text-white hover:bg-orange-500 transition-colors"
      >
        Booking လုပ်မယ် <ArrowUpRight size={18} />
      </a>
    </section>
  )
}
