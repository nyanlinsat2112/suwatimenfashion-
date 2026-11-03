import { Plus } from 'lucide-react'

const FAQS = [
  {
    q: 'ရှော့ဘာ ဘယ်အချိန် လဲသင့်လဲ?',
    a: 'ကီလိုမီတာနဲ့ အတိအကျ မသတ်မှတ်နိုင်ပေမယ့် ကားခုန်လာတာ၊ ဘရိတ်အုပ်ရင် ခေါင်းငုံ့တာ၊ ရှော့ဘာမှာ ဆီစွန်းနေတာ တွေ့ရင် စစ်ဆေးသင့်ပါပြီ။ မြန်မာလမ်းတွေမှာ ပိုမြန်မြန် ဟောင်းတတ်ပါတယ်။',
  },
  {
    q: 'ဘီးချိန် ဘယ်နှစ်ခါ လုပ်သင့်လဲ?',
    a: 'တာယာအသစ် လဲတိုင်း၊ အောက်ပိုင်း အစိတ်အပိုင်း (ဘော်လ်ဂျွိုင့်၊ တိုင်ရော့၊ ဘုရှ်) လဲတိုင်း၊ ချိုင့်ကြီးထဲ ပြင်းပြင်း ကျပြီးတိုင်း ချိန်သင့်ပါတယ်။',
  },
  {
    q: 'ဘယ်ကားတွေ လုပ်ပေးလဲ?',
    a: 'Toyota၊ Honda၊ Nissan၊ Mazda၊ Mitsubishi၊ Suzuki၊ Subaru၊ Isuzu စတဲ့ ဂျပန်ကားတွေကို သီးသန့် လုပ်ပါတယ် — Probox၊ Belta၊ Fit၊ Wish၊ Fielder၊ Hilux လို မြန်မာမှာ အများဆုံးစီးတဲ့ ကားတွေ နေ့တိုင်း ဝင်ပါတယ်။',
  },
  {
    q: 'စစ်ဆေးဖို့ ကြာလား?',
    a: 'အောက်ပိုင်း စစ်ဆေးမှု အများအားဖြင့် နာရီဝက်ခန့် ကြာပါတယ်။ Online Booking နဲ့ အချိန်ကြိုယူထားရင် ရောက်တာနဲ့ Lift တင်ပေးနိုင်ပါတယ်။',
  },
  {
    q: 'ပစ္စည်း ကိုယ်တိုင် ဝယ်လာလို့ရလား?',
    a: 'ရပါတယ်၊ လက်ခပဲ ယူပါတယ်။ ဆိုင်မှာလည်း Genuine နဲ့ ဈေးသက်သာတဲ့ ရွေးစရာ ပစ္စည်းတွေ ထားပေးပါတယ် — ဈေးနှုန်းကို ကြိုပြောပြီးမှ လဲပါတယ်။',
  },
]

export default function Faq() {
  return (
    <section className="grid gap-8 px-2 py-16 md:px-6 md:py-20 lg:grid-cols-[1fr_1.6fr]">
      <div>
        <p className="text-sm font-bold uppercase tracking-widest text-wander-orange">FAQ</p>
        <h2 className="mt-3 text-3xl md:text-4xl font-medium leading-[1.05] tracking-tight text-wander-dark">
          Questions we hear every day.
        </h2>
      </div>
      <div className="grid gap-3">
        {FAQS.map(({ q, a }) => (
          <details key={q} className="group rounded-[24px] bg-white/60 ring-1 ring-black/5 px-6 py-5 open:bg-white transition-colors">
            <summary className="flex cursor-pointer list-none items-center justify-between gap-4 font-medium leading-relaxed text-wander-dark hover:text-orange-500 transition-colors [&::-webkit-details-marker]:hidden">
              {q}
              <span className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-black/5 transition-transform group-open:rotate-45">
                <Plus size={16} />
              </span>
            </summary>
            <p className="mt-3 text-sm leading-relaxed text-wander-text/80">{a}</p>
          </details>
        ))}
      </div>
    </section>
  )
}
