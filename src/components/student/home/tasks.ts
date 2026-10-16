// The student home's to-do list, one builder per kind of task. Pure: load()
// fetches the rows and pushes these in the order it always did, so equal-rank
// tasks still land where they did.
import { formatPeso, formatPesoExact, formatDate, formatMonth } from '@/utils/format'
import { BILL_TAG, isBillSettled, manilaToday, type LedgerRow } from '@/utils/payments'
import type { UtilityKey } from '@/utils/listings'
import { ago, listGaps, type ProfileGap } from '@/utils/profile'
import type { Task } from '@/components/shared/dashboard'
import type { Stay } from '@/components/student/dashboard'

type Standing = { reason: string | null; restrictions: string[] | null } | null

export function titleCase(raw: string | null | undefined) {
  if (!raw) return ''
  return raw.replace(/[_-]+/g, ' ').replace(/^\w/, (c) => c.toUpperCase())
}

/** OSAS has paused this student's applications (account_standing). */
export function standingTasks(standing: Standing): Task[] {
  const list: Task[] = []
  if (standing?.restrictions?.includes('apply')) {
    list.push({
      id: 'osas-apply',
      icon: 'lucide:shield-minus',
      kind: 'OSAS',
      label: 'OSAS has paused your room applications',
      hint: standing.reason || 'Contact OSAS to sort this out',
      when: '',
      action: 'Open OSAS',
      route: '/student/support',
      tone: 'danger',
      rank: 0,
    })
  }
  return list
}

/** Where verification stands: what to do about it, or that it is done. */
export function verificationTasks(verification: string, docRows: { status: string }[], standing: Standing): Task[] {
  const list: Task[] = []
  // Verification: whether they must act depends on what they have already
  // submitted, so the pending documents decide the wording and the action.
  if (verification !== 'verified') {
    const pendingDocs = docRows.filter((d) => d.status === 'pending').length

    if (verification === 'rejected' || verification === 'needs_resubmission' || verification === 'suspended') {
      const sentBack = verification === 'needs_resubmission'
      list.push({
        id: 'verify',
        icon: 'lucide:file-x',
        kind: 'OSAS',
        label: sentBack ? 'OSAS asked for new requirements' : verification === 'rejected' ? 'Your requirements were rejected' : 'Your account is suspended',
        hint: standing?.reason || (sentBack ? 'Upload them again to stay verified' : verification === 'rejected' ? 'Upload clearer copies to get verified' : 'Contact OSAS to sort this out'),
        when: '',
        action: verification === 'suspended' ? 'Open OSAS' : 'Re-upload requirements',
        route: '/student/support',
        tone: 'danger',
        rank: 1,
      })
    } else if (pendingDocs > 0) {
      list.push({
        id: 'verify',
        icon: 'lucide:hourglass',
        kind: 'OSAS',
        label: 'OSAS is reviewing your requirements',
        hint: `${pendingDocs} ${pendingDocs === 1 ? 'requirement' : 'requirements'} submitted`,
        when: '',
        action: '',
        route: '',
        tone: 'info',
        rank: 9,
      })
    } else {
      list.push({
        id: 'verify',
        icon: 'lucide:id-card',
        kind: 'OSAS',
        label: 'Finish your OSAS verification',
        hint: 'Landlords/Landladies can only accept verified students',
        when: '',
        action: 'Upload requirements',
        route: '/student/support',
        tone: 'warn',
        rank: 2,
      })
    }
  } else {
    list.push({
      id: 'verify',
      icon: 'lucide:shield-check',
      kind: 'OSAS',
      label: 'OSAS verified',
      hint: '',
      when: '',
      action: '',
      route: '',
      tone: 'done',
      rank: 99,
    })
  }
  return list
}

/** Profile fields still blank. */
export function profileTasks(missing: ProfileGap[]): Task[] {
  const list: Task[] = []
  if (missing.length) {
    list.push({
      id: 'profile',
      icon: 'lucide:user-round-pen',
      kind: 'Profile',
      label: 'Complete your profile',
      hint: `Add your ${listGaps(missing)}`,
      when: '',
      action: 'Continue',
      route: '/student/profile/complete',
      tone: 'warn',
      rank: 3,
    })
  }
  return list
}

/** An application the landlord/landlady has not decided yet. */
export function applicationTasks(leaseStatus: string | undefined, who: string): Task[] {
  const list: Task[] = []
  if (leaseStatus === 'pending') {
    list.push({
      id: 'application',
      icon: 'lucide:file-clock',
      kind: 'Application',
      label: `Your ${who} is reviewing your application`,
      hint: 'You will be told as soon as they decide',
      when: '',
      action: '',
      route: '',
      tone: 'info',
      rank: 8,
    })
  }
  return list
}

/** The current stay: advance and deposit, and the renewal window. */
export function stayTasks(stay: Stay | null, who: string): Task[] {
  const list: Task[] = []
  if (stay) {
    const moveIn = stay.moveIn
    if (moveIn) {
      const paid = moveIn.left <= 0.009
      list.push({
        id: 'move-in',
        icon: paid ? 'lucide:check-circle' : 'lucide:circle-dashed',
        kind: 'Move-in',
        label: 'Advance and deposit',
        hint: paid ? 'Paid' : `${formatPesoExact(moveIn.left)} of ${formatPesoExact(moveIn.due)} left`,
        when: '',
        action: paid ? '' : 'Pay now',
        route: '/student/payments',
        tone: paid ? 'done' : 'warn',
        rank: paid ? 99 : 2,
      })
    }

    // The countdown lives on the stay card; this row exists only once the
    // renewal window opens and there is actually something to do about it.
    const end = new Date(stay.endDate).getTime()
    const daysLeft = Number.isNaN(end) ? null : Math.ceil((end - Date.now()) / 86400000)
    if (stay.status === 'active' && daysLeft !== null && daysLeft >= 0 && daysLeft <= 30) {
      list.push({
        id: 'renewal',
        icon: 'lucide:calendar-clock',
        kind: 'Lease',
        label: `Your lease ends in ${daysLeft} ${daysLeft === 1 ? 'day' : 'days'}`,
        hint: `Talk to your ${who} if you want to renew`,
        when: '',
        action: `Message ${who}`,
        route: '/student/messages',
        tone: 'warn',
        rank: 5,
      })
    }
  }
  return list
}

/** Concerns filed against this stay, and whether they were answered. */
export function concernTasks(concernRows: { id: string; category: string; status: string; reported_at: string; manager_response: string | null }[] | null, who: string): Task[] {
  const list: Task[] = []
  for (const c of concernRows || []) {
    const answered = Boolean(c.manager_response)
    list.push({
      id: `concern-${c.id}`,
      icon: answered ? 'lucide:message-square-reply' : 'lucide:triangle-alert',
      kind: 'Your report',
      label: answered
        ? `Your ${who} replied about ${(titleCase(c.category) || 'your report').toLowerCase()}`
        : `${titleCase(c.category) || 'Concern'} still open`,
      hint: answered ? 'Read the reply and close it off' : `Waiting on your ${who}`,
      when: ago(c.reported_at),
      action: answered ? 'Read reply' : '',
      route: '/student/concerns',
      tone: answered ? 'warn' : 'info',
      rank: answered ? 3 : 7,
    })
  }
  return list
}

/** Utility bills posted and not yet paid. */
export function billTasks(billRows: { id: string; utility: string; month: string; amount: number; due_date: string; payments: { status: string; amount: number }[] | null }[] | null): Task[] {
  const list: Task[] = []
  for (const b of billRows ?? []) {
    if (isBillSettled(b.payments, Number(b.amount))) continue
    const overdue = b.due_date < manilaToday()
    list.push({
      id: `bill-${b.id}`,
      icon: 'lucide:receipt',
      kind: 'Utilities',
      label: `${BILL_TAG[b.utility as UtilityKey]} · ${formatPesoExact(Number(b.amount || 0))}`,
      hint: `${formatMonth(b.month)} · ${overdue ? 'overdue since' : 'due'} ${formatDate(b.due_date)}`,
      when: '',
      action: 'Pay now',
      route: '/student/payments',
      tone: overdue ? 'danger' : 'warn',
      rank: overdue ? 0 : 1,
    })
  }
  return list
}

/** Rent that is overdue (from the ledger). */
export function overdueRentTasks(due: LedgerRow | null): Task[] {
  const list: Task[] = []
  if (due?.month && due.state === 'overdue') {
    list.push({
      id: `payment-${due.month}`,
      icon: 'lucide:banknote',
      kind: 'Rent',
      label: `${formatPeso(due.balance)} is overdue`,
      hint: `Rent for ${formatMonth(due.month)}`,
      when: '',
      action: 'Pay now',
      route: '/student/payments',
      tone: 'danger',
      rank: 0,
    })
  }
  return list
}

/** Unread messages. */
export function unreadTasks(totalUnread: number, who: string): Task[] {
  const list: Task[] = []
  if (totalUnread > 0) {
    list.push({
      id: 'unread',
      icon: 'lucide:message-circle',
      kind: 'Messages',
      label: `${totalUnread} unread ${totalUnread === 1 ? 'message' : 'messages'}`,
      hint: `From your ${who}`,
      when: '',
      action: 'Open messages',
      route: '/student/messages',
      tone: 'warn',
      rank: 4,
    })
  }
  return list
}
