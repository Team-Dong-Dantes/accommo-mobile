// One month's rent across the landlord/landlady's boarders: loading it,
// stepping months, the tiles and what each shows, and the payment sheets.
import { type CollectionLease, type CollectionLedgerRow, type CollectionPayment, type Collections, monthCollections } from '@/utils/collections'
import { type Seed } from './model'
import { type Task } from '@/components/shared/dashboard'
import { UTILITIES, type UtilityKey } from '@/utils/listings'
import { authUser, supabase } from '@/utils/supabase'
import { computed, ref, watch } from 'vue'
import { errorMessage } from '@/utils/errors'
import { fetchLandlordMoney } from '@/api/landlordMoney'
import { formatMonth } from '@/utils/format'
import { manilaToday } from '@/utils/payments'
import { useRouter } from 'vue-router'

export function createCollections(ctx: Seed) {
  const { props, emit } = ctx
  const router = useRouter()

  const loading = ref(false)
  const error = ref('')
  const leases = ref<CollectionLease[]>([])
  const ledger = ref<CollectionLedgerRow[]>([])
  const payments = ref<CollectionPayment[]>([])
  const billUtility = ref<Record<string, UtilityKey>>({})
  const billed = ref(new Set<string>())
  const propertyId = ref('all')

  const today = computed(() => manilaToday())
  const thisMonth = computed(() => `${today.value.slice(0, 7)}-01`)
  // The month on screen; null until the arrows move it, so it follows the date.
  const stepped = ref<string | null>(null)
  const viewMonth = computed(() => stepped.value ?? thisMonth.value)
  // Back as far as the first rent anyone was ever billed.
  const earliestMonth = computed(() => {
    const first = ledger.value.map((r) => (r.dueDate ?? '').slice(0, 7)).filter(Boolean).sort()[0]
    return first && `${first}-01` < thisMonth.value ? `${first}-01` : thisMonth.value
  })
  function step(by: number) {
    const d = new Date(`${viewMonth.value}T00:00:00`)
    d.setMonth(d.getMonth() + by)
    const next = `${d.toLocaleDateString('en-CA').slice(0, 7)}-01`
    stepped.value = next >= thisMonth.value ? null : next < earliestMonth.value ? earliestMonth.value : next
    picked.value = null
  }

  const properties = computed(() => {
    const seen = new Map<string, string>()
    for (const l of leases.value) if (l.accommodationId) seen.set(l.accommodationId, l.accommodationName)
    return [...seen.entries()].map(([id, name]) => ({ id, name }))
  })
  const propertyOptions = computed(() => [{ value: 'all', label: 'All properties' }, ...properties.value.map((p) => ({ value: p.id, label: p.name }))])

  function collectionsFor(id: string, month: string = viewMonth.value) {
    const ls = id === 'all' ? leases.value : leases.value.filter((l) => l.accommodationId === id)
    const ids = new Set(ls.map((l) => l.id))
    return monthCollections(ls, ledger.value.filter((r) => ids.has(r.leaseId)), payments.value.filter((p) => ids.has(p.leaseId)), month, today.value, billUtility.value, billed.value)
  }
  const col = computed(() => (leases.value.length || !loading.value ? collectionsFor(propertyId.value) : null))
  // Today's month across every property: the tab badge and the bills nag.
  const live = computed(() => (leases.value.length ? collectionsFor('all', thisMonth.value) : null))
  const expected = computed(() => (col.value ? col.value.collected + col.value.toConfirm + col.value.overdue + col.value.toCome : 0))
  const allIn = computed(() => !!col.value && expected.value > 0 && col.value.toConfirm + col.value.overdue + col.value.toCome < 0.01)

  // The four tiles are radios: the one picked chooses the list. With no pick it
  // opens on what needs doing first.
  type Tile = 'confirm' | 'late' | 'paid' | 'coming'
  const picked = ref<Tile | null>(null)
  const tiles = computed(() => {
    const c = col.value
    if (!c) return []
    return [
      { key: 'confirm' as Tile, label: 'To confirm', count: c.confirm.length, amount: c.toConfirm, tone: 'info' },
      { key: 'late' as Tile, label: 'Overdue', count: c.late.length, amount: c.overdue, tone: 'danger' },
      { key: 'paid' as Tile, label: 'Paid', count: c.paid.length, amount: c.collected, tone: 'success' },
      { key: 'coming' as Tile, label: 'Still to come', count: c.coming.length, amount: c.toCome, tone: 'muted' },
    ]
  })
  const shownTile = computed<Tile>(() => picked.value ?? tiles.value.find((t) => t.key !== 'paid' && t.count)?.key ?? 'paid')
  const nothingLine = computed(() => ({ confirm: 'Nothing waiting on you.', late: 'Nobody is late.', coming: 'Nothing else due this month.', paid: 'Nobody has paid yet.' })[shownTile.value])

  // The search box narrows the rows, never the hero or tiles above them.
  const shown = computed<Collections>(() => {
    const c = col.value as Collections
    const q = props.query.trim().toLowerCase()
    if (!q) return c
    const hit = (l: CollectionLease) => [l.studentName, l.roomLabel, l.accommodationName].some((t) => t.toLowerCase().includes(q))
    return { ...c, confirm: c.confirm.filter((x) => hit(x.lease)), late: c.late.filter((x) => hit(x.lease)), coming: c.coming.filter((x) => hit(x.lease)), paid: c.paid.filter(hit), past: c.past.filter((x) => hit(x.lease)) }
  })

  // Things to set up or do, as rows of the dashboard's "Needs attention" list.
  const tasks = computed<Task[]>(() => {
    const out: Task[] = []
    if (payoutLoaded.value && !payout.value) {
      out.push({ id: 'payout', icon: 'lucide:smartphone', kind: 'Payments', label: 'Add where boarders send money', hint: 'GCash, Maya or bank. Until then they are told to ask you.', when: '', action: 'Add details', route: 'payout', tone: 'warn', rank: 0 })
    }
    if (live.value?.unposted.tenants) {
      out.push({ id: 'bills', icon: 'lucide:zap', kind: 'Bills', label: `Post ${formatMonth(live.value.month).split(' ')[0]} bills`, hint: unpostedLine.value, when: '', action: 'Post bills', route: 'bills', tone: 'warn', rank: 1 })
    }
    return out
  })
  function onTask(route: string) {
    if (route === 'payout') payoutOpen.value = true
    else if (route === 'bills') billsOpen.value = true
  }
  const unpostedLine = computed(() => {
    const u = live.value?.unposted
    if (!u) return ''
    const names = UTILITIES.filter((x) => u.utilities.includes(x.key)).map((x) => x.label.toLowerCase())
    return `${names.join(' and ').replace(/^./, (s) => s.toUpperCase())} · ${u.tenants} boarder${u.tenants === 1 ? '' : 's'}`
  })
  function leavingLabel(l: CollectionLease): string {
    return l.leaveDate ? `Leaving ${new Date(`${l.leaveDate}T00:00:00`).toLocaleDateString('en-PH', { month: 'short', day: 'numeric' })}` : 'Leaving'
  }
  function waitLabel(days: number): string {
    return days <= 0 ? 'Today' : `${days} day${days === 1 ? '' : 's'}`
  }

  async function load() {
    loading.value = true
    error.value = ''
    try {
      const m = await fetchLandlordMoney()
      leases.value = m.leases
      ledger.value = m.ledger
      payments.value = m.payments
      billUtility.value = m.billUtility
      billed.value = m.billed
    } catch (e) {
      error.value = errorMessage(e, 'Something went wrong.')
    } finally {
      loading.value = false
    }
  }

  // Where tenants send money (landlord_payout), for the strip at the bottom.
  const payout = ref<{ gcash_number: string | null; maya_number: string | null; bank_name: string | null; bank_account_number: string | null } | null>(null)
  const payoutLoaded = ref(false)
  const payoutOpen = ref(false)
  async function loadPayout() {
    const { data: auth } = await authUser()
    const { data } = await supabase
      .from('landlord_payout')
      .select('gcash_number,maya_number,bank_name,bank_account_number')
      .eq('landlord_id', auth?.user?.id ?? '')
      .maybeSingle()
    payout.value = data && (data.gcash_number || data.maya_number || data.bank_account_number) ? data : null
    payoutLoaded.value = true
  }
  const mask = (n: string) => `${n.slice(0, 4)} ••• ${n.slice(-4)}`
  const payoutWays = computed(() => {
    const p = payout.value
    if (!p) return ''
    const ways = [p.gcash_number && 'GCash', p.maya_number && 'Maya', p.bank_account_number && (p.bank_name || 'bank'), 'cash'].filter(Boolean) as string[]
    return ways.length > 1 ? `${ways.slice(0, -1).join(', ')} or ${ways[ways.length - 1]}` : ways[0]!
  })
  const payoutLine = computed(() => {
    const p = payout.value
    if (!p) return ''
    return [p.gcash_number && `GCash ${mask(p.gcash_number)}`, p.maya_number && `Maya ${mask(p.maya_number)}`, p.bank_account_number && `${p.bank_name || 'Bank'} ${mask(p.bank_account_number)}`]
      .filter(Boolean)
      .join(' · ')
  })

  watch(() => props.version, () => { void load(); void loadPayout() }, { immediate: true })
  // Payments waiting on the landlord/landlady, across every property: the tab's badge.
  watch(() => collectionsFor('all', thisMonth.value).confirm.length, (n) => emit('count', n), { immediate: true })

  const reviewOpen = ref(false)
  const reviewId = ref<string | null>(null)
  function review(id: string) {
    reviewId.value = id
    reviewOpen.value = true
  }
  const logOpen = ref(false)
  const logLease = ref<CollectionLease | null>(null)
  function logFor(l: CollectionLease) {
    logLease.value = l
    logOpen.value = true
  }
  const billsOpen = ref(false)
  function changed() {
    void load()
    emit('changed')
  }

  return {
    router,
    loading,
    error,
    leases,
    ledger,
    payments,
    billUtility,
    billed,
    propertyId,
    today,
    thisMonth,
    stepped,
    viewMonth,
    earliestMonth,
    step,
    properties,
    propertyOptions,
    collectionsFor,
    col,
    live,
    expected,
    allIn,
    picked,
    tiles,
    shownTile,
    nothingLine,
    shown,
    tasks,
    onTask,
    unpostedLine,
    leavingLabel,
    waitLabel,
    load,
    payout,
    payoutLoaded,
    payoutOpen,
    loadPayout,
    mask,
    payoutWays,
    payoutLine,
    reviewOpen,
    reviewId,
    review,
    logOpen,
    logLease,
    logFor,
    billsOpen,
    changed,
  }
}
