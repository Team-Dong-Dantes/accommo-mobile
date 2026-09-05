import { defineBoot } from '#q-app'
import { applyTheme, getStoredTheme } from '@/utils/theme'

// Applied before mount so a user who picked dark doesn't see a light flash.
export default defineBoot(() => {
  applyTheme(getStoredTheme())
})
