import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

// Where the admin API lives. Default is the plain-HTTP dev server. When the
// admin API is run through run_server.ps1 (HTTPS, DEBUG off) set
//   ADMIN_API_TARGET=https://127.0.0.1:8001
// before `npm run dev`. `secure: false` below only relaxes certificate
// checking for that https loopback hop (127.0.0.1 on this same machine);
// the browser -> Vite hop and the API's own TLS are unaffected.
const target = process.env.ADMIN_API_TARGET || 'http://127.0.0.1:8001';

export default defineConfig({
  plugins: [react()],
  server: {
    port: 5173,
    // Points only at csa_admin_api (staff-facing process), never at
    // csa_mobile_api. csa_admin_api runs on 8001 — see
    // csa_backend/csa_admin_api/.env.
    proxy: {
      '/api': {
        target,
        changeOrigin: true,
        secure: false
      },
      '/media': {
        target,
        changeOrigin: true,
        secure: false
      }
    }
  }
});
