<template>
  <q-page class="dashboard-page bg-grey-1">
    <div class="header-section text-white">
      <div class="row justify-between items-center q-pa-md">
        <h4 class="q-my-none text-weight-bold">Student Hub</h4>
        <q-btn flat round dense icon="logout" @click="handleLogout" />
      </div>
      <div class="q-px-md q-pb-xl">
        <p class="text-subtitle1 text-white-7">Manage your boarding house stay</p>
      </div>
    </div>

    <div class="content-section q-pa-md">
      <div class="row q-col-gutter-md">
        <div class="col-12 col-md-6">
          <q-card flat bordered class="custom-card">
            <q-card-section>
              <div class="text-overline text-teal-9">Current Stay</div>
              <div class="text-h6 q-mt-sm text-weight-bold">{{ stayTitle }}</div>
              <div class="text-subtitle2 text-grey-7">
                {{ staySubtitle }}
              </div>
            </q-card-section>
            <q-card-actions align="right" class="q-pa-md">
              <q-btn unelevated color="teal-9" class="action-btn" label="Find a Room" />
            </q-card-actions>
          </q-card>
        </div>

        <div class="col-12 col-md-6">
          <q-card flat bordered class="custom-card">
            <q-card-section>
              <div class="text-overline text-teal-9">Next Payment</div>
              <div class="text-h4 q-mt-sm text-weight-bold">{{ paymentTitle }}</div>
              <div class="text-subtitle2 text-grey-7">{{ paymentSubtitle }}</div>
            </q-card-section>
          </q-card>
        </div>
      </div>

      <div v-if="error" class="text-negative q-mt-md">{{ error }}</div>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue';
import { useRouter } from 'vue-router';
import { supabase } from '@/utils/supabase';
import { useAuthStore } from '@/stores/auth';

interface LeaseWithRoom {
  id: string;
  status: string;
  start_date: string | null;
  end_date: string | null;
  monthly_rent: number | null;
  room: {
    name: string | null;
    room_number: string | null;
    property: { name: string | null; address: string | null } | null;
  } | null;
}

interface NextPayment {
  amount: number;
  status: string;
  month: string | null;
  description: string | null;
}

const router = useRouter();

const stayTitle = ref('No Active Lease');
const staySubtitle = ref('You are not checked into a boarding house yet.');
const paymentTitle = ref('₱0.00');
const paymentSubtitle = ref('No pending balances');
const error = ref<string | null>(null);

function formatPeso(amount: number): string {
  return '₱' + amount.toLocaleString('en-PH', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
}

async function loadDashboard() {
  error.value = null;
  try {
    const {
      data: { user },
    } = await supabase.auth.getUser();

    if (!user) {
      void router.push('/login');
      return;
    }

    const { data: lease, error: leaseError } = await supabase
      .from('leases')
      .select('id, status, start_date, end_date, monthly_rent, room:rooms(name, room_number, property:properties(name, address))')
      .eq('student_id', user.id)
      .eq('status', 'active')
      .maybeSingle();

    if (leaseError) throw leaseError;

    if (lease) {
      const typedLease = lease as unknown as LeaseWithRoom;
      const propertyName = typedLease.room?.property?.name ?? 'Your boarding house';
      const roomLabel = typedLease.room?.room_number ?? typedLease.room?.name ?? '';
      stayTitle.value = roomLabel ? `${propertyName} · ${roomLabel}` : propertyName;
      const rent = typedLease.monthly_rent ?? 0;
      staySubtitle.value = rent > 0 ? `Monthly rent ${formatPeso(rent)}` : 'Active lease';
    }

    if (lease?.id) {
      const { data: payment, error: paymentError } = await supabase
        .from('payments')
        .select('amount, status, month, description')
        .eq('lease_id', (lease as unknown as LeaseWithRoom).id)
        .in('status', ['due', 'overdue', 'pending_verification'])
        .order('month', { ascending: true })
        .maybeSingle();

      if (paymentError) throw paymentError;

      if (payment) {
        const typedPayment = payment as unknown as NextPayment;
        paymentTitle.value = formatPeso(typedPayment.amount);
        const label =
          typedPayment.status === 'overdue'
            ? 'Overdue'
            : typedPayment.status === 'pending_verification'
              ? 'Awaiting verification'
              : 'Due';
        paymentSubtitle.value = [label, typedPayment.month, typedPayment.description]
          .filter(Boolean)
          .join(' · ');
      }
    }
  } catch (e) {
    error.value = e instanceof Error ? e.message : 'Failed to load dashboard';
  }
}

async function handleLogout() {
  useAuthStore().clearCachedRole();
  await supabase.auth.signOut();
  void router.push('/login');
}

onMounted(loadDashboard);
</script>

<style scoped>
.header-section {
  background: #00796b;
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
.action-btn {
  border-radius: 12px;
  font-weight: 600;
  padding: 8px 24px;
}
</style>
