import { useState } from 'react'
import { CarFront, Search, User, Bell, Menu, X } from 'lucide-react'
import { APP, NAV_LINKS, PROMO_COUNT } from '../site'

export default function Navbar() {
  const [open, setOpen] = useState(false)

  return (
    <nav className="absolute top-0 left-0 right-0 z-50 px-8 py-8 lg:px-16">
      <div className="flex items-center justify-between gap-6">
        {/* Logo */}
        <a href="#" className="flex items-center gap-2.5 text-wander-dark hover:text-orange-500 transition-colors">
          <CarFront size={28} />
          <span className="whitespace-nowrap font-bold text-lg sm:text-xl uppercase tracking-widest">Miba Yeik</span>
        </a>

        {/* Center links */}
        <ul className="hidden lg:flex items-center gap-8">
          {NAV_LINKS.map((l) => (
            <li key={l.label}>
              <a
                href={l.href}
                className={`${l.accent ? 'text-wander-orange' : 'text-wander-dark/90'} font-medium hover:text-orange-500 transition-colors`}
              >
                {l.label}
              </a>
            </li>
          ))}
        </ul>

        {/* Icons */}
        <div className="flex items-center gap-5 sm:gap-6 text-wander-dark">
          <a href={`${APP}#services`} aria-label="ဝန်ဆောင်မှု ရှာရန်" className="hover:text-orange-500 transition-colors">
            <Search size={22} />
          </a>
          <a href={`${APP}#account`} aria-label="Account" className="hover:text-orange-500 transition-colors">
            <User size={22} />
          </a>
          <a href={`${APP}#posts`} aria-label="Promotion" className="relative hover:text-orange-500 transition-colors">
            <Bell size={22} />
            {PROMO_COUNT > 0 && (
              <span className="absolute -top-1.5 -right-2 flex h-4 min-w-4 items-center justify-center rounded-full bg-wander-orange px-1 text-[10px] font-bold leading-none text-white">
                {PROMO_COUNT}
              </span>
            )}
          </a>
          <button
            type="button"
            onClick={() => setOpen((o) => !o)}
            aria-label="Menu"
            aria-expanded={open}
            className="lg:hidden hover:text-orange-500 transition-colors"
          >
            {open ? <X size={24} /> : <Menu size={24} />}
          </button>
        </div>
      </div>

      {/* Mobile menu */}
      {open && (
        <ul className="lg:hidden mt-6 grid gap-1 rounded-3xl bg-wander-bg/95 p-4 shadow-sm ring-1 ring-black/5 backdrop-blur">
          {NAV_LINKS.map((l) => (
            <li key={l.label}>
              <a
                href={l.href}
                onClick={() => setOpen(false)}
                className={`${l.accent ? 'text-wander-orange' : 'text-wander-dark/90'} block rounded-2xl px-4 py-2.5 font-medium hover:text-orange-500 transition-colors`}
              >
                {l.label}
              </a>
            </li>
          ))}
        </ul>
      )}
    </nav>
  )
}
