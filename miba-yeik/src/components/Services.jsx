import { Droplet, Disc3, Snowflake, Gauge, Cog, BatteryCharging, ArrowUpRight } from 'lucide-react'
import { APP } from '../site'

const SERVICES = [
  { icon: Droplet, name: 'အင်ဂျင်ဝိုင်လဲ', en: 'Oil change', desc: 'ဝိုင်၊ ဝိုင်စစ် လဲပြီး နောက်တစ်ကြိမ် လဲရမယ့်ရက်ကို Account မှာ မှတ်ပေးပါတယ်။' },
  { icon: Disc3, name: 'ဘရိတ်', en: 'Brakes', desc: 'ဘရိတ်ပြား၊ ဒစ်၊ ဘရိတ်ဆီ စစ်ဆေး လဲလှယ်ခြင်း။' },
  { icon: Snowflake, name: 'AC', en: 'Air-con', desc: 'AC ဂတ်စ်ဖြည့်၊ ယိုစိမ့်စစ်၊ စစ်ကြောပြင်ဆင်ခြင်း။' },
  { icon: Gauge, name: 'ဘီးချိန်', en: 'Alignment', desc: 'ဘီးချိန်၊ ဘီးမျှ — လမ်းကြောင်းဖြောင့်ဖြောင့် မောင်းနိုင်အောင်။' },
  { icon: Cog, name: 'အင်ဂျင်စစ်ဆေး', en: 'Engine check', desc: 'အသံ၊ တုန်ခါမှု၊ စက်ပိုင်းဆိုင်ရာ ပြဿနာများ ရှာဖွေပြင်ဆင်ခြင်း။' },
  { icon: BatteryCharging, name: 'ဘက်ထရီ & လျှပ်စစ်', en: 'Battery & electrical', desc: 'ဘက်ထရီ စစ်ဆေး/လဲလှယ်၊ မီး၊ ဝိုင်ယာ ပြဿနာများ။' },
]

export default function Services() {
  return (
    <section id="services" className="scroll-mt-6 px-2 py-16 md:px-6 md:py-24">
      <div className="flex flex-col gap-4 md:flex-row md:items-end md:justify-between">
        <div>
          <p className="text-sm font-bold uppercase tracking-widest text-wander-orange">Our services</p>
          <h2 className="mt-3 text-3xl md:text-4xl lg:text-5xl font-medium leading-[1.05] tracking-tight text-wander-dark">
            Everything your car needs,
            <br className="hidden sm:block" /> under one roof.
          </h2>
        </div>
        <a
          href={`${APP}#services`}
          className="self-start md:self-auto inline-flex items-center gap-2 rounded-full border-2 border-wander-dark px-6 py-3 text-sm font-semibold uppercase tracking-wide text-wander-dark hover:bg-wander-dark hover:text-white transition-colors"
        >
          ဈေးနှုန်းအားလုံး <ArrowUpRight size={18} />
        </a>
      </div>

      <div className="mt-10 grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
        {SERVICES.map(({ icon: Icon, name, en, desc }) => (
          <a
            key={en}
            href={`${APP}#booking`}
            className="group relative flex flex-col rounded-[32px] bg-white/60 p-7 ring-1 ring-black/5 shadow-sm hover:bg-white transition-colors"
          >
            <div className="flex items-start justify-between">
              <span className="flex h-14 w-14 items-center justify-center rounded-2xl bg-wander-blue/25 text-wander-dark">
                <Icon size={26} />
              </span>
              <span className="flex h-10 w-10 items-center justify-center rounded-full bg-black/5 text-wander-dark group-hover:bg-wander-dark group-hover:text-white transition-colors">
                <ArrowUpRight size={18} />
              </span>
            </div>
            <p className="mt-6 text-xs font-bold uppercase tracking-widest text-wander-text/60">{en}</p>
            <h3 className="mt-1 text-xl font-medium leading-relaxed text-wander-dark">{name}</h3>
            <p className="mt-2 text-sm leading-relaxed text-wander-text/80">{desc}</p>
          </a>
        ))}
      </div>
    </section>
  )
}
