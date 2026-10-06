<template>
  <q-dialog :model-value="modelValue" position="bottom" @update:model-value="emit('update:modelValue', $event)">
    <q-card class="ps-sheet">
      <span class="ps-grip" aria-hidden="true" />
      <div class="ps-progress" aria-hidden="true"><span class="ps-progress-fill" :style="{ width: step === 1 ? '50%' : '100%' }" /></div>

      <div class="ps-head">
        <button v-if="step === 2" type="button" class="ps-back" aria-label="Back to what you're paying" @click="step = 1">
          <IconifyIcon icon="lucide:chevron-left" width="20" />
        </button>
        <span class="ps-head-body">
          <span class="ps-step">{{ landlord ? 'Log a payment' : 'Pay' }} · step {{ step }} of 2</span>
          <h3 class="ps-title">
            {{ step === 1 ? (landlord ? 'What was paid?' : 'What are you paying?') : (landlord ? 'How was it paid?' : 'How did you pay?') }}
          </h3>
        </span>
        <span v-if="step === 2" class="ps-head-amt">{{ formatPesoExact(payAmount) }}</span>
      </div>
      <span v-if="subtitle && step === 1" class="ps-sub">{{ subtitle }}</span>

      <div v-if="loading" class="ps-body ps-center"><q-spinner size="24px" color="primary" /></div>
      <div v-else-if="!rentRows.length && !bills.length && !moveIn.length" class="ps-body ps-center">
        <IconifyIcon icon="lucide:circle-check" width="32" class="ps-done-icon" />
        <p class="ps-empty">Nothing is owed on this stay right now.</p>
      </div>

      <!-- Step 1: what is being paid. Every item is a card you tap to pick. -->
      <template v-else-if="step === 1">
        <div class="ps-body">
          <!-- Rent is one card: how many months, oldest first (months are paid in order). -->
          <div v-if="rentRows.length" class="ps-card" :class="{ 'ps-card--on': months > 0 }">
            <button type="button" class="ps-card-main" :aria-pressed="months > 0" @click="toggleRent">
              <span class="ps-radio" :class="{ 'ps-radio--on': months > 0 }"><IconifyIcon v-if="months > 0" icon="lucide:check" width="13" /></span>
              <span class="ps-card-body">
                <span class="ps-card-name">Rent</span>
                <span class="ps-card-note" :class="{ 'ps-late': rentLate }">{{ rentRange }}</span>
              </span>
              <span class="ps-card-amt">{{ formatPesoExact(months > 0 ? rentTotal : rentRows[0]!.balance) }}</span>
            </button>
            <div v-if="months > 0" class="ps-stepper">
              <span class="ps-stepper-label">Months</span>
              <button type="button" class="ps-stepper-btn" :disabled="months <= 1" aria-label="One month less" @click="months--">
                <IconifyIcon icon="lucide:minus" width="16" />
              </button>
              <span class="ps-stepper-value">{{ months }}</span>
              <button type="button" class="ps-stepper-btn" :disabled="months >= rentRows.length" aria-label="One month more" @click="months++">
                <IconifyIcon icon="lucide:plus" width="16" />
              </button>
            </div>
          </div>

          <button
            v-for="b in bills"
            :key="b.id"
            type="button"
            class="ps-card ps-card-main"
            :class="{ 'ps-card--on': billIds.includes(b.id) }"
            :aria-pressed="billIds.includes(b.id)"
            @click="toggle(billIds, b.id)"
          >
            <span class="ps-radio" :class="{ 'ps-radio--on': billIds.includes(b.id) }"><IconifyIcon v-if="billIds.includes(b.id)" icon="lucide:check" width="13" /></span>
            <span class="ps-card-body">
              <span class="ps-card-name">{{ b.label }}</span>
              <span class="ps-card-note" :class="{ 'ps-late': b.overdue }">{{ b.overdue ? 'Overdue since' : 'Due' }} {{ formatDate(b.dueDate) }}{{ b.partly ? ' · part paid' : '' }}</span>
            </span>
            <span class="ps-card-amt">{{ formatPesoExact(b.balance) }}</span>
          </button>

          <button
            v-for="m in moveIn"
            :key="m.kind"
            type="button"
            class="ps-card ps-card-main"
            :class="{ 'ps-card--on': moveInPicked.includes(m.kind) }"
            :aria-pressed="moveInPicked.includes(m.kind)"
            @click="toggle(moveInPicked, m.kind)"
          >
            <span class="ps-radio" :class="{ 'ps-radio--on': moveInPicked.includes(m.kind) }"><IconifyIcon v-if="moveInPicked.includes(m.kind)" icon="lucide:check" width="13" /></span>
            <span class="ps-card-body">
              <span class="ps-card-name">{{ m.kind === 'advance' ? 'Advance' : 'Deposit' }}</span>
              <span class="ps-card-note">{{ m.partly ? 'Part paid' : 'Paid once, on moving in' }}</span>
            </span>
            <span class="ps-card-amt">{{ formatPesoExact(m.balance) }}</span>
          </button>

          <div v-if="payLess" class="ps-card ps-less">
            <label class="ps-field">
              <span class="ps-label">Amount{{ landlord ? ' received' : ' you are paying now' }}</span>
              <span class="ps-money">
                <span class="ps-money-sign">₱</span>
                <input v-model.number="amount" type="number" :min="minAmount" :max="total" step="0.01" inputmode="decimal" class="ps-money-input" />
              </span>
              <span class="ps-hint">Goes to the picked items from the top; the rest stays owed.<template v-if="!landlord"> At least {{ formatPesoExact(minAmount) }}.</template></span>
            </label>
            <label v-if="!landlord && amount + 0.009 < total" class="ps-field">
              <span class="ps-label">When will you pay the rest? (optional)</span>
              <input v-model="promiseDate" type="date" :min="manilaToday()" class="ps-input" />
            </label>
          </div>
        </div>

        <div class="ps-foot">
          <div class="ps-total">
            <span class="ps-total-label">{{ payLess ? `Paying now · of ${formatPesoExact(total)}` : 'Total' }}</span>
            <button v-if="total > 0 && (payLess || canPayLess)" type="button" class="ps-link" @click="payLess ? (payLess = false) : startPayLess()">
              {{ payLess ? 'Pay all' : landlord ? 'Received less' : 'Pay less' }}
            </button>
          </div>
          <span class="ps-total-amt">{{ formatPesoExact(payAmount) }}</span>
          <q-btn unelevated rounded no-caps color="primary" class="ps-submit" :disable="!(payAmount > 0)" @click="next">
            Continue <IconifyIcon icon="lucide:arrow-right" width="18" class="ps-submit-icon" />
          </q-btn>
        </div>
      </template>

      <!-- Step 2: how it was paid. -->
      <template v-else>
        <div class="ps-body">
          <div class="ps-methods" role="radiogroup" aria-label="Payment method">
            <button
              v-for="m in METHODS"
              :key="m"
              type="button"
              role="radio"
              class="ps-method"
              :class="{ 'ps-method--on': method === m, 'ps-method--wide': m === 'others' }"
              :aria-checked="method === m"
              @click="method = m"
            >
              <IconifyIcon :icon="METHOD_ICON[m]" width="20" />
              <span>{{ PAYMENT_METHOD_LABEL[m] }}</span>
              <IconifyIcon v-if="method === m" icon="lucide:circle-check" width="16" class="ps-method-check" />
            </button>
          </div>

          <div v-if="!landlord" class="ps-card ps-panel">
            <template v-if="method === 'cash'">
              <p class="ps-panel-text">
                <IconifyIcon icon="lucide:hand-coins" width="18" />
                Hand it over in person. Your {{ who }} confirms it once received.
              </p>
            </template>
            <template v-else>
              <div v-if="payTo" class="ps-payto">
                <span class="ps-payto-body">
                  <span class="ps-label">Send to</span>
                  <span class="ps-payto-number">{{ payTo.number }}</span>
                  <span v-if="payTo.name" class="ps-payto-name">{{ payTo.name }}</span>
                </span>
                <button type="button" class="ps-copy" @click="copyText(payTo.number)">
                  <IconifyIcon icon="lucide:copy" width="14" /> Copy
                </button>
              </div>
              <p v-else-if="!payout" class="ps-hint ps-panel-row">Your {{ who }} hasn't added payment details yet — ask them where to send it.</p>
              <p v-if="payout?.note" class="ps-hint ps-panel-row">{{ payout.note }}</p>

              <label class="ps-field ps-panel-row">
                <span class="ps-label">Reference number</span>
                <input v-model="reference" type="text" class="ps-input" :inputmode="method === 'gcash' ? 'numeric' : 'text'" :placeholder="method === 'gcash' ? '13-digit GCash reference' : 'Reference number'" />
                <span v-if="referenceProblem(method, reference)" class="ps-hint ps-late">{{ referenceProblem(method, reference) }}</span>
              </label>
              <div class="ps-field ps-panel-row">
                <span class="ps-label">Screenshot of the receipt</span>
                <span class="ps-file" :class="{ 'ps-file--chosen': proofUrl }">
                  <img v-if="proofPreview" :src="proofPreview" alt="" class="ps-file-thumb" />
                  <IconifyIcon v-else icon="lucide:image-plus" width="18" />
                  <span class="ps-file-text">{{ uploading ? 'Uploading…' : proofUrl ? 'Attached · tap to replace' : 'Attach a screenshot' }}</span>
                  <input type="file" accept="image/*" class="ps-file-input" :disabled="uploading" @change="onProof" />
                </span>
              </div>
            </template>
            <label class="ps-field ps-panel-row">
              <span class="ps-label">Note (optional)</span>
              <input v-model="note" type="text" maxlength="300" class="ps-input" placeholder="e.g. The rest after my allowance comes in" />
            </label>
          </div>
        </div>

        <div class="ps-foot">
          <q-btn
            unelevated
            rounded
            no-caps
            color="primary"
            class="ps-submit"
            :loading="submitting"
            :disable="uploading"
            :label="`${landlord ? 'Log' : 'Submit'} ${formatPesoExact(payAmount)}`"
            @click="submit"
          />
          <p v-if="!landlord" class="ps-foot-note">Your {{ who }} confirms it once the money arrives.</p>
        </div>
      </template>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import { Icon as IconifyIcon } from '@iconify/vue'
import { supabase } from '@/utils/supabase'
import { errorMessage } from '@/utils/errors'
import { useNotify } from '@/utils/notify'
import { uploadSecureDocument } from '@/utils/upload'
import { formatDate, formatPesoExact, landlordTitle, PAYMENT_METHOD_LABEL } from '@/utils/format'
import { BILL_TAG, fileFingerprint, manilaToday, minPayment, normalizeReference, referenceProblem, toLedger, type LedgerRow } from '@/utils/payments'
import type { UtilityKey } from '@/utils/listings'

// One sheet for everything owed on a stay — the student's "Pay" and the
// landlord/landlady's "Log a payment". Rent months are chips (how many to pay),
// bills and the advance/deposit are tick boxes, and the whole lot goes to
// record_payments as one transfer.
const props = defineProps<{
  modelValue: boolean
  leaseId: string
  role: 'student' | 'landlord'
  /** For "Send to" (student only). */
  landlordId?: string
  allowPartial?: boolean
  partialMinPct?: number
  subtitle?: string
  /** An ended stay: only rent and bills are left to settle. */
  settleOnly?: boolean
}>()
const emit = defineEmits<{ 'update:modelValue': [boolean]; submitted: [] }>()
const notify = useNotify()
const landlord = computed(() => props.role === 'landlord')

const METHODS = ['gcash', 'maya', 'bank', 'cash', 'others'] as const
type Method = (typeof METHODS)[number]
const METHOD_ICON: Record<Method, string> = {
  gcash: 'lucide:smartphone',
  maya: 'lucide:wallet',
  bank: 'lucide:landmark',
  cash: 'lucide:banknote',
  others: 'lucide:circle-ellipsis',
}

const loading = ref(false)
const ledger = ref<LedgerRow[]>([])
const billMeta = ref<Record<string, { utility: UtilityKey }>>({})
const payout = ref<{ gcash_number: string | null; gcash_name: string | null; maya_number: string | null; maya_name: string | null; bank_name: string | null; bank_account_number: string | null; bank_account_name: string | null; note: string | null } | null>(null)

// The student's landlord/landlady, titled by their sex ("your landlady").
const landlordSex = ref<string | null>(null)
const who = computed(() => landlordTitle(landlordSex.value).toLowerCase())

const months = ref(0)
const billIds = ref<string[]>([])
const moveInPicked = ref<('advance' | 'deposit')[]>([])
const payLess = ref(false)
const amount = ref(0)
const method = ref<Method>('gcash')
const reference = ref('')
const proofUrl = ref('')
const proofHash = ref('')
const proofPreview = ref('')
const uploading = ref(false)
const note = ref('')
const promiseDate = ref('')
const submitting = ref(false)
/** 1: what is being paid · 2: how it was paid. */
const step = ref<1 | 2>(1)

const today = () => manilaToday()
const rentRows = computed(() => ledger.value.filter((r) => r.kind === 'rent' && r.balance > 0.009))
const bills = computed(() =>
  ledger.value
    .filter((r) => r.kind === 'bill' && r.balance > 0.009 && r.billId)
    .map((r) => {
      const u = billMeta.value[r.billId as string]?.utility
      return {
        id: r.billId as string,
        label: `${u ? BILL_TAG[u] : 'Bill'} · ${shortMonth(r.month)}`,
        dueDate: r.dueDate ?? '',
        overdue: r.state === 'overdue',
        partly: r.balance + 0.009 < r.due,
        balance: r.balance,
      }
    }),
)
const moveIn = computed(() =>
  (props.settleOnly ? [] : ledger.value)
    .filter((r): r is LedgerRow & { kind: 'advance' | 'deposit' } => (r.kind === 'advance' || r.kind === 'deposit') && r.balance > 0.009)
    .map((r) => ({ kind: r.kind, balance: r.balance, partly: r.balance + 0.009 < r.due })),
)

// The picked items in the order the money is applied to them (the database
// uses the same order): rent, bills by due date, advance, deposit.
const picked = computed(() => [
  ...rentRows.value.slice(0, months.value),
  ...ledger.value.filter((r) => r.kind === 'bill' && billIds.value.includes(r.billId as string)),
  ...(props.settleOnly ? [] : ledger.value.filter((r) => (r.kind === 'advance' || r.kind === 'deposit') && moveInPicked.value.includes(r.kind))),
])
const total = computed(() => Math.round(picked.value.reduce((s, r) => s + r.balance, 0) * 100) / 100)
const minAmount = computed(() => {
  const first = picked.value[0]
  if (!first || landlord.value) return 0.01
  return Math.min(total.value, minPayment(first, Boolean(props.allowPartial), props.partialMinPct ?? 10))
})
const canPayLess = computed(() => landlord.value || minAmount.value + 0.009 < total.value)
const payAmount = computed(() => (payLess.value ? Number(amount.value) || 0 : total.value))

// Rent is one card: the oldest `months` months still owed (months stay in order).
const rentTotal = computed(() => Math.round(rentRows.value.slice(0, months.value).reduce((t, r) => t + r.balance, 0) * 100) / 100)
const rentLate = computed(() => rentRows.value.slice(0, Math.max(months.value, 1)).some((r) => r.state === 'overdue'))
const rentRange = computed(() => {
  const rows = rentRows.value
  if (!months.value) return `${shortMonth(rows[0]?.month, true)} is next · tap to add rent`
  const first = rows[0]
  const last = rows[months.value - 1]
  const range = months.value === 1 ? shortMonth(first?.month, true) : `${shortMonth(first?.month)} – ${shortMonth(last?.month, true)}`
  const late = rows.slice(0, months.value).filter((r) => r.state === 'overdue').length
  const part = first && first.balance + 0.009 < first.due ? ` · ${formatPesoExact(first.balance)} left on ${shortMonth(first.month)}` : ''
  return `${range}${late ? ` · ${late} overdue` : ''}${part}`
})
// Tapping the rent card turns it off, or back on at the months it had.
let lastMonths = 1
function toggleRent() {
  if (months.value) {
    lastMonths = months.value
    months.value = 0
  } else {
    months.value = Math.min(lastMonths, rentRows.value.length)
  }
}
function toggle<T>(list: T[], v: T) {
  const i = list.indexOf(v)
  if (i >= 0) list.splice(i, 1)
  else list.push(v)
}

function shortMonth(m: string | null | undefined, withYear = false): string {
  if (!m) return ''
  return new Date(`${m.slice(0, 10)}T00:00:00`).toLocaleDateString('en-PH', withYear ? { month: 'short', year: 'numeric' } : { month: 'short' })
}

const payTo = computed(() => {
  const p = payout.value
  if (!p) return null
  if (method.value === 'gcash' && p.gcash_number) return { number: p.gcash_number, name: p.gcash_name }
  if (method.value === 'maya' && p.maya_number) return { number: p.maya_number, name: p.maya_name }
  if (method.value === 'bank' && p.bank_account_number) return { number: p.bank_account_number, name: [p.bank_name, p.bank_account_name].filter(Boolean).join(' · ') }
  return null
})
async function copyText(text: string) {
  try {
    await navigator.clipboard.writeText(text)
    notify.success('Copied.')
  } catch {
    notify.error('Could not copy — long-press the number instead.')
  }
}

function startPayLess() {
  amount.value = minAmount.value
  payLess.value = true
}

// Fresh each time it opens: what's owed now, with what is already due picked.
watch(
  () => props.modelValue,
  async (open) => {
    if (!open || !props.leaseId) return
    loading.value = true
    months.value = 0
    billIds.value = []
    moveInPicked.value = []
    payLess.value = false
    step.value = 1
    method.value = landlord.value ? 'cash' : 'gcash'
    reference.value = ''
    proofUrl.value = ''
    proofHash.value = ''
    proofPreview.value = ''
    note.value = ''
    promiseDate.value = ''
    try {
      const [{ data: rows, error }, { data: billRows }, payoutResult] = await Promise.all([
        supabase.rpc('lease_ledger', { p_lease: props.leaseId }),
        supabase.from('utility_bills').select('id, utility').eq('lease_id', props.leaseId),
        !landlord.value && props.landlordId
          ? supabase
              .from('landlord_payout')
              .select('gcash_number, gcash_name, maya_number, maya_name, bank_name, bank_account_number, bank_account_name, note')
              .eq('landlord_id', props.landlordId)
              .maybeSingle()
          : Promise.resolve({ data: null }),
      ])
      if (error) throw error
      ledger.value = toLedger(rows)
      billMeta.value = Object.fromEntries((billRows ?? []).map((b) => [b.id, { utility: b.utility as UtilityKey }]))
      payout.value = payoutResult.data
      if (!landlord.value && props.landlordId) {
        const { data: person } = await supabase.from('users').select('sex').eq('id', props.landlordId).maybeSingle()
        landlordSex.value = person?.sex ?? null
      }
      // Rent due by today (at least the oldest month), overdue bills, and an
      // unpaid advance/deposit start picked.
      const due = rentRows.value.filter((r) => (r.dueDate ?? '') <= today() || r.state === 'overdue').length
      // An ended stay is settled as a whole: everything left starts picked.
      months.value = props.settleOnly ? rentRows.value.length : rentRows.value.length ? Math.max(due, 1) : 0
      billIds.value = bills.value.filter((b) => props.settleOnly || b.overdue).map((b) => b.id)
      moveInPicked.value = moveIn.value.map((m) => m.kind)
    } catch (e) {
      notify.error(errorMessage(e, 'Could not load what is owed.'))
    } finally {
      loading.value = false
    }
  },
  { immediate: true },
)

async function onProof(event: Event) {
  const input = event.target as HTMLInputElement
  const file = input.files?.[0]
  if (!file) return
  uploading.value = true
  try {
    const [url, hash] = await Promise.all([uploadSecureDocument(file), fileFingerprint(file)])
    proofUrl.value = url
    proofHash.value = hash ?? ''
    proofPreview.value = URL.createObjectURL(file)
  } catch (e) {
    notify.error(errorMessage(e, 'Could not upload the proof image.'))
  } finally {
    uploading.value = false
    input.value = ''
  }
}

// What step 1 must get right before step 2. The database checks each of
// these too; saying so here saves a round trip.
function amountProblem(): string | null {
  if (!picked.value.length) return 'Pick at least one month or item.'
  const pay = Math.round(payAmount.value * 100) / 100
  if (!(pay > 0)) return 'Enter an amount.'
  if (pay > total.value + 0.009) return `That is more than what you picked (${formatPesoExact(total.value)}).`
  if (pay + 0.009 < minAmount.value) {
    return minAmount.value >= total.value
      ? `Pay the full ${formatPesoExact(total.value)} — your ${who.value} hasn't turned on partial payments.`
      : `Pay at least ${formatPesoExact(minAmount.value)}.`
  }
  return null
}
function next() {
  const problem = amountProblem()
  if (problem) return notify.error(problem)
  step.value = 2
}

async function submit() {
  if (submitting.value || uploading.value) return
  const problem = amountProblem()
  if (problem) {
    step.value = 1
    return notify.error(problem)
  }
  const pay = Math.round(payAmount.value * 100) / 100
  const ref = normalizeReference(reference.value)
  if (!landlord.value && method.value !== 'cash') {
    if (!ref) return notify.error('Enter the reference number, or switch the method to Cash.')
    const problem = referenceProblem(method.value, ref)
    if (problem) return notify.error(problem)
    if (!proofUrl.value) return notify.error('Attach a screenshot of the receipt, or switch the method to Cash.')
  }

  submitting.value = true
  try {
    const partial = pay + 0.009 < total.value
    const { error } = await supabase.rpc('record_payments', {
      p_lease: props.leaseId,
      p_months: months.value,
      p_bills: billIds.value,
      p_advance: !props.settleOnly && moveInPicked.value.includes('advance'),
      p_deposit: !props.settleOnly && moveInPicked.value.includes('deposit'),
      p_method: method.value,
      ...(partial ? { p_amount: pay } : {}),
      ...(ref && !landlord.value && method.value !== 'cash' ? { p_reference: ref } : {}),
      ...(proofUrl.value && method.value !== 'cash' ? { p_proof_url: proofUrl.value } : {}),
      ...(proofHash.value && method.value !== 'cash' ? { p_proof_hash: proofHash.value } : {}),
      ...(note.value.trim() ? { p_note: note.value.trim() } : {}),
      ...(partial && promiseDate.value ? { p_promise_date: promiseDate.value } : {}),
    })
    if (error) throw error
    notify.success(landlord.value ? 'Payment logged.' : 'Payment submitted for confirmation.')
    emit('update:modelValue', false)
    emit('submitted')
  } catch (e) {
    notify.error(errorMessage(e, 'Could not submit this payment.'))
  } finally {
    submitting.value = false
  }
}

</script>

<style scoped>
/* One fixed size for both steps: the sheet never jumps between them. The
   middle scrolls; the head and the footer (total, button) stay put. */
.ps-sheet {
  display: flex;
  width: 100%;
  max-width: 480px;
  height: min(640px, 85vh);
  flex-direction: column;
  margin: 0 auto;
  padding: 10px var(--m-page-gutter) calc(14px + env(safe-area-inset-bottom));
  overflow: hidden;
  border-radius: var(--m-radius-lg, var(--m-radius)) var(--m-radius-lg, var(--m-radius)) 0 0;
}
.ps-grip {
  display: block;
  width: 40px;
  height: 4px;
  flex: 0 0 auto;
  margin: 0 auto 10px;
  border-radius: 999px;
  background: var(--m-border);
}
.ps-progress {
  height: 3px;
  flex: 0 0 auto;
  margin-bottom: 14px;
  border-radius: 999px;
  background: var(--m-border);
  overflow: hidden;
}
.ps-progress-fill {
  display: block;
  height: 100%;
  border-radius: inherit;
  background: var(--m-primary);
  transition: width 0.25s ease;
}

.ps-head {
  display: flex;
  flex: 0 0 auto;
  align-items: center;
  gap: 8px;
}
.ps-head-body {
  display: flex;
  min-width: 0;
  flex: 1;
  flex-direction: column;
  gap: 2px;
}
.ps-step {
  color: var(--m-muted);
  font-size: 11.5px;
  font-weight: 700;
  letter-spacing: 0.04em;
  text-transform: uppercase;
}
.ps-title {
  margin: 0;
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 20px;
  font-weight: 700;
  line-height: 1.2;
}
.ps-sub {
  flex: 0 0 auto;
  margin-top: 2px;
  color: var(--m-muted);
  font-size: 13px;
}
.ps-back {
  display: flex;
  width: 36px;
  height: 36px;
  flex: 0 0 auto;
  align-items: center;
  justify-content: center;
  margin-left: -8px;
  border: 0;
  border-radius: 999px;
  background: none;
  color: var(--m-ink);
  cursor: pointer;
}
.ps-head-amt {
  flex: 0 0 auto;
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 18px;
  font-weight: 700;
  font-variant-numeric: tabular-nums;
}

.ps-body {
  display: flex;
  min-height: 0;
  flex: 1;
  flex-direction: column;
  gap: 10px;
  margin: 14px calc(-1 * var(--m-page-gutter)) 0;
  padding: 0 var(--m-page-gutter) 12px;
  overflow-y: auto;
}
.ps-center {
  align-items: center;
  justify-content: center;
}
.ps-done-icon {
  color: var(--m-success);
}
.ps-empty {
  margin: 0;
  color: var(--m-muted);
  font-size: 14px;
  text-align: center;
}

/* Item cards: the whole card is the tap target. */
.ps-card {
  display: flex;
  flex: 0 0 auto;
  flex-direction: column;
  border: 1.5px solid var(--m-border);
  border-radius: var(--m-radius);
  background: var(--m-surface);
  transition: border-color 0.15s ease, background 0.15s ease;
}
.ps-card--on {
  border-color: var(--m-primary);
  background: var(--m-primary-soft, rgba(18, 194, 153, 0.08));
}
.ps-card-main {
  display: flex;
  width: 100%;
  min-height: 60px;
  flex-direction: row;
  align-items: center;
  gap: 12px;
  padding: 12px 14px;
  border-radius: var(--m-radius);
  background: transparent;
  color: inherit;
  cursor: pointer;
  font: inherit;
  text-align: left;
}
button.ps-card-main:not(.ps-card) {
  border: 0;
}
.ps-radio {
  display: flex;
  width: 22px;
  height: 22px;
  flex: 0 0 auto;
  align-items: center;
  justify-content: center;
  border: 2px solid var(--m-border);
  border-radius: 999px;
  color: #fff;
}
.ps-radio--on {
  border-color: var(--m-primary);
  background: var(--m-primary);
}
.ps-card-body {
  display: flex;
  min-width: 0;
  flex: 1;
  flex-direction: column;
  gap: 2px;
}
.ps-card-name {
  color: var(--m-ink);
  font-size: 15px;
  font-weight: 700;
}
.ps-card-note {
  color: var(--m-muted);
  font-size: 12.5px;
}
.ps-card-amt {
  flex: 0 0 auto;
  color: var(--m-ink);
  font-size: 15px;
  font-weight: 700;
  font-variant-numeric: tabular-nums;
}
.ps-late {
  color: var(--m-danger);
  font-weight: 600;
}

.ps-stepper {
  display: flex;
  align-items: center;
  gap: 10px;
  margin: 0 14px;
  padding: 10px 0 12px 34px;
  border-top: 1px solid var(--m-border);
}
.ps-stepper-label {
  flex: 1;
  color: var(--m-muted);
  font-size: 13px;
  font-weight: 600;
}
.ps-stepper-btn {
  display: flex;
  width: 36px;
  height: 36px;
  align-items: center;
  justify-content: center;
  border: 1px solid var(--m-border);
  border-radius: 999px;
  background: var(--m-surface);
  color: var(--m-ink);
  cursor: pointer;
}
.ps-stepper-btn:disabled {
  opacity: 0.35;
  cursor: default;
}
.ps-stepper-value {
  min-width: 24px;
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 18px;
  font-weight: 700;
  text-align: center;
  font-variant-numeric: tabular-nums;
}

.ps-less {
  gap: 12px;
  padding: 14px;
  border-style: dashed;
}
.ps-field {
  display: flex;
  flex-direction: column;
  gap: 6px;
}
.ps-label {
  color: var(--m-muted);
  font-size: 11.5px;
  font-weight: 700;
  letter-spacing: 0.03em;
  text-transform: uppercase;
}
.ps-hint {
  margin: 0;
  color: var(--m-muted);
  font-size: 12px;
  line-height: 1.45;
}
.ps-input {
  min-height: 46px;
  padding: 0 12px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius-sm);
  background-color: var(--m-surface);
  color: var(--m-ink);
  font: inherit;
  font-size: 14.5px;
}
.ps-money {
  display: flex;
  min-height: 52px;
  align-items: center;
  gap: 6px;
  padding: 0 14px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius-sm);
  background: var(--m-surface);
}
.ps-money-sign {
  color: var(--m-muted);
  font-size: 18px;
  font-weight: 700;
}
.ps-money-input {
  min-width: 0;
  flex: 1;
  border: 0;
  background: transparent;
  color: var(--m-ink);
  font: inherit;
  font-family: var(--m-font-display);
  font-size: 20px;
  font-weight: 700;
  outline: none;
}

/* Step 2: methods as tiles, details in one panel. */
.ps-methods {
  display: grid;
  flex: 0 0 auto;
  grid-template-columns: 1fr 1fr;
  gap: 8px;
}
.ps-method {
  position: relative;
  display: flex;
  min-height: 56px;
  align-items: center;
  gap: 10px;
  padding: 0 14px;
  border: 1.5px solid var(--m-border);
  border-radius: var(--m-radius);
  background: var(--m-surface);
  color: var(--m-ink);
  cursor: pointer;
  font: inherit;
  font-size: 14.5px;
  font-weight: 700;
}
.ps-method--wide {
  grid-column: span 2;
  min-height: 48px;
}
.ps-method--on {
  border-color: var(--m-primary);
  background: var(--m-primary-soft, rgba(18, 194, 153, 0.08));
  color: var(--m-primary-dark);
}
.ps-method-check {
  margin-left: auto;
  color: var(--m-primary);
}
.ps-panel {
  padding: 4px 14px;
}
.ps-panel-row {
  padding: 12px 0;
}
.ps-panel-row + .ps-panel-row,
.ps-payto + .ps-panel-row {
  border-top: 1px solid var(--m-border);
}
.ps-panel-text {
  display: flex;
  align-items: flex-start;
  gap: 10px;
  margin: 0;
  padding: 12px 0;
  color: var(--m-text);
  font-size: 13.5px;
  line-height: 1.45;
}
.ps-payto {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 12px 0;
}
.ps-payto-body {
  display: flex;
  min-width: 0;
  flex: 1;
  flex-direction: column;
  gap: 2px;
}
.ps-payto-number {
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 18px;
  font-weight: 700;
  letter-spacing: 0.03em;
}
.ps-payto-name {
  overflow: hidden;
  color: var(--m-muted);
  font-size: 12.5px;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.ps-copy {
  display: flex;
  flex: 0 0 auto;
  align-items: center;
  gap: 4px;
  min-height: 36px;
  padding: 0 12px;
  border: 1px solid var(--m-border);
  border-radius: 999px;
  background: var(--m-surface);
  color: var(--m-primary-dark);
  cursor: pointer;
  font: inherit;
  font-size: 12.5px;
  font-weight: 700;
}
.ps-file {
  position: relative;
  display: flex;
  min-height: 52px;
  align-items: center;
  gap: 10px;
  padding: 0 12px;
  border: 1.5px dashed var(--m-border);
  border-radius: var(--m-radius-sm);
  background: var(--m-bg);
  color: var(--m-muted);
  cursor: pointer;
}
.ps-file--chosen {
  border-style: solid;
  border-color: var(--m-primary);
  color: var(--m-primary-dark);
}
.ps-file-thumb {
  width: 36px;
  height: 36px;
  border-radius: 6px;
  object-fit: cover;
}
.ps-file-text {
  flex: 1;
  overflow: hidden;
  color: var(--m-ink);
  font-size: 13.5px;
  font-weight: 600;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.ps-file-input {
  position: absolute;
  inset: 0;
  width: 100%;
  height: 100%;
  opacity: 0;
  cursor: pointer;
}

.ps-foot {
  display: flex;
  flex: 0 0 auto;
  flex-direction: column;
  gap: 4px;
  padding-top: 12px;
  border-top: 1px solid var(--m-border);
}
.ps-total {
  display: flex;
  align-items: center;
  justify-content: space-between;
  color: var(--m-muted);
  font-size: 12.5px;
  font-weight: 700;
}
.ps-total-amt {
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 26px;
  font-weight: 700;
  line-height: 1.15;
  font-variant-numeric: tabular-nums;
}
.ps-link {
  min-height: 32px;
  padding: 0 4px;
  border: 0;
  background: none;
  color: var(--m-primary-dark);
  cursor: pointer;
  font: inherit;
  font-size: 13px;
  font-weight: 700;
}
.ps-submit {
  min-height: 52px;
  margin-top: 6px;
  font-size: 15px;
  font-weight: 700;
}
.ps-submit-icon {
  margin-left: 6px;
}
.ps-foot-note {
  margin: 4px 0 0;
  color: var(--m-muted);
  font-size: 12px;
  text-align: center;
}
</style>
