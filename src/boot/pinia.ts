import { defineBoot } from '#q-app'
import pinia from '@/stores'

// Install the single Pinia instance created in src/stores/index.ts so that
// every useXStore() call has an active Pinia instance. Without this, the app
// crashes with "[🍍]: no active Pinia instance was found" on first store use.
export default defineBoot(({ app }) => {
  app.use(pinia)
})
