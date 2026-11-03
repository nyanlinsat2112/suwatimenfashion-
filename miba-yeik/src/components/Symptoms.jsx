import { useState } from 'react'
import { ArrowUpRight, Info } from 'lucide-react'
import { APP } from '../site'

// Common undercarriage symptoms → parts that usually cause them.
const SYMPTOMS = [
  {
    id: 'clunk',
    label: 'ကျောက်ခဲလမ်း/ချိုင့်မှာ ဂေါက်ဂေါက်မြည်',
    en: 'Clunk over bumps',
    parts: ['စတက်ဘလိုက်ဇာ လင့်', 'ဘော်လ်ဂျွိုင့်', 'ရှော့ဘာ Mount', 'အောက်လက် ဘုရှ်'],
    note: 'ဂျပန်ကားတွေမှာ အဖြစ်အများဆုံးက စတက်ဘလိုက်ဇာ လင့်ပါ။ ဈေးလည်း သက်သာပါတယ်။',
  },
  {
    id: 'pull',
    label: 'ကား တစ်ဖက်ကို ဆွဲနေ',
    en: 'Pulls to one side',
    parts: ['ဘီးချိန် (Alignment)', 'တာယာ လေမညီ', 'ဘရိတ် ကယ်လီပါ ကပ်နေ', 'အောက်လက် ဘုရှ်'],
    note: 'ဘီးချိန်ရုံနဲ့ မပျောက်ရင် ဘုရှ်၊ ကယ်လီပါကို ဆက်စစ်ရပါမယ်။',
  },
  {
    id: 'shake',
    label: 'အမြန်မောင်းရင် စတီယာရင် တုန်',
    en: 'Steering shakes at speed',
    parts: ['ဘီးမျှ (Balancing)', 'တိုင်ရော့ အန်း', 'ဘော်လ်ဂျွိုင့်', 'ဘရိတ်ဒစ် ကောက်'],
    note: 'ဘရိတ်အုပ်မှ တုန်တာဆိုရင် ဘရိတ်ဒစ် ဖြစ်နိုင်ခြေ များပါတယ်။',
  },
  {
    id: 'bounce',
    label: 'ကား ခုန်/ယိမ်း များ',
    en: 'Bouncy, floaty ride',
    parts: ['ရှော့ဘာ', 'စထရပ် Mount', 'Coil spring'],
    note: 'ရှော့ဘာ ဆီယိုနေရင် ရှော့ဘာတိုင်မှာ ဆီစွန်းနေတာ မြင်ရတတ်ပါတယ်။',
  },
  {
    id: 'click',
    label: 'လှည့်ကွေ့ရင် တောက်တောက်မြည်',
    en: 'Clicking when turning',
    parts: ['CV ဂျွိုင့် (အပြင်)', 'CV ရာဘာအိတ်', 'ဒရိုက်ရှပ်'],
    note: 'CV အိတ်ပေါက်ရင် ဂရိစ်ထွက်ပြီး ဂျွိုင့်ကို မြန်မြန် ပျက်စေပါတယ်။ စောစော ပြင်ရင် သက်သာပါတယ်။',
  },
  {
    id: 'squeal',
    label: 'ဘရိတ်နင်းရင် စီစီ/ကျွီကျွီ',
    en: 'Brake squeal',
    parts: ['ဘရိတ်ပြား ကုန်', 'ဘရိတ်ဒစ်', 'ကယ်လီပါ ပင်'],
    note: 'သံချင်းပွတ်သံ ကြားရရင် ဒစ်ပါ စားသွားနိုင်လို့ မကြာခင် ပြပါ။',
  },
  {
    id: 'tyre',
    label: 'တာယာ တစ်ဖက်တည်း စား',
    en: 'Uneven tyre wear',
    parts: ['ဘီးချိန် (Camber/Toe)', 'ဘော်လ်ဂျွိုင့်', 'အောက်လက် ဘုရှ်', 'ရှော့ဘာ'],
    note: 'တာယာ အသစ်မလဲခင် ဘီးချိန်ပါ စစ်ပါ၊ မဟုတ်ရင် အသစ်ပါ ထပ်စားပါမယ်။',
  },
  {
    id: 'heavy',
    label: 'စတီယာရင် လေး/ချောင်',
    en: 'Heavy or loose steering',
    parts: ['ပါဝါစတီယာရင် ဆီ/ပန့်', 'စတီယာရင် ရက်ခ်', 'ရက်ခ်အန်း', 'တိုင်ရော့ အန်း'],
    note: 'ဆီယိုနေလား အရင်ကြည့်ပါ — ကားရပ်ထားတဲ့ မြေပေါ်မှာ အနီရောင်ဆီစက် ကျနေတတ်ပါတယ်။',
  },
]

export default function Symptoms() {
  const [sel, setSel] = useState(SYMPTOMS[0].id)
  const s = SYMPTOMS.find((x) => x.id === sel)

  return (
    <section id="symptoms" className="scroll-mt-6 grid gap-4 lg:grid-cols-[1.25fr_1fr]">
      <div className="rounded-[32px] md:rounded-[40px] bg-white/60 ring-1 ring-black/5 shadow-sm p-8 md:p-12">
        <p className="text-sm font-bold uppercase tracking-widest text-wander-orange">Symptom checker</p>
        <h2 className="mt-3 text-3xl md:text-4xl font-medium leading-[1.05] tracking-tight text-wander-dark">
          What is your car telling you?
        </h2>
        <p className="mt-3 leading-relaxed text-wander-text/80">ကားမှာ ဖြစ်နေတာကို ရွေးကြည့်ပါ။</p>

        <div className="mt-8 flex flex-wrap gap-2.5" role="radiogroup" aria-label="ရောဂါလက္ခဏာ">
          {SYMPTOMS.map((x) => (
            <button
              key={x.id}
              type="button"
              role="radio"
              aria-checked={sel === x.id}
              onClick={() => setSel(x.id)}
              className={`rounded-full border-2 px-4 py-2 text-sm leading-relaxed transition-colors ${
                sel === x.id
                  ? 'border-wander-dark bg-wander-dark text-white'
                  : 'border-wander-dark/15 text-wander-dark hover:border-wander-dark hover:text-orange-500'
              }`}
            >
              {x.label}
            </button>
          ))}
        </div>
      </div>

      <div className="relative flex flex-col rounded-[32px] md:rounded-[40px] bg-wander-blue p-8 md:p-12" aria-live="polite">
        <p className="text-xs font-bold uppercase tracking-widest text-wander-dark/70">{s.en}</p>
        <h3 className="mt-2 text-2xl font-medium leading-relaxed text-wander-dark">{s.label}</h3>
        <p className="mt-6 text-sm font-semibold text-wander-dark">ဖြစ်နိုင်တဲ့ အစိတ်အပိုင်းများ</p>
        <ol className="mt-3 grid gap-2">
          {s.parts.map((p, i) => (
            <li key={p} className="flex items-center gap-3 rounded-2xl bg-wander-bg/70 px-4 py-3 text-wander-dark">
              <span className="flex h-7 w-7 shrink-0 items-center justify-center rounded-full bg-wander-dark text-xs font-bold text-white">
                {i + 1}
              </span>
              <span className="leading-relaxed">{p}</span>
            </li>
          ))}
        </ol>
        <p className="mt-5 text-sm leading-relaxed text-wander-text/90">{s.note}</p>
        <p className="mt-4 flex items-start gap-2 text-xs leading-relaxed text-wander-dark/70">
          <Info size={14} className="mt-0.5 shrink-0" /> ခန့်မှန်းချက်သာ ဖြစ်ပါတယ်။ ကားကို Lift တင်ပြီး စစ်ဆေးမှ အတိအကျ သိရပါမယ်။
        </p>
        <a
          href={`${APP}#booking`}
          className="mt-8 self-start inline-flex items-center gap-2 rounded-full bg-wander-orange px-7 py-3.5 text-sm font-semibold uppercase tracking-wide text-white hover:bg-orange-500 transition-colors"
        >
          စစ်ဆေးဖို့ Booking <ArrowUpRight size={18} />
        </a>
      </div>
    </section>
  )
}
