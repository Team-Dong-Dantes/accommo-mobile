import { computed, ref } from 'vue'
import { supabase } from '@/utils/supabase'
import { formatDate, formatMonth, formatPesoExact } from '@/utils/format'
import { BILL_TAG, manilaToday, toLedger, type LedgerRow } from '@/utils/payments'
import type { UtilityKey } from '@/utils/listings'

/** One tick box in a pay sheet (PayItemList.vue). */
export interface PayItem {
  key: string
  name: string
  note: string
  late: boolean
  amount: number
  on: boolean
  toggle: () => void
}

/** What a sheet starts with ticked: a rejected transfer being sent again. */
export interface PayPick {
  months: number
  billIds: string[]
  deposit: boolean
}

// Everything owed on a stay as tick boxes: the student's Pay and the
// landlord/landlady's Log a payment both pick from this, and both submit the
// picked items to record_payments(), which applies the money in the same order
// (rent oldest first, bills by due date, then the deposit).
export function usePayItems(leaseId: () => string, startDate: () => string | undefined, settleOnly: () => boolean) {
  const loading = ref(false)
  const ledger = ref<LedgerRow[]>([])
  const billUtility = ref<Record<string, UtilityKey>>({})
  const months = ref(0)
  const billIds = ref<string[]>([])
  const deposit = ref(false)
  const today = () => manilaToday()

  const rentRows = computed(() => ledger.value.filter((r) => r.kind === 'rent' && r.balance > 0.009))
  const billRows = computed(() => ledger.value.filter((r) => r.kind === 'bill' && r.balance > 0.009 && r.billId))
  const depositRow = computed(() => (settleOnly() ? null : ledger.value.find((r) => r.kind === 'deposit' && r.balance > 0.009) ?? null))

  const picked = computed(() => [
    ...rentRows.value.slice(0, months.value),
    ...billRows.value.filter((r) => billIds.value.includes(r.billId as string)),
    ...(deposit.value && depositRow.value ? [depositRow.value] : []),
  ])
  const total = computed(() => Math.round(picked.value.reduce((s, r) => s + r.balance, 0) * 100) / 100)

  function note(r: LedgerRow): string {
    const left = r.balance + 0.009 < r.due ? `${formatPesoExact(r.balance)} left of ${formatPesoExact(r.due)} · ` : ''
    if (r.state === 'overdue') {
      const days = Math.max(1, Math.round((new Date(`${today()}T00:00:00`).getTime() - new Date(`${r.dueDate}T00:00:00`).getTime()) / 86400000))
      return `${left}${days} day${days === 1 ? '' : 's'} late`
    }
    if (r.kind === 'rent' && r.dueDate === startDate()) return `${left}Due on moving in`
    if ((r.dueDate ?? '') > today() && r.kind === 'rent') return `${left}Pay ahead · due ${formatDate(r.dueDate)}`
    return `${left}Due ${formatDate(r.dueDate)}`
  }
  const monthName = (m: string | null) => formatMonth(m).split(' ')[0]

  // Rent already due plus the next two months, so paying ahead stays a short list.
  const items = computed<PayItem[]>(() => {
    const due = rentRows.value.filter((r) => (r.dueDate ?? '') <= today()).length
    const rent = rentRows.value.slice(0, Math.max(due, 0) + 2).map((r, i) => ({
      key: `rent-${r.month}`,
      name: r.dueDate === startDate() ? `${monthName(r.month)} rent · advance` : `${monthName(r.month)} rent`,
      note: note(r),
      late: r.state === 'overdue',
      amount: r.balance,
      on: i < months.value,
      // Months go in order: ticking one ticks those before it, unticking one unticks those after.
      toggle: () => { months.value = i < months.value ? i : i + 1 },
    }))
    const dep = depositRow.value
      ? [{
          key: 'deposit',
          name: 'Deposit',
          note: depositNote(depositRow.value),
          late: false,
          amount: depositRow.value.balance,
          on: deposit.value,
          toggle: () => { deposit.value = !deposit.value },
        }]
      : []
    const bills = billRows.value.map((r) => {
      const id = r.billId as string
      return {
        key: `bill-${id}`,
        name: `${BILL_TAG[billUtility.value[id] ?? 'water'] ?? 'Utility bill'} · ${monthName(r.month)}`,
        note: note(r),
        late: r.state === 'overdue',
        amount: r.balance,
        on: billIds.value.includes(id),
        toggle: () => { billIds.value = billIds.value.includes(id) ? billIds.value.filter((x) => x !== id) : [...billIds.value, id] },
      }
    })
    return [...rent, ...dep, ...bills]
  })
  function depositNote(r: LedgerRow): string {
    return r.balance + 0.009 < r.due ? `${formatPesoExact(r.balance)} left · paid once, on moving in` : 'Paid once, on moving in'
  }

  /** Fresh from the database; what is due now starts ticked unless `pick` says otherwise. */
  async function load(pick?: PayPick | null) {
    loading.value = true
    try {
      const [{ data: rows, error }, { data: bills }] = await Promise.all([
        supabase.rpc('lease_ledger', { p_lease: leaseId() }),
        supabase.from('utility_bills').select('id, utility').eq('lease_id', leaseId()),
      ])
      if (error) throw error
      ledger.value = toLedger(rows)
      billUtility.value = Object.fromEntries((bills ?? []).map((b) => [b.id, b.utility as UtilityKey]))
      if (pick) {
        months.value = Math.min(pick.months, rentRows.value.length)
        billIds.value = pick.billIds.filter((id) => billRows.value.some((r) => r.billId === id))
        deposit.value = pick.deposit && !!depositRow.value
        return
      }
      const due = rentRows.value.filter((r) => (r.dueDate ?? '') <= today() || r.state === 'overdue').length
      // An ended stay is settled as a whole: everything left starts ticked.
      months.value = settleOnly() ? rentRows.value.length : rentRows.value.length ? Math.max(due, 1) : 0
      billIds.value = billRows.value.filter((r) => settleOnly() || r.state === 'overdue').map((r) => r.billId as string)
      deposit.value = !!depositRow.value
    } finally {
      loading.value = false
    }
  }

  return { loading, ledger, billUtility, months, billIds, deposit, depositRow, rentRows, picked, total, items, load }
}
