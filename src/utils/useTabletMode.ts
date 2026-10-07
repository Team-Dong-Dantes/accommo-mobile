import { readonly, ref } from 'vue'

/**
 * Which of the app's two shells is on screen.
 *
 * Landscape on a 10" tablet and up is the only thing that gets the two-pane
 * layout. Everything else — every phone in either orientation, and a tablet held
 * in portrait — keeps the phone shell, because that is what a tall narrow column
 * of cards is designed for. A phone in landscape is around 850px, so it stays
 * below the line on purpose: there is no room for two panes there, only for a
 * cramped one.
 *
 * `orientation` rather than a second width test because it is the question being
 * asked. A portrait tablet is 800px wide — wide enough to pass any width test
 * worth writing, and still the wrong shape for panes.
 *
 * One matchMedia for the whole app, evaluated once at module load. Every caller
 * shares this ref: the shell, the rail and each page that splits itself all ask
 * the same question, and a listener each would be 20 listeners for one boolean.
 */
const QUERY = '(min-width: 900px) and (orientation: landscape)'

const mql = typeof window !== 'undefined' ? window.matchMedia(QUERY) : null
const state = ref(mql?.matches ?? false)

mql?.addEventListener('change', (e) => {
  state.value = e.matches
})

/** True only in tablet landscape. Read-only — the media query owns it. */
export const isTablet = readonly(state)

/**
 * The web build's layout: the admin console's 68px rail carrying the hamburger's
 * items, and two-half desk cards. Every landscape tablet gets it, not only a
 * 1200px browser window, so a real tablet looks exactly like the web build on
 * one. Must match the tablet media queries in app.scss.
 */
export const isDesktop = isTablet

export function useTabletMode() {
  return { isTablet }
}
