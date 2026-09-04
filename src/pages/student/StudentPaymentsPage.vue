<template>
  <q-page class="pp">
    <div v-if="loading" class="stack">
      <q-skeleton type="rect" height="90px" class="sk" />
      <q-skeleton type="rect" height="70px" class="sk" />
    </div>

    <div v-else-if="error" class="stack">
      <q-card flat bordered class="card">
        <IconifyIcon icon="lucide:cloud-off" width="24" class="text-grey-6" />
        <p class="err-title">Couldn't load your payments</p>
        <p class="err-sub">{{ error }}</p>
        <q-btn unelevated rounded no-caps dense color="primary" label="Try again" class="q-mt-sm q-px-md" @click="load" />
      </q-card>
    </div>

    <EmptyState
      v-else-if="!lease"
      icon="lucide:wallet-cards"
      title="No active stay"
      message="Once you're accepted into a lease, your rent schedule and payment history will appear here."
    />

    <div v-else class="stack">
      <div class="head">
        <span class="head-label">Expected rent</span>
        <span class="head-rent">{{ formatPeso(lease.monthlyRent) }}<span class="head-per">/mo</span></span>
        <span class="head-sub">{{ lease.roomLabel }} · {{ lease.accommodationName }}</span>
        <button type="button" class="head-btn" @click="openSubmit">
          <IconifyIcon icon="lucide:circle-plus" width="16" />
          Submit a payment
        </button>
      </div>

      <section class="sec">
        <h2 class="sec-title">History</h2>
        <div v-if="payments.length" class="group">
          <div v-for="p in payments" :key="p.id" class="pay-row">
            <span class="pay-icon"><IconifyIcon icon="lucide:receipt" width="16" /></span>
            <span class="pay-body">
              <span class="pay-month">{{ formatMonth(p.month) }}</span>
              <span class="pay-method">{{ PAYMENT_METHOD_LABEL[p.method] || p.method }}</span>
            </span>
            <span class="pay-side">
              <span class="pay-amount">{{ formatPeso(p.amount) }}</span>
              <span class="pay-chip" :class="`pay-chip--${statusColor(PAYMENT_STATUS, p.status)}`">
                {{ statusText(PAYMENT_STATUS, p.status) }}
              </span>
            </span>
          </div>
        </div>
        <p v-else class="none">No payments submitted yet.</p>
      </section>

      <div class="tail" />
    </div>

    <q-dialog v-model="submitOpen" position="bottom">
      <q-card class="submit-sheet">
        <h3 class="submit-title">Submit a payment</h3>
        <p class="submit-note">Your manager will verify this before it's marked paid.</p>

        <label class="submit-field">
          <span class="submit-label">Month</span>
          <input v-model="form.month" type="month" class="submit-input" />
        </label>
        <label class="submit-field">
          <span class="submit-label">Amount</span>
          <input v-model.number="form.amount" type="number" min="0" step="0.01" class="submit-input" />
        </label>
        <label class="submit-field">
          <span class="submit-label">Method</span>
          <select v-model="form.method" class="submit-input">
            <option value="gcash">GCash</option>
            <option value="maya">Maya</option>
            <option value="bank">Bank transfer</option>
            <option value="cash">Cash</option>
            <option value="others">Other</option>
          </select>
        </label>
        <label class="submit-field">
          <span class="submit-label">Reference number (optional)</span>
          <input v-model="form.reference" type="text" class="submit-input" placeholder="e.g. GCash ref no." />
        </label>
        <label class="submit-field">
          <span class="submit-label">Proof of payment (optional)</span>
          <input type="file" accept="image/*" class="submit-file" @change="onProofSelected" />
          <span v-if="uploadingProof" class="submit-hint">Uploading…</span>
          <span v-else-if="form.proofUrl" class="submit-hint submit-hint--ok">Attached ✓</span>
        </label>

        <q-btn
          unelevated
          rounded
          no-caps
          color="primary"
          class="submit-btn"
          :loading="submitting"
          :disable="uploadingProof"
          label="Submit"
          @click="submitPayment"
        />
      </q-card>
    </q-dialog>
  </q-page>
</template>

<script setup lang="ts">
import { ref, reactive, onMounted } from 'vue'
import { Icon as IconifyIcon } from '@iconify/vue'
import { supabase } from '@/utils/supabase'
import { errorMessage } from '@/utils/errors'
import { formatPeso, formatMonth, PAYMENT_STATUS, PAYMENT_METHOD_LABEL, statusText, statusColor } from '@/utils/format'
import { useNotify } from '@/utils/notify'
import { createNotification } from '@/boot/notify'
import { uploadDocument } from '@/utils/upload'
import EmptyState from '@/components/shared/EmptyState.vue'

interface Lease {
  id: string
  managerId: string
  monthlyRent: number
  roomLabel: string
  accommodationName: string
}
interface Payment {
  id: string
  month: string
  amount: number
  status: string
  method: string
}

const notify = useNotify()

const loading = ref(true)
const error = ref('')
const lease = ref<Lease | null>(null)
const payments = ref<Payment[]>([])

const submitOpen = ref(false)
const submitting = ref(false)
const uploadingProof = ref(false)
const form = reactive({
  month: new Date().toISOString().slice(0, 7),
  amount: 0,
  method: 'gcash' as 'gcash' | 'maya' | 'bank' | 'cash' | 'others',
  reference: '',
  proofUrl: '',
})

async function load() {
  loading.value = true
  error.value = ''
  try {
    const { data: authData } = await supabase.auth.getUser()
    const user = authData?.user
    if (!user) {
      error.value = 'Not signed in.'
      return
    }

    const { data: leaseRow } = await supabase
      .from('leases')
      .select('id, monthly_rent, accommodation_manager_id, rooms(room_number, label, accommodations(name))')
      .eq('student_id', user.id)
      .in('status', ['active', 'leave_requested'])
      .order('start_date', { ascending: false })
      .limit(1)
      .maybeSingle()

    if (!leaseRow) {
      lease.value = null
      return
    }

    const room = leaseRow.rooms as unknown as {
      room_number: string | null
      label: string | null
      accommodations: { name: string | null } | null
    } | null

    lease.value = {
      id: leaseRow.id,
      managerId: leaseRow.accommodation_manager_id,
      monthlyRent: Number(leaseRow.monthly_rent ?? 0),
      roomLabel: room?.label || (room?.room_number ? `Room ${room.room_number}` : 'Your room'),
      accommodationName: room?.accommodations?.name || 'Your accommodation',
    }

    const { data: paymentRows, error: paymentsError } = await supabase
      .from('payments')
      .select('id, month, amount, status, method')
      .eq('lease_id', leaseRow.id)
      .order('month', { ascending: false })
    if (paymentsError) throw paymentsError
    payments.value = (paymentRows ?? []).map((p) => ({
      id: p.id,
      month: p.month,
      amount: Number(p.amount),
      status: p.status,
      method: p.method,
    }))
  } catch (e) {
    error.value = errorMessage(e, 'Something went wrong.')
  } finally {
    loading.value = false
  }
}

function openSubmit() {
  form.month = new Date().toISOString().slice(0, 7)
  form.amount = lease.value?.monthlyRent ?? 0
  form.method = 'gcash'
  form.reference = ''
  form.proofUrl = ''
  submitOpen.value = true
}

async function onProofSelected(event: Event) {
  const input = event.target as HTMLInputElement
  const file = input.files?.[0]
  if (!file) return
  uploadingProof.value = true
  try {
    form.proofUrl = await uploadDocument(file, '', 'payment_proof')
  } catch (e) {
    notify.error(errorMessage(e, 'Could not upload the proof image.'))
  } finally {
    uploadingProof.value = false
    input.value = ''
  }
}

async function submitPayment() {
  if (submitting.value || uploadingProof.value || !lease.value) return
  submitting.value = true
  try {
    const { data: created, error: insertError } = await supabase
      .from('payments')
      .insert({
        lease_id: lease.value.id,
        month: `${form.month}-01`,
        amount: form.amount,
        method: form.method,
        status: 'pending_verification',
        txn_reference: form.reference.trim() || null,
        proof_url: form.proofUrl || null,
      })
      .select('id, month, amount, status, method')
      .single()
    if (insertError) throw insertError

    payments.value = [
      { id: created.id, month: created.month, amount: Number(created.amount), status: created.status, method: created.method },
      ...payments.value,
    ]

    void createNotification(
      lease.value.managerId,
      'Payment submitted',
      `A payment of ${formatPeso(form.amount)} was submitted for verification.`,
      'payment',
      `/manager/tenant/${lease.value.id}`,
    )

    submitOpen.value = false
    notify.success('Payment submitted for verification.')
  } catch (e) {
    notify.error(errorMessage(e, 'Could not submit your payment.'))
  } finally {
    submitting.value = false
  }
}

onMounted(load)
</script>

<style scoped>
.pp {
  background: var(--m-bg);
}
.stack {
  display: flex;
  flex-direction: column;
  gap: 14px;
  padding: 8px var(--m-page-gutter) 24px;
}
.sk {
  border-radius: var(--m-radius);
}
.tail {
  height: 12px;
}

.card {
  padding: 18px 14px;
  border-radius: var(--m-radius);
  background: var(--m-surface);
  text-align: center;
}
.err-title {
  margin: 8px 0 0;
  color: var(--m-ink);
  font-size: 14px;
  font-weight: 700;
}
.err-sub {
  margin: 2px 0 0;
  color: var(--m-muted);
  font-size: 12px;
}

.head {
  display: flex;
  flex-direction: column;
  gap: 3px;
  padding: 10px 14px 14px;
  border-radius: var(--m-radius);
  background: var(--m-surface);
  border: 1px solid var(--m-border);
}
.head-label {
  color: var(--m-muted);
  font-size: 12px;
  font-weight: 700;
  letter-spacing: 0.02em;
  text-transform: uppercase;
}
.head-rent {
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 26px;
  font-weight: 700;
  letter-spacing: -0.02em;
}
.head-per {
  font-size: 13px;
  font-weight: 600;
  opacity: 0.7;
}
.head-sub {
  color: var(--m-muted);
  font-size: 12.5px;
}
.head-btn {
  display: inline-flex;
  align-self: flex-start;
  align-items: center;
  gap: 6px;
  margin-top: 10px;
  padding: 9px 16px;
  border: 0;
  border-radius: 999px;
  background: var(--m-primary);
  color: #fff;
  cursor: pointer;
  font: inherit;
  font-size: 13px;
  font-weight: 700;
  -webkit-tap-highlight-color: transparent;
}

.sec {
  display: flex;
  flex-direction: column;
  gap: 6px;
}
.sec-title {
  margin: 0;
  padding: 0 2px;
  color: var(--m-ink);
  font-size: 12.5px;
  font-weight: 700;
  letter-spacing: 0.02em;
  text-transform: uppercase;
}
.group {
  display: flex;
  flex-direction: column;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius);
  background: var(--m-surface);
  overflow: hidden;
}
.none {
  padding: 14px 12px;
  margin: 0;
  color: var(--m-muted);
  font-size: 12.5px;
  text-align: center;
}

.pay-row {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 10px 12px;
  border-top: 1px solid var(--m-border);
}
.group > .pay-row:first-child {
  border-top: 0;
}
.pay-icon {
  display: grid;
  width: 32px;
  height: 32px;
  flex: 0 0 32px;
  place-items: center;
  border-radius: 999px;
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
}
.pay-body {
  display: flex;
  min-width: 0;
  flex: 1;
  flex-direction: column;
  gap: 1px;
}
.pay-month {
  color: var(--m-ink);
  font-size: 13.5px;
  font-weight: 700;
}
.pay-method {
  color: var(--m-muted);
  font-size: 11.5px;
}
.pay-side {
  display: flex;
  flex: 0 0 auto;
  flex-direction: column;
  align-items: flex-end;
  gap: 3px;
}
.pay-amount {
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 14px;
  font-weight: 700;
}
.pay-chip {
  padding: 2px 8px;
  border-radius: 999px;
  font-size: 10px;
  font-weight: 700;
}
.pay-chip--green {
  background: var(--m-success-soft);
  color: var(--m-success);
}
.pay-chip--amber,
.pay-chip--orange {
  background: var(--m-warning-soft);
  color: var(--m-warning);
}
.pay-chip--red {
  background: var(--m-danger-soft);
  color: var(--m-danger);
}
.pay-chip--grey {
  background: var(--m-bg);
  color: var(--m-muted);
}

.submit-sheet {
  display: flex;
  width: 100%;
  max-width: 480px;
  flex-direction: column;
  gap: 12px;
  margin: 0 auto;
  padding: 16px var(--m-page-gutter) calc(16px + env(safe-area-inset-bottom));
  border-radius: var(--m-radius-lg, var(--m-radius)) var(--m-radius-lg, var(--m-radius)) 0 0;
}
.submit-title {
  margin: 0;
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 17px;
  font-weight: 700;
}
.submit-note {
  margin: -6px 0 0;
  color: var(--m-muted);
  font-size: 12.5px;
}
.submit-field {
  display: flex;
  flex-direction: column;
  gap: 4px;
}
.submit-label {
  color: var(--m-muted);
  font-size: 12px;
  font-weight: 700;
  letter-spacing: 0.02em;
  text-transform: uppercase;
}
.submit-input {
  min-height: 44px;
  padding: 0 12px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius-sm);
  background: var(--m-surface);
  color: var(--m-ink);
  font: inherit;
  font-size: 14px;
}
.submit-file {
  font-size: 13px;
}
.submit-hint {
  color: var(--m-muted);
  font-size: 11.5px;
}
.submit-hint--ok {
  color: var(--m-success);
  font-weight: 600;
}
.submit-btn {
  min-height: 48px;
  font-weight: 700;
}
</style>
