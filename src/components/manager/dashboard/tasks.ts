// The landlord/landlady dashboard's to-do list, one builder per kind of task.
// Pure: load() fetches the rows and concatenates these in the order they have
// always been pushed, so equal-rank tasks still land where they did.
import { ago, listGaps, type ProfileGap } from '@/utils/profile'
import type { Task } from '@/components/shared/dashboard'

export function titleCase(raw: string | null | undefined) {
  if (!raw) return ''
  return raw.replace(/[_-]+/g, ' ').replace(/^\w/, (c) => c.toUpperCase())
}

/** Expired and soon-expiring permits, and how many of each per accommodation. */
export function permitTasks(
  docRows: { id: string; doc_type: string; expires_at: string | null; accommodation_id: string }[],
  accName: Map<string, string>,
) {
  const expiredByAcc = new Map<string, number>()
  const expiringSoonByAcc = new Map<string, number>()
  const items: Task[] = []

  {
    const now = Date.now()
    const soon = now + 30 * 24 * 60 * 60 * 1000

    for (const d of docRows) {
      if (!d.expires_at) continue
      const t = new Date(d.expires_at).getTime()
      const where = accName.get(d.accommodation_id) || 'Accommodation'
      if (t < now) {
        expiredByAcc.set(d.accommodation_id, (expiredByAcc.get(d.accommodation_id) || 0) + 1)
        items.push({
          id: `doc-${d.id}`,
          icon: 'lucide:file-warning',
          kind: 'OSAS',
          label: `${titleCase(d.doc_type)} expired`,
          hint: `${where} — accreditation is at risk until this is renewed`,
          when: ago(d.expires_at),
          action: 'Upload renewal',
          route: '/manager/osas',
          tone: 'danger',
          rank: 1,
        })
      } else if (t < soon) {
        expiringSoonByAcc.set(d.accommodation_id, (expiringSoonByAcc.get(d.accommodation_id) || 0) + 1)
        items.push({
          id: `doc-soon-${d.id}`,
          icon: 'lucide:calendar-clock',
          kind: 'OSAS',
          label: `${titleCase(d.doc_type)} expires soon`,
          hint: `${where} — renew it before it lapses`,
          when: '',
          action: 'Renew now',
          route: '/manager/osas',
          tone: 'warn',
          rank: 3,
        })
      }
    }
  }
  return { items, expiredByAcc, expiringSoonByAcc }
}

/** Rooms that don't say how utilities are paid, grouped per accommodation. */
export function utilityTasks(
  roomRows: { accommodation_id: string; water_billing: string | null; electric_billing: string | null; wifi_billing: string | null }[],
  accName: Map<string, string>,
): Task[] {
  const items: Task[] = []
  // Rooms that don't yet say how utilities are paid — every room from before
  // utilities were per room. Students see nothing for them, and a draft
  // can't be submitted until they're set, so it's a task, not a footnote.
  const unsetByAcc = new Map<string, number>()
  for (const r of roomRows) {
    if (r.water_billing && r.electric_billing && r.wifi_billing) continue
    unsetByAcc.set(r.accommodation_id, (unsetByAcc.get(r.accommodation_id) || 0) + 1)
  }
  for (const [accId, count] of unsetByAcc) {
    items.push({
      id: `utilities-${accId}`,
      icon: 'lucide:plug-zap',
      kind: 'Utilities',
      label: `Set utilities on ${count} room${count === 1 ? '' : 's'}`,
      hint: `${accName.get(accId) || 'Accommodation'} — students can't see how water, power and Wi-Fi are paid`,
      when: '',
      action: 'Set utilities',
      route: `/manager/properties/${accId}`,
      tone: 'warn',
      rank: 3,
    })
  }
  return items
}

/** Open concerns from boarders. */
export function concernTasks(concernRows: { id: string; category: string; reported_at: string; leases: unknown }[] | null): Task[] {
  const items: Task[] = []
  for (const c of concernRows || []) {
    const lease = c.leases as unknown as {
      users: { full_name: string } | null
      rooms: { accommodations: { name: string } | null } | null
    } | null
    const who = lease?.users?.full_name || 'A boarder'
    const where = lease?.rooms?.accommodations?.name
    items.push({
      id: `concern-${c.id}`,
      icon: 'lucide:message-square-warning',
      kind: 'Student concern',
      label: `${titleCase(c.category) || 'Concern'} reported by ${who}`,
      hint: where ? `At ${where} — awaiting your reply` : 'Awaiting your reply',
      when: ago(c.reported_at),
      action: 'Reply',
      route: '/manager/support',
      tone: 'danger',
      rank: 0,
    })
  }
  return items
}

/** One grouped row for payments waiting to be verified. */
export function paymentTasks(paymentsToVerify: number | null): Task[] {
  const items: Task[] = []
  // One grouped row, like "Set utilities": a busy month would otherwise bury
  // concerns and applications under a row per payment.
  if (paymentsToVerify) {
    items.push({
      id: 'payments-to-verify',
      icon: 'lucide:receipt',
      kind: 'Payments',
      label: `Verify ${paymentsToVerify} payment${paymentsToVerify === 1 ? '' : 's'}`,
      hint: 'Students are waiting for these to be marked paid',
      when: '',
      action: 'Verify',
      route: '/manager/tenants?tab=payments',
      tone: 'warn',
      rank: 2,
    })
  }
  return items
}

/** Applications and leave requests waiting on a decision. */
export function peopleTasks(
  peopleRows: { id: string; status: string; start_date: string; leave_requested_at: string | null; users: unknown; rooms: unknown }[] | null,
): Task[] {
  const items: Task[] = []
  for (const l of peopleRows || []) {
    const who =
      (l.users as unknown as { full_name: string } | null)?.full_name || 'A student'
    const room = l.rooms as unknown as {
      room_number: string | null
      accommodations: { name: string } | null
    } | null
    const where = [room?.room_number ? `Room ${room.room_number}` : '', room?.accommodations?.name]
      .filter(Boolean)
      .join(' · ')
    if (l.status === 'pending') {
      items.push({
        id: `app-${l.id}`,
        icon: 'lucide:user-plus',
        kind: 'Application',
        label: `${who} wants to move in`,
        hint: where || 'Waiting on your decision',
        when: ago(l.start_date),
        action: 'Review application',
        route: `/manager/tenant/${l.id}`,
        tone: 'warn',
        rank: 2,
      })
    } else {
      items.push({
        id: `leave-${l.id}`,
        icon: 'lucide:door-open',
        kind: 'Leave request',
        label: `${who} wants to move out`,
        hint: where || 'Waiting on your decision',
        when: ago(l.leave_requested_at),
        action: 'Review request',
        route: `/manager/tenant/${l.id}`,
        tone: 'warn',
        rank: 2,
      })
    }
  }
  return items
}

/** OSAS has hidden the listings (account_standing). */
export function standingTasks(standing: { reason: string | null; restrictions: string[] | null } | null): Task[] {
  const items: Task[] = []
  if (standing?.restrictions?.includes('listings')) {
    items.push({
      id: 'osas-listings',
      icon: 'lucide:eye-off',
      kind: 'OSAS',
      label: 'OSAS has hidden your listings',
      hint: standing.reason || 'Students cannot see your accommodations for now',
      when: '',
      action: 'Contact OSAS',
      route: '/manager/support',
      tone: 'danger',
      rank: 0,
    })
  }
  return items
}

/** Profile fields still missing on an older account. */
export function profileTasks(missing: ProfileGap[]): Task[] {
  const items: Task[] = []
  if (missing.length) {
    items.push({
      id: 'profile',
      icon: 'lucide:user-round-pen',
      kind: 'Profile',
      label: 'Complete your profile',
      hint: `Add your ${listGaps(missing)}`,
      when: '',
      action: 'Continue',
      route: '/manager/profile/complete',
      tone: 'warn',
      rank: 3,
    })
  }
  return items
}
