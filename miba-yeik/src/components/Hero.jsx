import { useEffect, useRef, useState } from 'react'
import Navbar from './Navbar'
import BookNowCutout from './BookNowCutout'
import { HERO_VIDEO } from '../site'

export default function Hero() {
  const videoRef = useRef(null)
  const [videoOk, setVideoOk] = useState(true)

  useEffect(() => {
    if (videoRef.current) videoRef.current.playbackRate = 0.25
  }, [])

  return (
    <section className="relative w-full h-[calc(100vh-2rem)] md:h-[calc(100vh-3rem)] rounded-[32px] md:rounded-[40px] overflow-hidden shadow-sm ring-1 ring-black/5 bg-wander-blue">
      <Navbar />

      {/* Mobile: video is enlarged and lifted above the Book Now cutout with a soft mask.
          md+: bottom-anchored, natural size, sharp bottom edge (spec mask). */}
      {videoOk && (
      <video
        ref={videoRef}
        src={HERO_VIDEO}
        autoPlay
        loop
        muted
        playsInline
        onLoadedMetadata={(e) => (e.currentTarget.playbackRate = 0.25)}
        onError={() => setVideoOk(false)}
        className="absolute bottom-24 left-1/2 -translate-x-1/2 w-[190%] max-w-none pointer-events-none [mask-image:linear-gradient(to_bottom,transparent,black_35%,black_70%,transparent)] [-webkit-mask-image:linear-gradient(to_bottom,transparent,black_35%,black_70%,transparent)] md:bottom-0 md:w-auto md:max-w-full md:[mask-image:radial-gradient(55%_100%_at_bottom,black_5%,transparent_90%)] md:[-webkit-mask-image:radial-gradient(55%_100%_at_bottom,black_5%,transparent_90%)]"
      />
      )}

      <div className="relative z-10 flex h-full flex-col items-center justify-center text-center px-6">
        <div className="max-w-3xl -mt-22 flex flex-col items-center">
          <p className="text-sm font-bold uppercase tracking-widest text-wander-dark">Japanese undercarriage specialist</p>
          <h1 className="mt-5 text-4xl md:text-5xl lg:text-6xl font-medium leading-[1.05] tracking-tight text-wander-dark">
            A smooth ride starts
            <br />
            underneath.
          </h1>
          <p className="mt-6 max-w-md text-lg md:text-xl leading-relaxed text-wander-text/90">
            ဂျပန်ကား အောက်ပိုင်း သီးသန့် — ရှော့ဘာ၊ ဘော်လ်ဂျွိုင့်၊ ဘုရှ်၊ စတီယာရင်၊ ဘရိတ်၊ ဘီးချိန်။ မြည်တာ၊ တုန်တာ၊ ဆွဲတာ အကုန် ရှာပြီး ပြင်ပေးပါတယ်။
          </p>
          <a
            href="#symptoms"
            className="mt-8 inline-flex items-center rounded-full border-2 border-wander-dark px-8 py-3.5 text-sm font-semibold uppercase tracking-wide text-wander-dark hover:bg-wander-dark hover:text-white transition-colors"
          >
            ကားအသံ စစ်ကြည့်မယ်
          </a>
        </div>
      </div>

      <BookNowCutout />
    </section>
  )
}
