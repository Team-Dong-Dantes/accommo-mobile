import { defineBoot } from '#q-app'
import { Icon, addCollection } from '@iconify/vue'
import { icons as lucideIcons } from '@iconify-json/lucide'

// One icon family, registered up front. Every screen authors against
// `lucide:<name>`; without this they render as blank boxes (an addIcon-only
// boot never resolved unbundled sets).
//
// Twenty-five Material glyphs used to be pasted in below as inline SVG paths,
// kept alive purely for the auth flow — the last corner of the app still on a
// second icon family. Auth now speaks Lucide like everything else, so the paths
// went with it.
addCollection(lucideIcons)

export default defineBoot(({ app }) => {
  app.component('IconifyIcon', Icon)
})
