<template>
  <q-page class="bg-grey-1 q-pb-xl">
    <div class="row justify-between items-center q-pa-md">
      <div>
        <div class="text-h5 text-weight-bold">Payments</div>
        <div class="text-subtitle2 text-grey-6">Track your rent & deposit</div>
      </div>
      <q-btn
        unelevated color="teal-8" icon="payment" label="Pay"
        class="rounded-borders text-weight-bold" no-caps @click="openPaymentMethod()"
      />
    </div>

    <template v-if="loading">
      <div class="q-pa-md">
        <q-skeleton height="80px" square class="q-mb-md" style="border-radius:16px" />
        <div class="row q-col-gutter-sm">
          <div class="col-6"><q-skeleton height="100px" square style="border-radius:16px" /></div>
          <div class="col-6"><q-skeleton height="100px" square style="border-radius:16px" /></div>
        </div>
      </div>
    </template>

    <template v-else>
      <div class="q-px-md q-mb-md">
        <div class="text-subtitle2 text-weight-bold q-mb-sm">
          Payment Progress <span class="text-teal-8">· {{ paidCount }} of {{ totalMonths }} months paid</span>
        </div>
        <div class="row">
          <div v-for="(m, i) in months" :key="i" class="column items-center" style="flex:1">
            <div
              class="rounded-full"
              :class="m === 'paid' ? 'bg-teal-8' : m === 'current' ? 'bg-amber-5' : 'bg-grey-3'"
              style="width:22px;height:22px;display:flex;align-items:center;justify-content:center"
            >
              <q-icon v-if="m === 'paid'" name="check" size="13px" color="white" />
              <span v-else-if="m === 'current'" class="text-white text-weight-bold" style="font-size:10px">!</span>
            </div>
          </div>
        </div>
      </div>

      <div class="row q-col-gutter-sm q-px-md q-mb-md">
        <div class="col-6">
          <q-card flat bordered class="custom-card">
            <q-card-section>
              <div class="text-caption text-grey-7">Total Paid</div>
              <div class="text-h5 text-weight-bold q-mt-xs">{{ formatPeso(totalPaid) }}</div>
              <div class="text-caption text-teal-8 text-weight-medium">{{ paidCount }} month{{ paidCount === 1 ? '' : 's' }} covered</div>
            </q-card-section>
          </q-card>
        </div>
        <div class="col-6">
          <q-card flat bordered class="custom-card">
            <q-card-section>
              <div class="text-caption text-grey-7">Security Deposit</div>
              <div class="text-h5 text-weight-bold q-mt-xs">{{ formatPeso(lease?.deposit_paid ?? 0) }}</div>
              <div class="text-caption text-blue-8 text-weight-medium">Refundable</div>
            </q-card-section>
          </q-card>
        </div>
      </div>

      <div class="q-px-md q-mb-md">
        <div class="text-subtitle1 text-weight-bold q-mb-sm">Lease Summary</div>
        <q-card flat bordered class="custom-card">
          <q-list dense separator>
            <q-item><q-item-section>Monthly Rent</q-item-section><q-item-section side class="text-weight-bold">{{ formatPeso(lease?.monthly_rent ?? 0) }}</q-item-section></q-item>
            <q-item><q-item-section>Advance Paid</q-item-section><q-item-section side class="text-weight-bold">{{ formatPeso(lease?.advance_paid ?? 0) }}</q-item-section></q-item>
            <q-item><q-item-section>Deposit Paid</q-item-section><q-item-section side class="text-weight-bold">{{ formatPeso(lease?.deposit_paid ?? 0) }}</q-item-section></q-item>
            <q-item><q-item-section>Lease Period</q-item-section><q-item-section side class="text-weight-medium">{{ formatDate(lease?.start_date ?? null) }} – {{ formatDate(lease?.end_date ?? null) }}</q-item-section></q-item>
            <q-item><q-item-section>Status</q-item-section>          <q-item-section side><q-badge :color="statusColor(LEASE_STATUS, lease?.status)" :label="statusText(LEASE_STATUS, lease?.status, 'None')" class="q-px-sm" /></q-item-section></q-item>
          </q-list>
        </q-card>
      </div>

      <div class="q-px-md">
        <div class="text-subtitle1 text-weight-bold q-mb-sm">Payment History</div>
        <div v-if="paymentHistory.length === 0" class="text-center text-grey-6 q-py-xl">
          No payments recorded yet.
        </div>
        <q-card v-for="payment in paymentHistory" :key="payment.id" flat bordered class="custom-card q-mb-sm">
          <q-item>
            <q-item-section avatar>
              <q-icon
                :name="payment.status === 'paid' ? 'check_circle' : 'pending'"
                :color="payment.status === 'paid' ? 'green' : payment.status === 'overdue' ? 'negative' : 'amber'"
                size="28px"
              />
            </q-item-section>
            <q-item-section>
              <q-item-label class="text-weight-bold">{{ formatMonth(payment.month) }}</q-item-label>
              <q-item-label caption>{{ payment.description }}</q-item-label>
            </q-item-section>
            <q-item-section side>
              <div class="text-weight-bold text-right">{{ formatPeso(payment.amount) }}</div>
              <div class="q-mt-xs">
                <q-btn
                  v-if="payment.status === 'due' || payment.status === 'overdue'"
                  unelevated :color="payment.status === 'overdue' ? 'negative' : 'teal-8'"
                  label="Pay Now" size="sm" dense no-caps
                  class="rounded-borders text-weight-bold" @click="openPaymentMethod(payment.amount)"
                />
                <q-badge v-else-if="payment.status === 'pending_verification'" color="amber" label="Pending" />
                <q-btn v-else flat dense icon="download" color="grey-6" size="sm" round @click="downloadReceipt(payment.id)" />
              </div>
            </q-item-section>
          </q-item>
        </q-card>
      </div>

      <div v-if="error" class="text-negative text-center q-pa-md">{{ error }}</div>
    </template>

    <!-- Payment Method Dialog (bottom sheet) -->
    <q-dialog v-model="methodDialog" position="bottom">
      <q-card class="custom-card dialog-card full-width">
        <q-card-section class="row items-center justify-between">
          <div>
            <div class="text-caption text-grey-6">Amount Due</div>
            <div class="text-h5 text-weight-bold">{{ formatPeso(amountDue) }}</div>
          </div>
          <q-btn flat round dense icon="close" @click="methodDialog = false" />
        </q-card-section>
        <q-separator />
        <q-card-section>
          <div class="text-subtitle2 text-weight-bold q-mb-sm">Select Payment Method</div>
          <q-list>
            <q-item
              v-for="m in paymentMethods" :key="m.value" clickable v-ripple
              :class="selectedMethod === m.value ? 'method-selected' : ''"
              @click="selectedMethod = m.value"
            >
              <q-item-section avatar>
                <q-avatar :color="m.color" text-color="white" :icon="m.icon" />
              </q-item-section>
              <q-item-section>
                <q-item-label class="text-weight-medium">{{ m.label }}</q-item-label>
                <q-item-label caption>{{ m.hint }}</q-item-label>
              </q-item-section>
              <q-item-section side>
                <q-radio v-model="selectedMethod" :val="m.value" color="teal-8" />
              </q-item-section>
            </q-item>
          </q-list>
        </q-card-section>
        <q-card-section>
          <q-btn
            unelevated color="teal-8" label="Continue"
            class="rounded-borders text-weight-bold full-width"
            no-caps :disable="!selectedMethod" @click="continuePayment"
          />
        </q-card-section>
      </q-card>
    </q-dialog>

    <!-- Proof of Payment Dialog (bottom sheet) -->
    <q-dialog v-model="proofDialog" position="bottom">
      <q-card class="dialog-card full-width">
        <q-card-section class="row items-center justify-between">
          <div>
            <div class="text-subtitle1 text-weight-bold">Proof of Payment</div>
            <div class="text-caption text-grey-6">Attach a screenshot of your transaction</div>
          </div>
          <q-btn flat round dense icon="close" @click="proofDialog = false" />
        </q-card-section>
        <q-separator />
        <q-card-section class="text-center">
          <AuthFileDropZone
            v-model="proofFile"
            label="Tap to attach proof of payment"
            accept=".jpg, image/*, .pdf"
            class="q-mb-sm"
          />
          <div v-if="proofFile" class="text-caption text-teal-8 text-weight-medium q-mb-xs">
            {{ proofFile.name }}
          </div>
          <div class="text-caption text-grey-5">JPG, PNG, or PDF · Max 5MB</div>
        </q-card-section>
        <q-card-section>
          <q-btn
            unelevated color="teal-8" label="Submit Payment"
            class="rounded-borders text-weight-bold full-width"
            no-caps :loading="submitting" :disable="!proofFile" @click="submitPayment"
          />
        </q-card-section>
      </q-card>
    </q-dialog>

    <!-- Payment Success Dialog (centered modal) -->
    <q-dialog v-model="successDialog" persistent>
      <q-card class="success-card text-center q-pa-lg">
        <q-card-section>
          <div class="row justify-center q-mb-md">
            <div class="success-check">
              <q-icon name="check" color="teal-8" size="48px" />
            </div>
          </div>
          <div class="text-h6 text-weight-bold">Payment Sent!</div>
          <div class="text-body2 text-grey-6 q-mt-sm q-px-md">
            Your landlord will confirm within 24 hours. Keep your proof of payment.
          </div>
          <div class="text-caption text-grey-5 q-mt-md">REF: {{ referenceNumber }}</div>
        </q-card-section>
        <q-card-section>
          <q-btn
            unelevated color="teal-8" label="Done"
            class="rounded-borders text-weight-bold full-width"
            no-caps @click="finishPayment"
          />
        </q-card-section>
      </q-card>
    </q-dialog>
  </q-page>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue';
import { useQuasar } from 'quasar';
import { useRouter } from 'vue-router';
import { supabase } from '@/shared/utils/supabase';
import { LEASE_STATUS, statusText, statusColor, formatPeso } from '@/shared/utils/format';
import AuthFileDropZone from '@/modules/auth/components/AuthFileDropZone.vue';
import { uploadDocument } from '@/shared/utils/upload';
import type { Database } from '@/shared/types/database.gen';

type PaymentMethodEnum = Database['public']['Enums']['payment_method'];

interface LeaseRow {
  id: string;
  status: string;
  start_date: string | null;
  end_date: string | null;
  monthly_rent: number | null;
  advance_paid: number | null;
  deposit_paid: number | null;
}

interface PaymentRow {
  id: string;
  month: string | null;
  description: string | null;
  amount: number;
  status: string;
  method: string | null;
  txn_reference: string | null;
}

interface PaymentMethod {
  value: PaymentMethodEnum;
  label: string;
  hint: string;
  icon: string;
  color: string;
}

const $q = useQuasar();
const router = useRouter();

// Data
const loading = ref(true);
const error = ref<string | null>(null);
const lease = ref<LeaseRow | null>(null);
const paymentHistory = ref<PaymentRow[]>([]);

// Dialog states
const methodDialog = ref(false);
const proofDialog = ref(false);
const successDialog = ref(false);
const selectedMethod = ref<string | null>(null);
const amountDue = ref(2500);
const referenceNumber = ref('');
const proofFile = ref<File | null>(null);
const submitting = ref(false);

const paymentMethods: PaymentMethod[] = [
  { value: 'gcash', label: 'GCash', hint: 'Pay via GCash app or QR', icon: 'account_balance_wallet', color: 'blue-8' },
  { value: 'maya', label: 'Maya', hint: 'Pay via Maya app', icon: 'smartphone', color: 'green-8' },
  { value: 'bank', label: 'Bank Transfer', hint: 'Direct bank deposit / InstaPay', icon: 'account_balance', color: 'purple-8' },
  { value: 'cash', label: 'Over-the-Counter', hint: 'Pay at partner outlets (cash)', icon: 'storefront', color: 'orange-8' },
];

// Derived
const totalPaid = computed(() =>
  paymentHistory.value
    .filter((p) => p.status === 'paid')
    .reduce((sum, p) => sum + p.amount, 0),
);

const paidCount = computed(() =>
  paymentHistory.value.filter((p) => p.status === 'paid').length,
);

const totalMonths = computed(() => {
  if (!lease.value?.start_date || !lease.value?.end_date) return 12;
  const start = new Date(lease.value.start_date);
  const end = new Date(lease.value.end_date);
  const months = (end.getFullYear() - start.getFullYear()) * 12 + (end.getMonth() - start.getMonth()) + 1;
  return months > 0 ? months : 12;
});

// Build the progress dots: paid for done months, current for the earliest unpaid
const months = computed(() => {
  const arr: string[] = Array(totalMonths.value).fill('upcoming');
  let paidIdx = paidCount.value;
  for (let i = 0; i < paidIdx; i++) arr[i] = 'paid';
  // Mark the next unpaid month as current
  if (paidIdx < arr.length) arr[paidIdx] = 'current';
  return arr;
});


function formatDate(dateStr: string | null): string {
  if (!dateStr) return '—';
  return new Date(dateStr).toLocaleDateString('en-PH', { year: 'numeric', month: 'short' });
}

function formatMonth(dateStr: string | null): string {
  if (!dateStr) return 'Unspecified';
  return new Date(dateStr).toLocaleDateString('en-PH', { month: 'long', year: 'numeric' });
}

function nextDueMonthValue(): string {
  const base = lease.value?.start_date ? new Date(lease.value.start_date) : new Date();
  const d = new Date(base.getFullYear(), base.getMonth() + paidCount.value, 1);
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, '0');
  return `${y}-${m}-01`;
}

async function loadPayments() {
  loading.value = true;
  error.value = null;
  try {
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) { void router.push('/login'); return; }

    // Active lease
    const { data: leaseData } = await supabase
      .from('leases')
      .select('id, status, start_date, end_date, monthly_rent, advance_paid, deposit_paid')
      .eq('student_id', user.id)
      .eq('status', 'active')
      .maybeSingle();

    lease.value = leaseData as unknown as LeaseRow | null;

    if (lease.value?.id) {
      const { data: payments, error: payError } = await supabase
        .from('payments')
        .select('id, month, description, amount, status, method, txn_reference')
        .eq('lease_id', lease.value.id)
        .order('month', { ascending: false });

      if (payError) throw payError;
      paymentHistory.value = (payments ?? []) as unknown as PaymentRow[];
    } else {
      paymentHistory.value = [];
    }
  } catch (e) {
    error.value = e instanceof Error ? e.message : 'Failed to load payments';
  } finally {
    loading.value = false;
  }
}

function openPaymentMethod(amount: number = 2500) {
  amountDue.value = amount;
  selectedMethod.value = null;
  referenceNumber.value = '';
  proofFile.value = null;
  methodDialog.value = true;
}

function continuePayment() {
  if (!selectedMethod.value) return;
  methodDialog.value = false;
  proofDialog.value = true;
}

async function submitPayment() {
  const file = proofFile.value;
  if (!file) {
    $q.notify({
      message: 'Please attach your proof of payment first.',
      color: 'negative',
      position: 'top',
      classes: 'custom-notify',
      icon: 'error',
    });
    return;
  }
  if (!selectedMethod.value) {
    $q.notify({
      message: 'Please choose a payment method.',
      color: 'negative',
      position: 'top',
      classes: 'custom-notify',
      icon: 'error',
    });
    return;
  }
  if (!lease.value?.id) {
    error.value = 'No active lease found for this payment.';
    return;
  }

  const { data: { user } } = await supabase.auth.getUser();
  if (!user) {
    void router.push('/login');
    return;
  }

  proofDialog.value = false;
  submitting.value = true;
  $q.loading.show({ message: 'Uploading proof & recording payment...' });
  try {
    const proofUrl = await uploadDocument(file, user.id, 'payment_proof');
    const txn = `TXN-${Date.now().toString().slice(-8)}`;
    const { error: insertError } = await supabase
      .from('payments')
      .insert({
        lease_id: lease.value.id,
        amount: amountDue.value,
        method: selectedMethod.value as PaymentMethodEnum,
        month: nextDueMonthValue(),
        status: 'pending_verification',
        proof_url: proofUrl,
        txn_reference: txn,
        description: `Rent payment via ${selectedMethod.value}`,
      });
    if (insertError) throw insertError;
    referenceNumber.value = txn;
    successDialog.value = true;
    await loadPayments();
  } catch (e) {
    error.value = e instanceof Error ? e.message : 'Failed to submit payment';
    $q.notify({
      message: error.value,
      color: 'negative',
      position: 'top',
      classes: 'custom-notify',
      icon: 'error',
    });
  } finally {
    $q.loading.hide();
    submitting.value = false;
    proofFile.value = null;
  }
}

function finishPayment() {
  successDialog.value = false;
  selectedMethod.value = null;
  referenceNumber.value = '';
  proofFile.value = null;
  $q.notify({
    message: 'Payment sent to your landlord for verification.',
    color: 'teal-8',
    position: 'top',
    classes: 'custom-notify',
    icon: 'check_circle',
  });
}

function downloadReceipt(id: string) {
  $q.notify({
    message: 'Receipt download started.',
    color: 'grey-9',
    position: 'top',
    classes: 'custom-notify',
    icon: 'download',
  });
}

onMounted(loadPayments);
</script>

<style scoped>
.custom-card {
  border-radius: 14px;
  background: white;
  box-shadow: 0 2px 6px rgba(0, 0, 0, 0.04);
}

.rounded-full {
  border-radius: 50%;
}

.dialog-card {
  border-radius: 20px 20px 0 0;
}

.method-selected {
  background: #e0f2f1;
}

.success-card {
  border-radius: 20px;
  width: 320px;
  max-width: 90vw;
  background: white;
}

.success-check {
  width: 80px;
  height: 80px;
  border-radius: 50%;
  background: #e0f2f1;
  display: flex;
  align-items: center;
  justify-content: center;
}
</style>
