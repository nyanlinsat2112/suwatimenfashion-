import { ArrowUpRight } from 'lucide-react'
import { APP } from '../site'

// Inverted-radius cutout sitting in the hero's bottom-right corner.
// The two 40px squares carry a radial-gradient whose transparent quarter-circle
// faces the hero, so the cutout melts into the container's straight edges.
const corner = 'pointer-events-none absolute w-10 h-10 bg-[radial-gradient(circle_at_0_0,transparent_40px,#f3efe8_40px)]'

export default function BookNowCutout() {
  return (
    <div className="absolute bottom-0 right-0 z-30 bg-wander-cutout rounded-tl-[40px] pt-8 pl-10 pb-8 pr-10">
      <div className={`${corner} bottom-full right-0`} />
      <div className={`${corner} bottom-0 right-full`} />

      <a href={`${APP}#booking`} className="group flex items-center gap-4 text-wander-dark">
        <span className="flex w-12 h-12 items-center justify-center rounded-full bg-black/5 hover:bg-black/10 group-hover:bg-black/10 transition-colors">
          <ArrowUpRight size={22} />
        </span>
        <span className="flex flex-col">
          <span className="text-lg font-medium">Book Now</span>
          <span className="text-sm opacity-60">Online booking &gt;</span>
        </span>
      </a>
    </div>
  )
}
