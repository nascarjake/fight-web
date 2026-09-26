import react from '@vitejs/plugin-react';
import tailwindcss from '@tailwindcss/postcss';
import { defineConfig } from 'vite';
import { fileURLToPath, URL } from 'node:url';

export default defineConfig({
  // A relative base keeps assets working both at the repository Pages URL and
  // when the built site is opened from another static host.
  base: './',
  plugins: [react()],
  resolve: {
    alias: {
      '@': fileURLToPath(new URL('./', import.meta.url)),
    },
  },
  css: { postcss: { plugins: [tailwindcss()] } },
});
