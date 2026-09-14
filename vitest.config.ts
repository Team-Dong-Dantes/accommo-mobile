import { fileURLToPath, URL } from 'node:url'
import { defineConfig } from 'vitest/config'

// Vitest runs outside the Quasar build, so it does not inherit the `@` alias
// from the generated tsconfig. Without this, any test importing a module that
// uses `@/...` fails to resolve — which is why the first two test files stuck to
// relative imports and avoided anything touching `@/stores`.
//
// No env defines are needed: src/utils/supabase.ts already falls back to its
// in-memory stub when VITE_SUPABASE_URL is absent, so importing it in a test is
// harmless (it logs one warning).
export default defineConfig({
  resolve: {
    alias: {
      '@': fileURLToPath(new URL('./src', import.meta.url)),
    },
  },
})
