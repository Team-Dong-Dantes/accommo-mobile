<template>
  <q-page class="bg-grey-1 q-pb-xl">
    <div class="row justify-between items-center q-pa-md">
      <div>
        <div class="text-h5 text-weight-bold">Payments</div>
        <div class="text-subtitle2 text-grey-6">Track your rent & deposit</div>
      </div>
      <q-btn unelevated color="teal-8" icon="payment" label="Pay" class="rounded-borders text-weight-bold" no-caps @click="payNow" />
    </div>

    <div class="q-px-md q-mb-md">
      <div class="text-subtitle2 text-weight-bold q-mb-sm">
        Payment Progress <span class="text-teal-8">· 3 of 12 months paid</span>
      </div>
      <div class="row">
        <div v-for="m in months" :key="m.label" class="column items-center" style="flex:1">
          <div
            class="rounded-full"
            :class="m.status === 'paid' ? 'bg-teal-8' : m.status === 'current' ? 'bg-amber-5' : 'bg-grey-3'"
            style="width:24px;height:24px;display:flex;align-items:center;justify-content:center"
          >
            <q-icon v-if="m.status === 'paid'" name="check" size="14px" color="white" />
            <span v-else-if="m.status === 'current'" class="text-white text-weight-bold" style="font-size:11px">!</span>
          </div>
          <div class="text-caption q-mt-xs" :class="m.status === 'current' ? 'text-weight-bold text-amber-9' : 'text-grey-5'" style="font-size:10px">
            {{ m.label }}
          </div>
        </div>
      </div>
    </div>

    <div class="row q-col-gutter-sm q-px-md q-mb-md">
      <div class="col-6">
        <q-card flat bordered class="custom-card">
          <q-card-section>
            <div class="text-caption text-grey-7">Total Paid</div>
            <div class="text-h5 text-weight-bold q-mt-xs">₱7,500</div>
            <div class="text-caption text-teal-8 text-weight-medium">3 months covered</div>
          </q-card-section>
        </q-card>
      </div>
      <div class="col-6">
        <q-card flat bordered class="custom-card">
          <q-card-section>
            <div class="text-caption text-grey-7">Security Deposit</div>
            <div class="text-h5 text-weight-bold q-mt-xs">₱2,500</div>
            <div class="text-caption text-blue-8 text-weight-medium">Refundable</div>
          </q-card-section>
        </q-card>
      </div>
    </div>

    <div class="q-px-md q-mb-md">
      <div class="text-subtitle1 text-weight-bold q-mb-sm">Lease Summary</div>
      <q-card flat bordered class="custom-card">
        <q-list dense separator>
          <q-item><q-item-section>Monthly Rent</q-item-section><q-item-section side class="text-weight-bold">₱2,500</q-item-section></q-item>
          <q-item><q-item-section>Advance Paid</q-item-section><q-item-section side class="text-weight-bold">₱2,500</q-item-section></q-item>
          <q-item><q-item-section>Deposit Paid</q-item-section><q-item-section side class="text-weight-bold">₱2,500</q-item-section></q-item>
          <q-item><q-item-section>Lease Period</q-item-section><q-item-section side class="text-weight-medium">Aug 2026 – May 2027</q-item-section></q-item>
          <q-item><q-item-section>Status</q-item-section><q-item-section side><q-badge color="teal-8" label="Active" class="q-px-sm" /></q-item-section></q-item>
        </q-list>
      </q-card>
    </div>

    <div class="q-px-md">
      <div class="text-subtitle1 text-weight-bold q-mb-sm">Payment History</div>
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
            <q-item-label class="text-weight-bold">{{ payment.month }}</q-item-label>
            <q-item-label caption>{{ payment.description }}</q-item-label>
          </q-item-section>
          <q-item-section side>
            <div class="text-weight-bold text-right">{{ formatPeso(payment.amount) }}</div>
            <div class="q-mt-xs text-right">
              <q-btn
                v-if="payment.status === 'due'"
                unelevated color="teal-8" label="Pay Now" size="sm" dense no-caps
                class="rounded-borders text-weight-bold"
                @click="payNow"
              />
              <q-badge v-else-if="payment.status === 'overdue'" color="negative" label="Overdue" />
              <q-btn v-else flat dense icon="download" color="grey-6" size="sm" round @click="downloadReceipt(payment.id)" />
            </div>
          </q-item-section>
        </q-item>
      </q-card>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { useQuasar } from 'quasar';

interface PaymentHistoryItem {
  id: number;
  month: string;
  description: string;
  amount: number;
  status: 'paid' | 'due' | 'overdue' | 'pending_verification';
}

interface MonthTracker {
  label: string;
  status: 'paid' | 'current' | 'upcoming';
}

const $q = useQuasar();

const months: MonthTracker[] = [
  { label: 'Aug', status: 'paid' }, { label: 'Sep', status: 'paid' }, { label: 'Oct', status: 'paid' },
  { label: 'Nov', status: 'current' }, { label: 'Dec', status: 'upcoming' }, { label: 'Jan', status: 'upcoming' },
  { label: 'Feb', status: 'upcoming' }, { label: 'Mar', status: 'upcoming' }, { label: 'Apr', status: 'upcoming' },
  { label: 'May', status: 'upcoming' }, { label: 'Jun', status: 'upcoming' }, { label: 'Jul', status: 'upcoming' },
];

const paymentHistory: PaymentHistoryItem[] = [
  { id: 1, month: 'November 2026', description: 'Monthly rent - November', amount: 2500, status: 'due' },
  { id: 2, month: 'October 2026', description: 'Monthly rent - October', amount: 2500, status: 'paid' },
  { id: 3, month: 'September 2026', description: 'Monthly rent - September', amount: 2500, status: 'paid' },
  { id: 4, month: 'August 2026', description: 'Monthly rent + advance deposit', amount: 5000, status: 'paid' },
];

function formatPeso(amount: number): string {
  return '\u20B1' + amount.toLocaleString('en-PH', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
}

function payNow() {
  $q.notify({ message: 'Payment gateway will open here.', color: 'teal-8', position: 'top', classes: 'custom-notify' });
}

function downloadReceipt(id: number) {
  $q.notify({ message: `Receipt #${id} download started.`, color: 'grey-9', position: 'top', classes: 'custom-notify', icon: 'download' });
}
</script>

<style scoped>
.custom-card {
  border-radius: 14px;
  background: white;
  box-shadow: 0 2px 6px rgba(0,0,0,0.04);
}
.rounded-full {
  border-radius: 50%;
}
</style>
