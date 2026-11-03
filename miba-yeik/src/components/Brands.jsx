import { BRANDS } from '../site'

export default function Brands() {
  const row = [...BRANDS, ...BRANDS]
  return (
    <section className="rounded-[32px] md:rounded-[40px] bg-white/60 ring-1 ring-black/5 shadow-sm py-10 overflow-hidden">
      <p className="px-6 text-center text-sm font-bold uppercase tracking-widest text-wander-text/70">
        ပြင်ပေးသော ကားအမှတ်တံဆိပ်များ
      </p>
      <div className="mt-6 [mask-image:linear-gradient(90deg,transparent,black_12%,black_88%,transparent)] [-webkit-mask-image:linear-gradient(90deg,transparent,black_12%,black_88%,transparent)]">
        <div className="flex w-max animate-marquee gap-14 hover:[animation-play-state:paused]">
          {row.map((b, i) => (
            <img
              key={i}
              src={`assets/brands/${b}.png`}
              alt={i < BRANDS.length ? b[0].toUpperCase() + b.slice(1) : ''}
              aria-hidden={i >= BRANDS.length}
              loading="lazy"
              className="h-12 md:h-14 w-auto object-contain opacity-70 grayscale hover:opacity-100 hover:grayscale-0 transition"
            />
          ))}
        </div>
      </div>
    </section>
  )
}
