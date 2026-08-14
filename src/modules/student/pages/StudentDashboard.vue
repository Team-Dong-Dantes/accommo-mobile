<template>
  <q-page class="bg-grey-1 q-pb-md">
    <template v-if="loading">
      <div class="q-pa-md">
        <q-skeleton height="200px" square class="q-mb-md" style="border-radius:16px" />
        <div class="row q-col-gutter-md">
          <div class="col-6"><q-skeleton height="100px" square style="border-radius:16px" /></div>
          <div class="col-6"><q-skeleton height="100px" square style="border-radius:16px" /></div>
        </div>
      </div>
    </template>

    <template v-else>
      <!-- Active Lease Card -->
      <q-card flat class="q-ma-md custom-card overflow-hidden cursor-pointer" @click="goToStay">
        <q-img src="https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?w=600&h=300&fit=crop" height="200px">
          <div class="absolute-full bg-transparent flex flex-center column" style="background: linear-gradient(180deg, rgba(0,0,0,0.1) 0%, rgba(0,0,0,0.7) 100%);">
            <div class="text-white text-weight-bold text-h5">{{ stayTitle }}</div>
            <div class="text-white text-subtitle2 q-mt-xs opacity-8">{{ staySubtitle }}</div>
          </div>
        </q-img>
        <q-card-section class="q-py-sm">
          <div class="row justify-between text-caption text-grey-7 q-mb-xs">
            <span>{{ formatDate(lease?.start_date ?? null) }}</span>
            <span>{{ formatDate(lease?.end_date ?? null) }}</span>
          </div>
          <q-linear-progress :value="leaseProgress" color="teal-8" track-color="grey-3" rounded size="6px" />
          <div class="text-caption text-teal-8 text-weight-bold q-mt-xs text-right">{{ leaseProgressPercent }}% of stay</div>
        </q-card-section>
      </q-card>

      <!-- Landlord + Roommate Grid -->
      <div class="row q-col-gutter-sm q-px-md q-mb-md">
        <div class="col-6">
          <q-card flat bordered class="custom-card cursor-pointer" @click="goToMessages">
            <q-card-section class="q-py-sm">
              <div class="text-caption text-grey-7">Landlord</div>
              <div class="row items-center q-mt-xs">
                <q-avatar size="32px" color="teal-8" text-color="white" class="text-weight-bold">MS</q-avatar>
                <div class="q-ml-sm">
                  <div class="text-subtitle2 text-weight-bold">{{ landlordName }}</div>
                  <div class="text-caption text-grey-6">Santos BH</div>
                </div>
              </div>
            </q-card-section>
          </q-card>
        </div>
        <div class="col-6">
          <q-card flat bordered class="custom-card">
            <q-card-section class="q-py-sm">
              <div class="text-caption text-grey-7">Roommate</div>
              <div class="row items-center q-mt-xs">
                <q-avatar size="32px" color="orange-7" text-color="white" class="text-weight-bold">AB</q-avatar>
                <div class="q-ml-sm">
                  <div class="text-subtitle2 text-weight-bold">Ana Banawa</div>
                  <div class="text-caption text-grey-6">Room 2B</div>
                </div>
              </div>
            </q-card-section>
          </q-card>
        </div>
      </div>

      <!-- Rent Due Alert -->
      <q-card flat class="q-mx-md q-mb-md custom-card" style="background: #FFF3E0;">
        <q-card-section class="q-py-sm row items-center">
          <q-icon name="warning" color="orange-9" size="28px" />
          <div class="q-ml-sm col">
            <div class="text-weight-bold text-orange-9">Rent Due Alert</div>
            <div class="text-caption text-grey-8">{{ paymentTitle }} · {{ paymentSubtitle }}</div>
          </div>
          <q-btn unelevated color="orange-9" label="Pay" class="rounded-borders text-weight-bold" size="sm" no-caps @click="goToPayments" />
        </q-card-section>
      </q-card>

      <!-- Quick Actions -->
      <div class="q-px-md q-mb-md">
        <div class="text-subtitle2 text-weight-bold q-mb-sm">Quick Actions</div>
        <div class="row q-col-gutter-sm">
          <div class="col-6" v-for="action in quickActions" :key="action.label">
            <q-card flat bordered class="custom-card cursor-pointer" @click="action.handler">
              <q-card-section class="text-center q-py-md">
                <q-icon :name="action.icon" :color="action.color" size="28px" />
                <div class="text-caption text-weight-bold q-mt-xs">{{ action.label }}</div>
              </q-card-section>
            </q-card>
          </div>
        </div>
      </div>

      <div v-if="error" class="text-negative text-center q-px-md">{{ error }}</div>
    </template>
  </q-page>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue';
import { useRouter } from 'vue-router';
import { supabase } from '@/shared/utils/supabase';

interface LeaseRow {
  id: string;
  status: string;
  start_date: string | null;
  end_date: string | null;
  monthly_rent: number | null;
  room: {
    room_number: string | null;
    property: { name: string | null; address: string | null } | null;
  } | null;
}

interface PaymentRow {
  amount: number;
  status: string;
  month: string | null;
  description: string | null;
}

const router = useRouter();

const loading = ref(true);
const error = ref<string | null>(null);
const lease = ref<LeaseRow | null>(null);
const nextPayment = ref<PaymentRow | null>(null);
const landlordName = ref('Mario Santos');

const stayTitle = ref('No Active Lease');
const staySubtitle = ref('You are not checked in yet.');
const paymentTitle = ref('\u20B10.00');
const paymentSubtitle = ref('No pending balances');

const quickActions = [
  { label: 'Report Issue', icon: 'report_problem', color: 'amber-8', handler: goToConcerns },
  { label: 'File Complaint', icon: 'gavel', color: 'negative', handler: goToConcerns },
  { label: 'View History', icon: 'history', color: 'teal-7', handler: goToPayments },
  { label: 'Review Stay', icon: 'star', color: 'yellow-8', handler: goToSupport },
];

const leaseProgress = computed(() => {
  if (!lease.value?.start_date || !lease.value?.end_date) return 0;
  const start = new Date(lease.value.start_date).getTime();
  const end = new Date(lease.value.end_date).getTime();
  const now = Date.now();
  if (now <= start) return 0;
  if (now >= end) return 1;
  return (now - start) / (end - start);
});

const leaseProgressPercent = computed(() => Math.round(leaseProgress.value * 100));

function formatPeso(amount: number): string {
  return '\u20B1' + amount.toLocaleString('en-PH', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
}

function formatDate(dateStr: string | null): string {
  if (!dateStr) return '\u2014';
  return new Date(dateStr).toLocaleDateString('en-PH', { month: 'short', day: 'numeric' });
}

function paymentStatusLabel(status: string): string {
  switch (status) {
    case 'overdue': return 'Overdue';
    case 'pending_verification': return 'Awaiting verification';
    case 'due': return 'Due';
    default: return status;
  }
}

async function loadDashboard() {
  loading.value = true;
  error.value = null;
  try {
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) { void router.push('/login'); return; }

    const { data: leaseData, error: leaseError } = await supabase
      .from('leases')
      .select('id, status, start_date, end_date, monthly_rent, room:rooms(room_number, property:properties(name))')
      .eq('student_id', user.id).eq('status', 'active').maybeSingle();

    if (leaseError) throw leaseError;

    if (leaseData) {
      lease.value = leaseData as unknown as LeaseRow;
      const prop = lease.value.room?.property;
      const roomNum = lease.value.room?.room_number;
      stayTitle.value = prop?.name ? `${prop.name}${roomNum ? ' \u00B7 Room ' + roomNum : ''}` : 'Active Lease';
      const rent = lease.value.monthly_rent ?? 0;
      staySubtitle.value = rent > 0 ? `Monthly rent ${formatPeso(rent)}` : 'Active lease \u2014 no rent set';

      const landlordId = (leaseData as unknown as Record<string, string>).landlord_id;
      if (landlordId) {
        const { data: landlord } = await supabase
          .from('users').select('full_name')
          .eq('id', landlordId).maybeSingle();
        if (landlord) landlordName.value = (landlord as unknown as { full_name: string }).full_name;
      }
    }

    if (lease.value?.id) {
      const { data: paymentData } = await supabase
        .from('payments')
        .select('amount, status, month, description')
        .eq('lease_id', lease.value.id)
        .in('status', ['due', 'overdue', 'pending_verification'])
        .order('month', { ascending: true }).maybeSingle();

      if (paymentData) {
        nextPayment.value = paymentData as unknown as PaymentRow;
        paymentTitle.value = formatPeso(nextPayment.value.amount);
        paymentSubtitle.value = [
          paymentStatusLabel(nextPayment.value.status),
          nextPayment.value.month ? formatDate(nextPayment.value.month) : null,
          nextPayment.value.description,
        ].filter((s): s is string => s != null).join(' \u00B7 ');
      }
    }
  } catch (e) {
    error.value = e instanceof Error ? e.message : 'Failed to load dashboard';
  } finally {
    loading.value = false;
  }
}

function goToStay() { void router.push('/student/stay'); }
function goToPayments() { void router.push('/student/payments'); }
function goToConcerns() { void router.push('/student/concerns'); }
function goToSupport() { void router.push('/student/support'); }
function goToMessages() { void router.push('/student/messages'); }

onMounted(loadDashboard);
</script>

<style scoped>
.custom-card {
  border-radius: 16px;
  background: white;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.04);
}

.opacity-8 {
  opacity: 0.8;
}
</style>
