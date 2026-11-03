import Hero from './components/Hero'
import Services from './components/Services'
import Symptoms from './components/Symptoms'
import Brands from './components/Brands'
import Process from './components/Process'
import HowItWorks from './components/HowItWorks'
import AccountPerks from './components/AccountPerks'
import Faq from './components/Faq'
import Footer from './components/Footer'

export default function App() {
  return (
    <div className="min-h-screen bg-wander-bg flex flex-col items-center p-4 md:p-6">
      <div className="w-full max-w-[1600px] flex flex-col gap-4 md:gap-6">
        <Hero />
        <Services />
        <Symptoms />
        <Process />
        <Brands />
        <HowItWorks />
        <AccountPerks />
        <Faq />
        <Footer />
      </div>
    </div>
  )
}
