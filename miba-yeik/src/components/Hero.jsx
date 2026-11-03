import { useEffect, useRef } from 'react'
import Navbar from './Navbar'
import BookNowCutout from './BookNowCutout'
import { HERO_VIDEO } from '../site'

export default function Hero() {
  const videoRef = useRef(null)

  useEffect(() => {
    if (videoRef.current) videoRef.current.playbackRate = 0.25
  }, [])

  return (
    <section className="relative w-full h-[calc(100vh-2rem)] md:h-[calc(100vh-3rem)] rounded-[32px] md:rounded-[40px] overflow-hidden shadow-sm ring-1 ring-black/5 bg-wander-blue">
      <Navbar />

      <video
        ref={videoRef}
        src={HERO_VIDEO}
        autoPlay
        loop
        muted
        playsInline
        onLoadedMetadata={(e) => (e.currentTarget.playbackRate = 0.25)}
        className="absolute bottom-0 left-1/2 -translate-x-1/2 w-full md:w-auto pointer-events-none [mask-image:radial-gradient(55%_100%_at_bottom,black_5%,transparent_90%)] [-webkit-mask-image:radial-gradient(55%_100%_at_bottom,black_5%,transparent_90%)]"
      />

      <div className="relative z-10 flex h-full flex-col items-center justify-center text-center px-6">
        <div className="max-w-3xl -mt-22 flex flex-col items-center">
          <p className="text-sm font-bold uppercase tracking-widest text-wander-dark">Care for every journey</p>
          <h1 className="mt-5 text-4xl md:text-5xl lg:text-6xl font-medium leading-[1.05] tracking-tight text-wander-dark">
            Your car, cared for
            <br />
            like family.
          </h1>
          <p className="mt-6 max-w-md text-lg md:text-xl leading-relaxed text-wander-text/90">
            မိဘရိပ် Auto Service — ဝိုင်လဲ၊ ဘရိတ်၊ AC၊ ဘီးချိန်။ အချိန်ကြိုရွေးပြီး စောင့်စရာမလိုဘဲ ဝင်လာခဲ့ပါ။
          </p>
          <a
            href="#services"
            className="mt-8 inline-flex items-center rounded-full border-2 border-wander-dark px-8 py-3.5 text-sm font-semibold uppercase tracking-wide text-wander-dark hover:bg-wander-dark hover:text-white transition-colors"
          >
            Explore Services
          </a>
        </div>
      </div>

      <BookNowCutout />
    </section>
  )
}
