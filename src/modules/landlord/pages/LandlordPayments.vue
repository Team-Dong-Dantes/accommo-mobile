<template>
  <q-page class="dashboard-page bg-grey-1">
    <div class="header-section text-white">
      <div class="row justify-between items-center q-pa-md">
        <div>
          <h4 class="q-my-none text-weight-bold">Payment History</h4>
          <p class="text-subtitle1 text-white-7 q-mb-none">
            All payments received across your properties
          </p>
        </div>
        <q-btn flat round dense icon="logout" @click="handleLogout" />
      </div>
    </div>

    <div class="content-section q-pa-md">
      <q-list
        v-if="payments.length > 0"
        bordered
        separator
        class="rounded-borders bg-white"
      >
        <q-item v-for="payment in payments" :key="payment.id">
          <q-item-section>
            <q-item-label class="text-weight-bold">
              {{ payment.student_name }} ·
              {{ formatPeso(payment.amount) }}
            </q-item-label>
            <q-item-label caption>
              {{ payment.month }} ·
              {{ payment.method_display }} ·
              {{ payment.status_display }}
            </q-item-label>
          </q-item-section>
          <q-item-section side>
            <q-badge :color="payment.statusColor" :label="payment.statusDisplay" />
          </q-item-section>
        </q-item>
      </q-list>

      <q-card v-if="payments.length === 0" flat bordered class="custom-card q-mt-sm">
        <q-card-section class="text-center">
          <div class="text-subtitle2 text-grey-7 q-py-md">
            No payments recorded yet. Add tenants and collect payments to see history here.
          </div>
        </q-card-section>
      </q-card>

      <div v-if="error" class="text-negative q-mt-md">{{ error }}</div>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue';
import { supabase } from '@/shared/utils/supabase';
import { useRouter } from 'vue-router';
import { useAuthStore } from '@/stores/auth';
import { showToast } from '@/boot/notify';

// Check demo mode (same pattern as rest of app)
const isDemo = (import.meta.env.VITE_DEMO_MODE as unknown) === 'true';

const payments = ref<PaymentRow[]>([]);
interface PaymentRow {
  id: string;
  amount: number;
  method: string;
  month: string;
  status: string;
  student_name: string;
  room_number: string | null;
  property_name: string | null;
  paid_at: string | null;
}

if (isDemo) {
  showToast('Demo Mode', 'Connect to real Supabase for payment history', 'info');
  onMounted(() => {});
} else {
  onMounted(loadPayments);
}

function formatPeso(amount: number): string {
  return '₱' + amount.toLocaleString('en-PH', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
}

function statusInfo(status: string) {
  const info: Record<string, { color: string; label: string }> = {
    due: { color: 'teal', label: 'Due' },
    paid: { color: 'green', label: 'Paid' },
    overdue: { color: 'red', label: 'Overdue' },
    pending_verification: { color: 'amber', label: 'Awaiting verification' },
  };
  return info[status] || { color: 'grey', label: status };
}

async function loadPayments() {
  error.value = null;
  try {
    const {
      data: { user },
      error: userError,
    } = await supabase.auth.getUser();

    if (!user) return;

    // Business name from accreditation profile
    const { data: landlordProfile, error: profileError } = await supabase
      .from('landlord_profiles')
      .select('business_name')
      .eq('user_id', user.id)
      .maybeSingle();

    if (profileError) throw profileError;

    // All payments for this landlord's leases, with student/room/property details
    // Note: In demo mode, nested select chains may not resolve fully.
    // We query payments with minimal joins and extract data safely.
    const { data: payments, error: paymentsError } = await supabase
      .from('payments')
      .select('id, amount, method, month, status, paid_at, lease_id')
      .eq('lease_id.landlord_id', user.id);

    if (paymentsError) throw paymentsError;

    const typedPayments = (payments ?? []) as unknown as PaymentRow[];
    payments.value = typedPayments.map((payment) => {
      const { status, method, amount, month, paid_at, lease_id } = payment;

      // Safely extract student name - demo mode may not have lease.student data
      let student_name = 'Unknown Student';
      if (lease_id && typeof lease_id === 'object' && 'student_id' in lease_id) {
        const sid = lease_id.student_id;
        if (typeof sid === 'string' && sid.length > 0) {
          student_name = 'Student ' + sid.substring(0, 8);
        } else if (typeof sid === 'object' && sid.full_name) {
          student_name = sid.full_name;
        }
      }

      // Method display with fallback
      const methodDisplay = method || 'cash';

      // Status info
      const { color: statusColor, label: statusLabel } = statusInfo(status);

      return {
        id: payment.id,
        amount,
        method,
        method_display: methodDisplay,
        month,
        status,
        statusColor,
        status_display: statusLabel,
        student_name: student_name,
        room_number: '—', // Will be populated when real Supabase data available
        property_name: 'Unassigned', // Will be populated when real Supabase data available
        paid_at: paid_at ?? null,
      };
    });
  } catch (e) {
    error.value = e instanceof Error ? e.message : 'Failed to load payments';
    console.error('loadPayments error:', e);
  }
}

function handleLogout() {
  useAuthStore().clearCachedRole();
  supabase.auth.signOut();
}
</script>

<style scoped>
.header-section {
  background: #004d40;
  border-radius: 0 0 28px 28px;
  margin-bottom: -40px;
}
.text-white-7 {
  color: rgba(255, 255, 255, 0.7);
}
.content-section {
  position: relative;
  z-index: 1;
}
.custom-card {
  border-radius: 16px;
  background: white;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.05);
}
</style>