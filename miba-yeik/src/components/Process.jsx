import { CarFront, ScanSearch, MessageSquareText, Wrench, Route } from 'lucide-react'

const STEPS = [
  { icon: CarFront, title: 'ပြဿနာ ပြောပြ', desc: 'ဘယ်အချိန် မြည်လဲ၊ ဘယ်လမ်းမှာ တုန်လဲ — သိသလောက် ပြောပြပါ။' },
  { icon: ScanSearch, title: 'Lift တင် စစ်ဆေး', desc: 'ကားကို Lift ပေါ်တင်ပြီး အောက်ပိုင်း တစ်ခုချင်း လှုပ်ကြည့်၊ စစ်ကြည့်ပါတယ်။' },
  { icon: MessageSquareText, title: 'ပြ၊ ရှင်း၊ ဈေးပြော', desc: 'ပျက်နေတဲ့ အစိတ်အပိုင်းကို ပြပြီး ဈေးနှုန်း ကြိုပြောပါတယ်။ သဘောတူမှ စလုပ်ပါတယ်။' },
  { icon: Wrench, title: 'ပြင်ဆင်', desc: 'အစိတ်အပိုင်း လဲပြီးရင် လိုအပ်သလို ဘီးချိန် ပြန်ချိန်ပေးပါတယ်။' },
  { icon: Route, title: 'စမ်းမောင်း', desc: 'ပြင်ပြီးတိုင်း လမ်းပေါ် စမ်းမောင်းပြီး အသံ ပျောက်မပျောက် စစ်ပါတယ်။' },
]

export default function Process() {
  return (
    <section className="px-2 py-16 md:px-6 md:py-20">
      <p className="text-sm font-bold uppercase tracking-widest text-wander-orange">How we work</p>
      <h2 className="mt-3 max-w-2xl text-3xl md:text-4xl lg:text-5xl font-medium leading-[1.05] tracking-tight text-wander-dark">
        No guessing. We lift it, show you, then fix it.
      </h2>
      <ol className="mt-12 grid gap-4 sm:grid-cols-2 lg:grid-cols-5">
        {STEPS.map(({ icon: Icon, title, desc }, i) => (
          <li key={title} className="relative flex flex-col rounded-[28px] border-2 border-wander-dark/10 p-6">
            <div className="flex items-center justify-between">
              <span className="flex h-11 w-11 items-center justify-center rounded-full bg-wander-dark text-white">
                <Icon size={20} />
              </span>
              <span className="font-serif text-3xl font-medium text-wander-dark/20">{i + 1}</span>
            </div>
            <h3 className="mt-5 text-lg font-medium leading-relaxed text-wander-dark">{title}</h3>
            <p className="mt-1.5 text-sm leading-relaxed text-wander-text/80">{desc}</p>
          </li>
        ))}
      </ol>
    </section>
  )
}
