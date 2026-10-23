// The app PIN's resume lock, and where "Forgot your PIN?" goes from an action.
import { onMounted, onUnmounted, type Ref } from 'vue'
import { useRouter } from 'vue-router'
import { usePinStore, RESUME_LOCK_MS } from '@/stores/pin'
import { lockApp, settlePin } from '@/utils/requirePin'

export function usePinLock(role: Ref<string>) {
  const router = useRouter()
  const pin = usePinStore()

  /**
   * Lock the app when it comes back after sitting in the background. This is the
   * half of the PIN feature that covers *reads* — private messages, boarder phone
   * numbers, a student's uploaded school ID — none of which any per-action gate
   * can protect, because none of them are actions.
   *
   * `visibilitychange` is the cross-platform signal and works in the browser
   * during development.
   */
  function onVisibilityChange() {
    if (document.visibilityState === 'hidden') {
      pin.backgroundedAt = Date.now()
      return
    }
    const away = pin.backgroundedAt ? Date.now() - pin.backgroundedAt : 0
    pin.backgroundedAt = 0
    if (away > RESUME_LOCK_MS) void lockApp()
  }

  /**
   * The other half of the resume lock: the app being closed outright.
   *
   * `backgroundedAt` lives in memory, and `visibilitychange` does not fire on a
   * first paint, so a cold launch measured no time away and never locked —
   * swiping the app out of recents and reopening it walked straight into messages
   * and boarder records with the PIN never asked for. A launch is treated as
   * "away long enough" unconditionally. The one case that must not lock is having
   * just signed in, which AuthLayout marks as it goes.
   */
  function lockIfColdLaunch() {
    let authedHere = false
    try {
      authedHere = sessionStorage.getItem('accommo.authed.here') === '1'
    } catch {
      // Unreadable storage: fall through and ask for the PIN.
    }
    if (!authedHere) void lockApp()
  }

  onMounted(() => {
    document.addEventListener('visibilitychange', onVisibilityChange)
    // Answers "does this account have a PIN at all" once. requirePin() and
    // lockApp() both await pin.ensureReady(), which joins this same call.
    void pin.refresh()
    lockIfColdLaunch()
  })

  onUnmounted(() => {
    document.removeEventListener('visibilitychange', onVisibilityChange)
  })

  /**
   * "Forgot PIN?" from an ACTION prompt: the user is already inside and unlocked,
   * so send them to Settings where the reset lives. The resume lock never reaches
   * here — it cannot navigate out of the cover it is showing, so PinGate runs the
   * reset in place instead.
   */
  function goToSecuritySettings() {
    settlePin(false)
    void router.push(`/${role.value}/settings`)
  }

  return { goToSecuritySettings }
}
