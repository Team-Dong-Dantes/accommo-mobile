<template>
  <AppModal :model-value="modelValue" tall @update:model-value="emit('update:modelValue', $event)">
    <template #header>
      <button v-if="step === 2" type="button" class="ps-back" aria-label="Back to step 1" @click="step = 1">
        <IconifyIcon icon="lucide:chevron-left" width="20" />
      </button>
      <span class="mx-head">
        <span class="mx-head-step">Step {{ step }} of 2 · {{ step === 1 ? 'send it' : method === 'cash' ? 'cash' : 'prove it' }}</span>
        <h3 class="mx-head-title">
          {{ step === 1 ? (payLess ? 'Pay part now' : `Pay your ${who}`) : method === 'cash' ? `Hand over ${formatPesoExact(payAmount)}` : `Show you paid ${formatPesoExact(payAmount)}` }}
        </h3>
        <span v-if="subtitle && step === 1" class="mx-head-sub">{{ subtitle }}</span>
      </span>
      <button v-if="step === 1 && payLess" type="button" class="mx-link ps-all" @click="payLess = false">Pay all</button>
    </template>

    <div v-if="loading" class="mx-body ps-center"><q-spinner size="24px" color="primary" /></div>
    <div v-else-if="!items.length" class="mx-body ps-center">
      <IconifyIcon icon="lucide:circle-check" width="32" class="ps-done" />
      <p class="mx-hint">Nothing is owed on this stay right now.</p>
    </div>

    <!-- Step 1: what, and where to send it. -->
    <div v-else-if="step === 1" class="mx-body">
      <PayItemList :items="items" />

      <div v-if="payLess" class="mx-field">
        <span class="mx-label">How much now?</span>
        <span class="mx-money">
          <span class="mx-money-sign">₱</span>
          <input v-model.number="amount" type="number" :min="minAmount" :max="total" step="0.01" inputmode="decimal" class="mx-money-input" aria-label="Amount now" />
          <span class="mx-money-of">of {{ formatPesoExact(total) }}</span>
        </span>
        <span class="ps-quick">
          <button v-for="q in quick" :key="q.label" type="button" class="ps-quick-btn" :class="{ 'ps-quick-btn--on': Math.abs(Number(amount) - q.value) < 0.01 }" @click="amount = q.value">
            {{ q.label }}
          </button>
        </span>
        <span class="mx-hint">Your {{ who }} allows part payments of at least {{ formatPesoExact(minAmount) }}.</span>
        <label v-if="Number(amount) + 0.009 < total" class="mx-field ps-promise">
          <span class="mx-label">When will you pay the other {{ formatPesoExact(total - (Number(amount) || 0)) }}?</span>
          <DateTimeField v-model="promiseDate" mode="date" :min="manilaToday()" placeholder="Pick a date" class="mx-input" />
          <span class="mx-hint">Optional. We'll remind you that day.</span>
        </label>
      </div>

      <div class="mx-field">
        <span class="mx-label">Send {{ formatPesoExact(payAmount) }} to</span>
        <div class="mx-segs" role="tablist" aria-label="How you'll pay">
          <button
            v-for="m in METHODS"
            :key="m"
            type="button"
            role="tab"
            class="mx-seg"
            :class="{ 'mx-seg--on': method === m }"
            :aria-selected="method === m"
            @click="method = m"
          >
            {{ m === 'bank' ? 'Bank' : PAYMENT_METHOD_LABEL[m] }}
          </button>
        </div>
        <div v-if="method !== 'cash' && payTo" class="ps-payto">
          <span class="ps-payto-body">
            <span class="ps-payto-number">{{ payTo.number }}</span>
            <span v-if="payTo.name" class="mx-hint">{{ payTo.name }}</span>
          </span>
          <button type="button" class="ps-copy" @click="copyText(payTo.number)">
            <IconifyIcon icon="lucide:copy" width="15" /> Copy
          </button>
        </div>
        <p v-else-if="method !== 'cash'" class="mx-hint">Your {{ who }} hasn't added {{ PAYMENT_METHOD_LABEL[method] }} details yet — ask them where to send it.</p>
        <p v-else class="mx-hint">You'll hand it over in person.</p>
        <p v-if="payout?.note" class="mx-hint">From your {{ who }}: “{{ payout.note }}”</p>
      </div>
    </div>

    <!-- Step 2, cash: no receipt — the landlord/landlady's own check is the proof. -->
    <div v-else-if="method === 'cash'" class="mx-body">
      <div v-if="resubmit" class="mx-banner mx-banner--danger">
        <IconifyIcon icon="lucide:undo-2" width="18" class="mx-banner-icon" />
        <span><b>Sent back</b> · {{ resubmit.reason.replace('\n', ' — ') }}</span>
      </div>
      <ol class="ps-steps">
        <li><span class="ps-num">1</span><span>Give {{ formatPesoExact(payAmount) }} to your {{ who }} in person.</span></li>
        <li><span class="ps-num">2</span><span>Tap <b>I handed it over</b> below, right after.</span></li>
        <li><span class="ps-num">3</span><span>Your {{ who }} confirms {{ pronoun }} got it, and it shows as paid.</span></li>
      </ol>
      <label class="mx-field">
        <span class="mx-label">Note (optional)</span>
        <input v-model="note" type="text" maxlength="300" class="mx-input" placeholder="e.g. Gave it at the gate" />
      </label>
    </div>

    <!-- Step 2: the reference and a screenshot. -->
    <div v-else class="mx-body">
      <div v-if="resubmit" class="mx-banner mx-banner--danger">
        <IconifyIcon icon="lucide:undo-2" width="18" class="mx-banner-icon" />
        <span>
          <b>Sent back: {{ resubmitTitle }}</b>
          <template v-if="resubmitText"><br />“{{ resubmitText }}”</template>
        </span>
      </div>
      <label class="mx-field">
        <span class="mx-label">{{ PAYMENT_METHOD_LABEL[method] }} reference number</span>
        <input
          v-model="reference"
          type="text"
          class="mx-input mx-input--mono"
          :class="{ 'mx-input--bad': refProblem || serverRefProblem }"
          :inputmode="method === 'gcash' ? 'numeric' : 'text'"
          :placeholder="method === 'gcash' ? '13-digit GCash reference' : 'Reference number'"
          @input="serverRefProblem = ''"
        />
        <span v-if="refProblem || serverRefProblem" class="mx-hint mx-hint--bad">{{ serverRefProblem || refProblem }}</span>
        <span v-else-if="resubmit && reference && normalizeReference(reference) !== resubmit.reference" class="mx-hint ps-ok">
          <IconifyIcon icon="lucide:check" width="14" /> Changed from last time
        </span>
      </label>
      <div class="mx-field">
        <span class="mx-label">Receipt screenshot</span>
        <span class="ps-file" :class="{ 'ps-file--chosen': proofUrl }">
          <img v-if="proofPreview" :src="proofPreview" alt="" class="ps-file-thumb" />
          <IconifyIcon v-else icon="lucide:image-plus" width="20" />
          <span class="ps-file-body">
            <span class="ps-file-title">{{ uploading ? 'Uploading…' : proofUrl ? 'Screenshot attached' : 'Attach a screenshot' }}</span>
            <span class="mx-hint">{{ proofUrl ? 'Tap to replace with a clearer one' : 'Of the receipt in your app' }}</span>
          </span>
          <input type="file" accept="image/*" class="ps-file-input" :disabled="uploading" @change="onProof" />
        </span>
        <span v-if="serverProofProblem" class="mx-hint mx-hint--bad">{{ serverProofProblem }}</span>
      </div>
      <label class="mx-field">
        <span class="mx-label">Note to your {{ who }} (optional)</span>
        <input v-model="note" type="text" maxlength="300" class="mx-input" placeholder="e.g. The rest after my allowance comes in" />
      </label>
    </div>

    <template v-if="!loading && items.length" #footer>
      <div v-if="step === 1" class="mx-foot">
        <button type="button" class="mx-btn" :disabled="!(payAmount > 0)" @click="next">
          {{ method === 'cash' ? 'Next' : `I've sent ${formatPesoExact(payAmount)}` }}
          <IconifyIcon icon="lucide:arrow-right" width="18" />
        </button>
        <p v-if="!payLess && canPayLess" class="mx-foot-note">
          Can't pay it all? <button type="button" class="mx-link" @click="startPayLess">Pay part now</button> — at least {{ formatPesoExact(minAmount) }}.
        </p>
      </div>
      <div v-else class="mx-foot">
        <button type="button" class="mx-btn" :disabled="submitting || uploading" @click="submit">
          {{ submitting ? 'Sending…' : method === 'cash' ? 'I handed it over' : resubmit ? 'Send again for confirmation' : 'Send for confirmation' }}
        </button>
        <p class="mx-foot-note">
          {{ method === 'cash' ? 'Only tap this once the cash has changed hands.' : `Your ${who} confirms once it checks out. You can take it back until then.` }}
        </p>
      </div>
    </template>
  </AppModal>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import { Icon as IconifyIcon } from '@iconify/vue'
import { supabase } from '@/utils/supabase'
import { errorMessage } from '@/utils/errors'
import { useNotify } from '@/utils/notify'
import { uploadSecureDocument } from '@/utils/upload'
import { formatPesoExact, landlordTitle, PAYMENT_METHOD_LABEL } from '@/utils/format'
import { fileFingerprint, manilaToday, minPayment, normalizeReference, referenceProblem } from '@/utils/payments'
import { usePayItems, type PayPick } from '@/utils/usePayItems'
import AppModal from '@/components/shared/AppModal.vue'
import DateTimeField from '@/components/shared/DateTimeField.vue'
import PayItemList from '@/components/shared/PayItemList.vue'

// The student's Pay: step 1 picks what to pay and shows where to send it;
// step 2 proves it (reference + screenshot), or for cash just says it was handed
// over. Everything goes to record_payments() as one transfer that the
// landlord/landlady confirms or sends back. A transfer sent back opens straight
// on step 2 with the same items, the same method, and the reason in view.
export interface Resubmit {
  reason: string
  method: string
  reference: string
  pick: PayPick
}
const props = defineProps<{
  modelValue: boolean
  leaseId: string
  /** For "Send to". */
  landlordId?: string
  allowPartial?: boolean
  partialMinPct?: number
  subtitle?: string
  /** An ended stay: only rent and bills are left to settle. */
  settleOnly?: boolean
  /** The stay's move-in date: the rent due on it is the advance. */
  startDate?: string
  resubmit?: Resubmit | null
}>()
const emit = defineEmits<{ 'update:modelValue': [boolean]; submitted: [] }>()
const notify = useNotify()

const METHODS = ['gcash', 'maya', 'bank', 'cash'] as const
type Method = (typeof METHODS)[number]

const { loading, months, billIds, deposit, depositRow, picked, total, items, load } = usePayItems(
  () => props.leaseId,
  () => props.startDate,
  () => Boolean(props.settleOnly),
)
const payout = ref<{ gcash_number: string | null; gcash_name: string | null; maya_number: string | null; maya_name: string | null; bank_name: string | null; bank_account_number: string | null; bank_account_name: string | null; note: string | null } | null>(null)
const landlordSex = ref<string | null>(null)
const who = computed(() => landlordTitle(landlordSex.value).toLowerCase())
const pronoun = computed(() => (landlordSex.value?.toUpperCase() === 'F' ? 'she' : landlordSex.value?.toUpperCase() === 'M' ? 'he' : 'they'))

const step = ref<1 | 2>(1)
const payLess = ref(false)
const amount = ref<number | ''>(0)
const method = ref<Method>('gcash')
const reference = ref('')
const proofUrl = ref('')
const proofHash = ref('')
const proofPreview = ref('')
const uploading = ref(false)
const note = ref('')
const promiseDate = ref('')
const submitting = ref(false)
const serverRefProblem = ref('')
const serverProofProblem = ref('')

const minAmount = computed(() => {
  const first = picked.value[0]
  if (!first) return 0.01
  return Math.min(total.value, minPayment(first, Boolean(props.allowPartial), props.partialMinPct ?? 10))
})
const canPayLess = computed(() => minAmount.value + 0.009 < total.value)
const payAmount = computed(() => (payLess.value ? Math.round((Number(amount.value) || 0) * 100) / 100 : total.value))
const quick = computed(() =>
  [
    { label: '25%', value: total.value * 0.25 },
    { label: 'Half', value: total.value * 0.5 },
    { label: '75%', value: total.value * 0.75 },
  ]
    .map((q) => ({ ...q, value: Math.round(q.value * 100) / 100 }))
    .filter((q) => q.value + 0.009 >= minAmount.value),
)
const refProblem = computed(() => referenceProblem(method.value, reference.value))
const resubmitTitle = computed(() => (props.resubmit?.reason.includes('\n') ? props.resubmit.reason.split('\n')[0] : 'see why below'))
const resubmitText = computed(() => {
  const r = props.resubmit?.reason ?? ''
  return r.includes('\n') ? r.split('\n').slice(1).join(' ') : r
})

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
  amount.value = Math.max(minAmount.value, Math.round(total.value * 50) / 100)
  payLess.value = true
}

// Fresh each time it opens: what's owed now, with what is already due picked.
watch(
  () => props.modelValue,
  async (open) => {
    if (!open || !props.leaseId) return
    const re = props.resubmit ?? null
    step.value = re ? 2 : 1
    payLess.value = false
    method.value = re && (METHODS as readonly string[]).includes(re.method) ? (re.method as Method) : 'gcash'
    reference.value = ''
    proofUrl.value = ''
    proofHash.value = ''
    proofPreview.value = ''
    note.value = ''
    promiseDate.value = ''
    serverRefProblem.value = ''
    serverProofProblem.value = ''
    try {
      const [, payoutResult, person] = await Promise.all([
        load(re?.pick ?? null),
        props.landlordId
          ? supabase
              .from('landlord_payout')
              .select('gcash_number, gcash_name, maya_number, maya_name, bank_name, bank_account_number, bank_account_name, note')
              .eq('landlord_id', props.landlordId)
              .maybeSingle()
          : Promise.resolve({ data: null }),
        props.landlordId ? supabase.from('users').select('sex').eq('id', props.landlordId).maybeSingle() : Promise.resolve({ data: null }),
      ])
      payout.value = payoutResult.data
      landlordSex.value = (person.data as { sex: string | null } | null)?.sex ?? null
    } catch (e) {
      notify.error(errorMessage(e, 'Could not load what is owed.'))
    }
  },
  { immediate: true },
)

async function onProof(event: Event) {
  const input = event.target as HTMLInputElement
  const file = input.files?.[0]
  if (!file) return
  uploading.value = true
  serverProofProblem.value = ''
  try {
    const [url, hash] = await Promise.all([uploadSecureDocument(file), fileFingerprint(file)])
    proofUrl.value = url
    proofHash.value = hash ?? ''
    proofPreview.value = URL.createObjectURL(file)
  } catch (e) {
    notify.error(errorMessage(e, 'Could not upload the screenshot.'))
  } finally {
    uploading.value = false
    input.value = ''
  }
}

// What step 1 must get right before step 2. The database checks each of
// these too; saying so here saves a round trip.
function amountProblem(): string | null {
  if (!picked.value.length) return 'Tick at least one thing to pay.'
  const pay = payAmount.value
  if (!(pay > 0)) return 'Enter an amount.'
  if (pay > total.value + 0.009) return `That is more than what you ticked (${formatPesoExact(total.value)}).`
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
  const ref = normalizeReference(reference.value)
  if (method.value !== 'cash') {
    if (!ref) return notify.error('Enter the reference number from your receipt.')
    if (refProblem.value) return notify.error(refProblem.value)
    if (!proofUrl.value) return notify.error('Attach a screenshot of the receipt.')
  }
  submitting.value = true
  try {
    const partial = payAmount.value + 0.009 < total.value
    const { error } = await supabase.rpc('record_payments', {
      p_lease: props.leaseId,
      p_months: months.value,
      p_bills: billIds.value,
      // The advance is rent now (20261009010000); the parameter stays for older builds.
      p_advance: false,
      p_deposit: deposit.value && !!depositRow.value,
      p_method: method.value,
      ...(partial ? { p_amount: payAmount.value } : {}),
      ...(method.value !== 'cash' ? { p_reference: ref, p_proof_url: proofUrl.value } : {}),
      ...(proofHash.value && method.value !== 'cash' ? { p_proof_hash: proofHash.value } : {}),
      ...(note.value.trim() ? { p_note: note.value.trim() } : {}),
      ...(partial && promiseDate.value ? { p_promise_date: promiseDate.value } : {}),
    })
    if (error) throw error
    notify.success(method.value === 'cash' ? `Sent — your ${who.value} confirms once ${pronoun.value} has it.` : 'Sent for confirmation.')
    emit('update:modelValue', false)
    emit('submitted')
  } catch (e) {
    const msg = errorMessage(e, 'Could not send this payment.')
    // The two the database can refuse after step 2 is filled: show them on the field.
    if (/reference number/i.test(msg)) serverRefProblem.value = msg
    else if (/receipt image/i.test(msg)) serverProofProblem.value = msg
    else notify.error(msg)
  } finally {
    submitting.value = false
  }
}
</script>

<style scoped>
.ps-center {
  align-items: center;
  justify-content: center;
  text-align: center;
}
.ps-done {
  color: var(--m-success);
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
.ps-all {
  flex: 0 0 auto;
  font-size: 13.5px;
}
.ps-quick {
  display: flex;
  gap: 6px;
}
.ps-quick-btn {
  flex: 1;
  min-height: 40px;
  border: 1px solid var(--m-border);
  border-radius: 10px;
  background: var(--m-surface);
  color: var(--m-ink);
  cursor: pointer;
  font: inherit;
  font-size: 13.5px;
  font-weight: 700;
}
.ps-quick-btn--on {
  border-color: var(--m-primary);
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
}
.ps-promise {
  margin-top: 6px;
}
.ps-payto {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 14px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius-sm);
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
  font-family: var(--m-font-mono);
  font-size: 19px;
  font-weight: 500;
  letter-spacing: 0.02em;
}
.ps-copy {
  display: inline-flex;
  min-height: 40px;
  flex: 0 0 auto;
  align-items: center;
  gap: 6px;
  padding: 0 14px;
  border: 0;
  border-radius: 999px;
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
  cursor: pointer;
  font: inherit;
  font-size: 13.5px;
  font-weight: 700;
}
.ps-steps {
  display: flex;
  flex: 0 0 auto;
  flex-direction: column;
  gap: 14px;
  margin: 0;
  padding: 16px;
  border-radius: var(--m-radius);
  background: var(--m-bg);
  list-style: none;
}
.ps-steps li {
  display: flex;
  align-items: flex-start;
  gap: 12px;
  color: var(--m-text);
  font-size: 14px;
  line-height: 1.45;
}
.ps-num {
  display: inline-flex;
  width: 26px;
  height: 26px;
  flex: 0 0 auto;
  align-items: center;
  justify-content: center;
  border-radius: 50%;
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
  font-size: 13px;
  font-weight: 700;
}
.ps-ok {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  color: var(--m-success);
  font-weight: 600;
}
.ps-file {
  position: relative;
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 10px;
  border: 1.5px dashed var(--m-border);
  border-radius: var(--m-radius-sm);
  background: var(--m-bg);
  color: var(--m-muted);
}
.ps-file--chosen {
  border-style: solid;
}
.ps-file-thumb {
  width: 52px;
  height: 70px;
  flex: 0 0 auto;
  border: 1px solid var(--m-border);
  border-radius: 8px;
  object-fit: cover;
}
.ps-file-body {
  display: flex;
  min-width: 0;
  flex: 1;
  flex-direction: column;
  gap: 2px;
}
.ps-file-title {
  color: var(--m-ink);
  font-size: 14px;
  font-weight: 700;
}
.ps-file-input {
  position: absolute;
  inset: 0;
  width: 100%;
  height: 100%;
  opacity: 0;
  cursor: pointer;
}
</style>
