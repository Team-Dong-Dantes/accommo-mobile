import { defineBoot } from '#q-app'
import { Capacitor } from '@capacitor/core'
import { Keyboard } from '@capacitor/keyboard'

// On a real Android/iOS device (Capacitor), the onscreen keyboard overlays the
// WebView instead of resizing or panning it, so the layout keeps its height and
// nothing jumps when an input is focused. That is set by
// android:windowSoftInputMode="adjustNothing" in the AndroidManifest.
// Keyboard.setResizeMode() is NOT the lever: it is call.unimplemented() in the
// Android plugin and silently rejects, so it was never doing anything here.
//
// Nothing reads --m-kb or .kb-open at the moment. The register sheet used to
// shrink by the height, and later hid its action bar on the class; both were
// tried and both were worse than simply letting the keyboard cover the bar, so
// the layout no longer reacts to the keyboard at all. This stays because it is
// the hook any bottom bar would need if one ever does — the chat composer is the
// likely candidate — and it costs two listeners. Delete it if that never comes.
// The keyboard's Next/Enter key walks the form: next visible field, and from
// the last one it submits the form (Register's submit is "next step"). Without
// this Enter did nothing on most screens — implicit submission needs a submit
// button or a lone field, and most of the app's forms are inputs in a sheet,
// not a <form> at all. Off a <form>, the last field is left to its own
// @keyup.enter (Find, Verify, Change email), so those are untouched.
const TYPING = 'input:not([type=hidden]):not([type=checkbox]):not([type=radio]):not([type=file]):not([type=button]):not([type=submit]):not([type=range]), textarea'

function fieldsAround(el: HTMLElement): { next: HTMLElement | undefined; form: HTMLFormElement | null } {
  const form = el.closest('form')
  const scope = form ?? el.closest('.q-dialog, .q-page') ?? document.body
  const fields = [...scope.querySelectorAll<HTMLInputElement>(TYPING)]
    .filter((f) => f === el || (!f.disabled && !f.readOnly && f.getClientRects().length))
  return { next: fields[fields.indexOf(el as HTMLInputElement) + 1], form }
}

function onEnter(e: KeyboardEvent) {
  const el = e.target as HTMLElement
  // A textarea's Enter is a newline; QSelect's picks an option and prevents it.
  if (e.key !== 'Enter' || e.isComposing || e.defaultPrevented || !(el instanceof HTMLInputElement) || !el.matches(TYPING)) return
  const { next, form } = fieldsAround(el)
  if (next) {
    e.preventDefault()
    next.focus()
  } else if (form) {
    e.preventDefault()
    form.requestSubmit()
  }
}

// The key's label, set as the field gains focus so the keyboard opens with it.
function onFocus(e: FocusEvent) {
  const el = e.target as HTMLElement
  if (el instanceof HTMLInputElement && el.matches(TYPING) && !el.hasAttribute('enterkeyhint') && fieldsAround(el).next) {
    el.enterKeyHint = 'next'
  }
}

export default defineBoot(() => {
  document.addEventListener('keydown', onEnter)
  document.addEventListener('focusin', onFocus)

  if (!Capacitor.isNativePlatform()) return

  // Two facts, one source. The height is what the scrollers pad themselves by;
  // the class is what lets CSS ask the yes/no question, which a custom property
  // alone cannot answer in a selector.
  const setKb = (px: number) => {
    document.documentElement.style.setProperty('--m-kb', `${px}px`)
    document.documentElement.classList.toggle('kb-open', px > 0)
  }

  // Moving from one field to the next makes Android close and reopen the IME,
  // so the raw events arrive as hide-then-show a few milliseconds apart. Acting
  // on that hide drops the footer to the floor and hauls it straight back up —
  // the jump. Holding the hide briefly lets the following show cancel it, and a
  // real dismissal being 120ms late is not something anyone can see.
  let hideTimer: ReturnType<typeof setTimeout> | undefined

  void Keyboard.addListener('keyboardWillShow', (info) => {
    clearTimeout(hideTimer)
    setKb(info.keyboardHeight)
  })
  void Keyboard.addListener('keyboardWillHide', () => {
    clearTimeout(hideTimer)
    hideTimer = setTimeout(() => setKb(0), 120)
  })
})
