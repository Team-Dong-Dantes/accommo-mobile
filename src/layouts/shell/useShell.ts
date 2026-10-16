// MainLayout's state: navigation (tabs, back bars, titles, transitions) and the
// signed-in session (avatar, badge dots, notification and message stores).
import { createShellNav } from './nav'
import { createShellSession } from './session'

export function useShell() {
  const nav = createShellNav()
  const session = createShellSession({ ...nav })
  return { ...nav, ...session }
}
