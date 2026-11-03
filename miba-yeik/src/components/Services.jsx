import { ArrowUpRight, ScanSearch, Waves, CircleDot, Link2, Navigation, Disc3, Cog, Crosshair } from 'lucide-react'
import { APP } from '../site'

const SERVICES = [
  { icon: ScanSearch, name: 'အောက်ပိုင်း စစ်ဆေး', en: 'Lift inspection', desc: 'ကားကို Lift တင်ပြီး ရှော့ဘာ၊ ဂျွိုင့်၊ ဘုရှ်၊ ဘရိတ်၊ ဆီယို အကုန် တစ်ခါတည်း စစ်ပေးပါတယ်။' },
  { icon: Waves, name: 'ရှော့ဘာ / စထရပ်', en: 'Shocks & struts', desc: 'ကားခုန်တာ၊ ဘရိတ်အုပ်ရင် ခေါင်းငုံ့တာ၊ ရှော့ဘာ ဆီယိုတာ — ရှေ့/နောက် လဲလှယ်ခြင်း။' },
  { icon: CircleDot, name: 'ဘော်လ်ဂျွိုင့် / တိုင်ရော့', en: 'Ball joints & tie rods', desc: 'ကျောက်ခဲလမ်းမှာ ဂေါက်ဂေါက်မြည်တာ၊ စတီယာရင် ချောင်တာ။' },
  { icon: Link2, name: 'ရာဘာဘုရှ် / အောက်လက်', en: 'Bushings & control arms', desc: 'အောက်လက်ဘုရှ်၊ စတက်ဘလိုက်ဇာ ဘုရှ်/လင့် — တုန်ခါမှု၊ အသံ လျော့စေ။' },
  { icon: Navigation, name: 'စတီယာရင် ရက်ခ်', en: 'Steering rack', desc: 'ရက်ခ်အန်း၊ ပါဝါစတီယာရင် ဆီယို၊ စတီယာရင် လေးတာ/ချောင်တာ။' },
  { icon: Cog, name: 'ဒရိုက်ရှပ် / CV ဂျွိုင့်', en: 'Drive shafts & CV', desc: 'လှည့်ကွေ့ရင် တောက်တောက်မြည်တာ၊ CV ရာဘာအိတ် ပေါက်တာ။' },
  { icon: Disc3, name: 'ဘရိတ်', en: 'Brakes', desc: 'ဘရိတ်ပြား၊ ဒစ်၊ ကယ်လီပါ၊ ဘရိတ်ဆီ — စီစီမြည်တာ၊ ဘရိတ်တုန်တာ။' },
  { icon: Crosshair, name: 'ဘီးချိန် / ဘီးမျှ', en: 'Alignment & balancing', desc: 'ကားတစ်ဖက်ဆွဲတာ၊ တာယာ တစ်ဖက်စားတာ၊ အမြန်မောင်းရင် စတီယာရင် တုန်တာ။' },
]

export default function Services() {
  return (
    <section id="services" className="scroll-mt-6 px-2 py-16 md:px-6 md:py-24">
      <div className="flex flex-col gap-4 md:flex-row md:items-end md:justify-between">
        <div>
          <p className="text-sm font-bold uppercase tracking-widest text-wander-orange">What we fix</p>
          <h2 className="mt-3 text-3xl md:text-4xl lg:text-5xl font-medium leading-[1.05] tracking-tight text-wander-dark">
            Everything below the doors,
            <br className="hidden sm:block" /> nothing else.
          </h2>
          <p className="mt-4 max-w-xl leading-relaxed text-wander-text/80">
            အင်ဂျင်၊ AC မလုပ်ပါ — အောက်ပိုင်း တစ်ခုတည်းကိုပဲ နေ့တိုင်း လုပ်နေလို့ ပြဿနာကို မြန်မြန် ရှာနိုင်ပါတယ်။
          </p>
        </div>
        <a
          href={`${APP}#services`}
          className="self-start md:self-auto inline-flex items-center gap-2 rounded-full border-2 border-wander-dark px-6 py-3 text-sm font-semibold uppercase tracking-wide text-wander-dark hover:bg-wander-dark hover:text-white transition-colors"
        >
          ဈေးနှုန်းအားလုံး <ArrowUpRight size={18} />
        </a>
      </div>

      <div className="mt-10 grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
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
