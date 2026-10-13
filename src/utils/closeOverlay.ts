import type { Router } from 'vue-router'

/**
 * Closes a thread or ticket opened over its list by query (`?c=`, `?t=`). Back
 * returns where the user came from — the room they pressed "Message" on, a
 * notification — not always the list. Only when another item of the same list
 * is behind it (desktop picks one after another), or nothing is, does it fall
 * to the list itself.
 */
export function closeOverlay(router: Router, key: string) {
  const back = window.history.state?.back
  const path = router.currentRoute.value.path
  const [backPath, backQuery] = typeof back === 'string' ? back.split('?') : []
  const sameListItem = backPath === path && new URLSearchParams(backQuery).has(key)
  if (back && !sameListItem) router.back()
  else void router.push({ path })
}
