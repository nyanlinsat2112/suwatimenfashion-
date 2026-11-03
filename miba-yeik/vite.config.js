import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import tailwindcss from '@tailwindcss/vite'

// index.html = React landing page (Wander style)
// public/app.html, public/admin.html = existing Miba Yeik customer site + admin (copied as-is on build)
export default defineConfig({
  plugins: [react(), tailwindcss()],
})
