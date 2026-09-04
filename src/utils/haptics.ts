import { Capacitor } from '@capacitor/core'
import { Haptics, ImpactStyle, NotificationType } from '@capacitor/haptics'

// Thin, guarded haptics for native feel. Every call is a safe no-op on the
// web build and is best-effort on native, so it's fine to call from tap
// handlers in the shell. Wire these where a real native app would buzz —
// switching bottom tabs, opening the action menu, confirmations — and NOT on
// every tiny tap (that reads as janky instead of native).

const enabled = Capacitor.isNativePlatform()

async function run(action: () => Promise<void>) {
  if (!enabled) return
  try {
    await action()
  } catch {
    // Haptics are cosmetic; never let a plugin failure block UI.
  }
}

/** Short light pulse — tab change, opening a menu, picking an option. */
export function hapticLight() {
  void run(() => Haptics.impact({ style: ImpactStyle.Light }))
}

/** Slightly stronger — confirm / consequential choices. */
export function hapticMedium() {
  void run(() => Haptics.impact({ style: ImpactStyle.Medium }))
}

/** Soft "task succeeded" tick. */
export function hapticSuccess() {
  void run(() => Haptics.notification({ type: NotificationType.Success }))
}

/** Gentle "that failed / needs attention" tick. */
export function hapticWarning() {
  void run(() => Haptics.notification({ type: NotificationType.Warning }))
}
