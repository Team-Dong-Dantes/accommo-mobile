// The signed-in user in the chrome: avatar and initials, the needs-checking
// dots, the notification and message stores, push, and scroll state.
import { AVATAR, resolveAsset } from '@/utils/cloudinaryUrl'
import { authUser, supabase } from '@/utils/supabase'
import { countLeasesAwaitingManager } from '@/api/leases'
import { initialsOf } from '@/utils/format'
import { loadProfileGaps } from '@/utils/profile'
import { onMounted, onUnmounted } from 'vue'
import { startPush } from '@/utils/push'
import type { createShellNav } from './nav'

export function createShellSession(ctx: ReturnType<typeof createShellNav>) {
  const { router, notifications, messagesStore, role, userInitials, profileImageUrl, tenantsNeedCheck, profileNeedsCheck, concernsNeedCheck, onScroll } = ctx
  onMounted(async () => {
    window.addEventListener('scroll', onScroll, true)
    window.addEventListener('accommo:avatar-change', onAvatarChange)
    window.addEventListener('accommo:profile-change', onProfileChange)
    document.querySelector('.q-page-container')?.addEventListener('scroll', onScroll)
    onScroll()
    try {
      const { data } = await authUser()
      const user = data?.user
      if (!user) return

      const metadata = user.user_metadata as Record<string, unknown> | undefined
      const picture =
        typeof metadata?.avatar_url === 'string'
          ? metadata.avatar_url
          : typeof metadata?.picture === 'string'
            ? metadata.picture
            : ''
      profileImageUrl.value = picture ? resolveAsset(picture, AVATAR) : null

      const { data: userData } = await supabase
        .from('users')
        .select('initials, full_name, avatar_url')
        .eq('id', user.id)
        .maybeSingle()

      const row = userData as { initials: string | null; full_name: string | null; avatar_url: string | null } | null
      userInitials.value =
        row?.initials || initialsOf(String(row?.full_name || metadata?.full_name || user.email || 'User'))

      // Fall back to the stored column when this session's metadata has no
      // picture — it can be stale or empty (avatar uploaded on another device,
      // or written straight to the database), which otherwise left the shell
      // showing initials despite a photo being on file.
      if (!picture && row?.avatar_url) profileImageUrl.value = resolveAsset(row.avatar_url, AVATAR)

      // Keeps users.avatar_url (the only copy anyone but this user can ever
      // read) in step with the auth session's own picture — a Google sign-in
      // never writes it directly, and a Cloudinary upload's write in
      // uploadAvatar() can't cover a photo change made on Google's side.
      if (picture && row?.avatar_url !== picture) {
        void supabase.from('users').update({ avatar_url: picture }).eq('id', user.id).then(() => undefined, () => undefined)
      }

      shellUserId = user.id
      void loadNeedsCheckDots(user.id)

      // Subscribes once for the session; the notifications page reuses the same
      // store, so a row marked read there clears this dot immediately.
      await notifications.start(user.id)
      // Same idea for the Messages tab's unread badge — MessagesPage.vue reuses
      // this same store instance, so start() here is a no-op once that page
      // also calls it (see the userId/channel guard in stores/messages.ts).
      await messagesStore.start(user.id)
      void startPush(role.value, router)

    } catch {
      userInitials.value = 'U'
    }
  })

  onUnmounted(() => {
    notifications.stop()
    messagesStore.stop()
    window.removeEventListener('scroll', onScroll, true)
    window.removeEventListener('accommo:avatar-change', onAvatarChange)
    window.removeEventListener('accommo:profile-change', onProfileChange)
    document.querySelector('.q-page-container')?.removeEventListener('scroll', onScroll)
  })

  // One existence-check query per dot, run once on shell mount. Deliberately
  // not realtime: these are low-frequency "does something need a look" flags,
  // not live counters — reopening the tab is enough to refresh them.
  //
  // The landlord/landlady's signals are exact-state checks (a lease sitting at 'pending', a
  // concern sitting at 'open') that self-clear the instant someone acts on the
  // row. Concerns has no per-student "seen this response" column, so the
  // student side uses a rolling time window instead (a concern resolved in the
  // last few days): still self-clearing (it ages out on its own), just on a
  // timer instead of a status flip.
  //
  // Discover had one too — "a listing accredited in the last week" — and it was
  // removed: with no seen state it stayed lit for the whole week after the
  // student had already looked, so it read as noise rather than news.
  const CONCERN_WINDOW_DAYS = 3

  async function loadNeedsCheckDots(userId: string) {
    const isManager = role.value === 'manager'
    const [tenants, docs, concerns, gaps] = await Promise.all([
      isManager
        ? countLeasesAwaitingManager(userId).then((count) => ({ count }))
        : Promise.resolve({ count: 0 }),
      supabase
        .from('verification_documents')
        .select('id', { count: 'exact', head: true })
        .eq('user_id', userId)
        .eq('status', 'rejected'),
      isManager
        ? supabase
            .from('concerns')
            .select('id, leases!inner(landlord_id)', { count: 'exact', head: true })
            .eq('status', 'open')
            .eq('leases.landlord_id', userId)
        : supabase
            .from('concerns')
            .select('id, leases!inner(student_id)', { count: 'exact', head: true })
            .in('status', ['resolved', 'rejected'])
            .gte('updated_at', new Date(Date.now() - CONCERN_WINDOW_DAYS * 86400000).toISOString())
            .eq('leases.student_id', userId),
      loadProfileGaps(userId, !isManager),
    ])
    tenantsNeedCheck.value = Boolean(tenants.count)
    // A rejected document, or something on the profile still blank (see CompleteProfilePage).
    profileNeedsCheck.value = Boolean(docs.count) || gaps.some((g) => g.needed)
    concernsNeedCheck.value = Boolean(concerns.count)
  }

  // CompleteProfilePage fires this after each saved step, so the dot clears without a relaunch.
  let shellUserId = ''
  function onProfileChange() {
    if (shellUserId) void loadNeedsCheckDots(shellUserId)
  }

  function onAvatarChange(event: Event) {
    const url = (event as CustomEvent<{ url: string }>).detail?.url
    if (url) profileImageUrl.value = resolveAsset(url)
  }

  return {
    CONCERN_WINDOW_DAYS,
    loadNeedsCheckDots,
    shellUserId,
    onProfileChange,
    onAvatarChange,
  }
}
