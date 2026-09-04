import { useQuasar } from 'quasar'

/**
 * Centralized toast notifications. Mirrors accommo-web's src/utils/notify.ts:
 * dark pill (grey-9), white text, status-colored icon, rounded via the
 * global `.custom-notify` class (src/css/app.scss). Use this everywhere
 * instead of raw $q.notify so the look stays consistent across the app.
 */
export function useNotify() {
  const $q = useQuasar()

  const base = {
    color: 'grey-9',
    textColor: 'white',
    position: 'top' as const,
    classes: 'custom-notify',
  }

  return {
    success: (message: string, caption = '') =>
      $q.notify({
        ...base,
        message,
        caption,
        icon: 'check_circle',
        iconColor: 'teal-4',
        timeout: 3500,
      }),
    error: (message: string, caption = '') =>
      $q.notify({
        ...base,
        message,
        caption,
        icon: 'error_outline',
        iconColor: 'red-4',
        timeout: 4500,
      }),
    warning: (message: string, caption = '') =>
      $q.notify({
        ...base,
        message,
        caption,
        icon: 'warning',
        iconColor: 'amber-4',
        timeout: 4500,
      }),
    info: (message: string, caption = '') =>
      $q.notify({
        ...base,
        message,
        caption,
        icon: 'info',
        iconColor: 'blue-4',
        timeout: 3500,
      }),
  }
}
