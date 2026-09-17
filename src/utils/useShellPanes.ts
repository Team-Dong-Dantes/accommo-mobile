import { computed, type Component } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import type { ShellConfig } from '@/types/app-types'

/**
 * Which list belongs beside the screen you are on, in tablet mode.
 *
 * The map already existed. Every entry in a role's `secondaryPages`
 * (MainLayout.vue's SHELLS) carries a `back` route, because the header's back
 * button needs one — and "the screen this one came from" is exactly the pane
 * that should stay visible beside it on a wide screen. Writing a second table
 * would mean two answers to one question, and the two would drift the first time
 * someone added a screen.
 *
 * Not every `back` target is a list, though. Settings goes back to Profile, and
 * neither is a list of anything — putting Profile in a left pane beside Settings
 * would be two documents side by side, not a master and a detail. So only the
 * five routes below open a pane; every other screen fills the stage on its own.
 *
 * Messages is deliberately absent. Its detail is not a route at all — the thread
 * is a sibling of the list inside MessagesPage, opened by a `?c=` query — so the
 * page splits itself (see `.page-split` in app.scss) and would otherwise end up
 * rendered whole inside the narrow left pane, thread and all.
 */
const PANE_LISTS: readonly string[] = [
  '/manager/tenants',
  '/manager/properties',
  '/manager/notifications',
  '/student/discover',
  '/student/notifications',
]

/**
 * What the empty detail pane says while nothing is picked. Keyed by the list, so
 * it names the thing rather than saying "select an item".
 */
const EMPTY_HINT: Record<string, string> = {
  '/manager/tenants': 'Pick a tenant to see their details',
  '/manager/properties': 'Pick an accommodation to see its rooms and details',
  '/manager/notifications': 'Pick a notification to read it',
  '/student/discover': 'Pick a listing to see its rooms, photos and location',
  '/student/notifications': 'Pick a notification to read it',
}

export type ShellPanes =
  | { mode: 'single' }
  | { mode: 'split'; listPath: string; listComponent: Component; hint: string; detailOpen: boolean }

export function useShellPanes(
  config: () => ShellConfig,
  isTablet: () => boolean,
) {
  const route = useRoute()
  const router = useRouter()

  /**
   * The list route's page component, pulled straight out of the router so there
   * is no second import list to keep in step with the route files.
   *
   * Every path in PANE_LISTS is parameter-free, which is what makes this safe: a
   * component rendered here gets the *detail* route from useRoute(), not its
   * own, so a list that read `route.params` would read the wrong ones. None of
   * the seven do — MessagesPage is the only list in the app that calls
   * useRoute(), and Messages splits itself internally (see MessagesPage.vue)
   * rather than being companion-rendered. Re-check this before adding a path.
   */
  function componentFor(path: string): Component | null {
    const matched = router.resolve(path).matched
    const last = matched[matched.length - 1]
    const c = last?.components?.default
    return (c as Component | undefined) ?? null
  }

  return computed<ShellPanes>(() => {
    if (!isTablet()) return { mode: 'single' }

    const here = route.path

    // Already on the list itself: it takes the left pane and the right pane
    // waits. Landing on a list in tablet mode should not look different from
    // landing on it and then going back — same two panes, one of them empty.
    if (PANE_LISTS.includes(here)) {
      const c = componentFor(here)
      return c
        ? { mode: 'split', listPath: here, listComponent: c, hint: EMPTY_HINT[here] ?? '', detailOpen: false }
        : { mode: 'single' }
    }

    const entry = config().secondaryPages.find((e) =>
      typeof e.path === 'string' ? e.path === here : e.path.test(here),
    )
    const listPath = entry?.back
    if (!listPath || !PANE_LISTS.includes(listPath)) return { mode: 'single' }

    const c = componentFor(listPath)
    if (!c) return { mode: 'single' }

    return { mode: 'split', listPath, listComponent: c, hint: EMPTY_HINT[listPath] ?? '', detailOpen: true }
  })
}
