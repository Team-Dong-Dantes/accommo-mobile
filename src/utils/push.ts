// Native push. The server side is the notification_push trigger plus the
// send-push edge function: every notifications row also goes to the
// recipient's devices. This file only registers the device and routes a tap.

import { Capacitor } from '@capacitor/core'
import { PushNotifications } from '@capacitor/push-notifications'
import type { Router } from 'vue-router'
import { supabase } from '@/utils/supabase'
import { resolveNotifLink, type Role } from '@/utils/notifications'
import { useNotificationsStore } from '@/stores/notifications'

let token = ''
let started = false

/** Ask for permission, register this device for the signed-in user, and route taps. */
export async function startPush(role: Role, router: Router) {
  if (!Capacitor.isNativePlatform() || started) return
  started = true

  await PushNotifications.addListener('registration', ({ value }) => {
    token = value
    void supabase.rpc('register_push_token', { p_token: value })
  })
  await PushNotifications.addListener('registrationError', (e) => {
    console.error('Push registration failed:', e.error)
  })
  // The plugin holds a tap that cold-started the app until this listener
  // exists, so tapping a push with the app closed still lands on the right screen.
  await PushNotifications.addListener('pushNotificationActionPerformed', ({ notification }) => {
    const d = (notification.data ?? {}) as Record<string, string | undefined>
    if (d.id) void useNotificationsStore().markRead(d.id)
    const to = resolveNotifLink(d.link_url, d.type, role, d.ref_id)
    void router.push(to ?? `/${role}/notifications`)
  })

  let perm = await PushNotifications.checkPermissions()
  if (perm.receive === 'prompt' || perm.receive === 'prompt-with-rationale') {
    perm = await PushNotifications.requestPermissions()
  }
  if (perm.receive === 'granted') await PushNotifications.register()
}

/** Sign-out: this device stops receiving the previous account's pushes. */
export async function stopPush() {
  if (!started) return
  started = false
  if (token) await supabase.from('push_tokens').delete().eq('token', token)
  token = ''
  await PushNotifications.removeAllListeners()
  await PushNotifications.unregister()
}
