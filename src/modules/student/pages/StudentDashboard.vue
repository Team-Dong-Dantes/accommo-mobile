<template>
  <q-page class="dashboard-page bg-grey-1">
    <!-- Loading State -->
    <template v-if="loading">
      <div class="header-section text-white">
        <div class="row justify-between items-center q-pa-md">
          <div>
            <q-skeleton type="text" width="200px" class="text-white" />
            <q-skeleton type="text" width="140px" class="text-white" />
          </div>
          <q-skeleton type="circle" size="40px" />
        </div>
      </div>
      <div class="content-section q-pa-md">
        <div class="row q-col-gutter-md">
          <div class="col-12 col-md-6"><q-skeleton height="180px" square class="custom-card" /></div>
          <div class="col-12 col-md-6"><q-skeleton height="180px" square class="custom-card" /></div>
        </div>
      </div>
    </template>

    <!-- Loaded State -->
    <template v-else>
      <div class="header-section text-white">
        <div class="row justify-between items-center q-pa-md">
          <div>
            <h4 class="q-my-none text-weight-bold">Student Hub</h4>
            <p class="text-subtitle1 text-white-7 q-mb-none">
              {{ profile?.program ?? 'Manage your boarding house stay' }}
            </p>
          </div>
          <q-btn flat round dense icon="logout" @click="handleLogout" />
        </div>
        <div class="q-px-md q-pb-xl">
          <div class="row items-center">
            <q-avatar size="56px" color="blue" text-color="white" class="text-weight-bold">
              {{ profile?.initials ?? initials ?? 'UN' }}
            </q-avatar>
            <div class="q-ml-md">
              <div class="text-h6 text-weight-bold">{{ profile?.full_name ?? 'Student' }}</div>
              <div class="text-subtitle2 text-white-7">
                {{ profile?.college ? shortCollege(profile.college) : '' }}
                {{ profile?.year_level ? `· Year ${profile.year_level}` : '' }}
              </div>
            </div>
          </div>
        </div>
      </div>

      <div class="content-section q-pa-md">
        <!-- Lease Card -->
        <q-card flat bordered class="custom-card q-mb-md">
          <q-card-section>
            <div class="row items-center">
              <q-icon name="bed" size="28px" color="teal-9" class="q-mr-sm" />
              <div>
                <div class="text-overline text-teal-9">Current Stay</div>
                <div class="text-h6 q-mt-xs text-weight-bold">{{ stayTitle }}</div>
                <div class="text-subtitle2 text-grey-7">{{ staySubtitle }}</div>
              </div>
            </div>
          </q-card-section>
          <q-separator v-if="lease" />
          <q-card-section v-if="lease">
            <div class="row q-col-gutter-sm text-caption text-grey-7">
              <div class="col-6">
                <div class="text-weight-medium text-grey-9">Move-in</div>
                <div>{{ formatDate(lease.start_date) }}</div>
              </div>
              <div class="col-6">
                <div class="text-weight-medium text-grey-9">Move-out</div>
                <div>{{ formatDate(lease.end_date) }}</div>
              </div>
            </div>
          </q-card-section>
          <q-card-actions align="right" class="q-pa-md">
            <q-btn unelevated color="teal-9" class="action-btn" label="Find a Room" @click="goToFindRoom" />
          </q-card-actions>
        </q-card>

        <!-- Payments Card -->
        <q-card flat bordered class="custom-card q-mb-md">
          <q-card-section>
            <div class="row items-center">
              <q-icon name="payments" size="28px" color="teal-9" class="q-mr-sm" />
              <div>
                <div class="text-overline text-teal-9">Payments</div>
                <div class="text-h6 q-mt-xs text-weight-bold">{{ paymentTitle }}</div>
                <div class="text-subtitle2 text-grey-7">{{ paymentSubtitle }}</div>
              </div>
            </div>
          </q-card-section>
          <q-card-actions v-if="nextPayment" align="right" class="q-pa-md">
            <q-btn
              flat
              color="teal-9"
              class="text-weight-bold"
              label="Pay Now"
              @click="goToPayments"
            />
          </q-card-actions>
        </q-card>

        <!-- Quick Actions -->
        <div class="text-subtitle1 text-weight-bold q-mb-sm">Quick Actions</div>
        <div class="row q-col-gutter-sm">
          <div class="col-6">
            <q-card flat bordered class="custom-card cursor-pointer" @click="goToConcerns">
              <q-card-section class="text-center q-py-md">
                <q-icon name="report_problem" size="32px" color="amber-8" />
                <div class="text-subtitle2 text-weight-bold q-mt-sm">Report Concern</div>
                <div class="text-caption text-grey-7">Maintenance or issue</div>
              </q-card-section>
            </q-card>
          </div>
          <div class="col-6">
            <q-card flat bordered class="custom-card cursor-pointer" @click="goToComplaints">
              <q-card-section class="text-center q-py-md">
                <q-icon name="gavel" size="32px" color="negative" />
                <div class="text-subtitle2 text-weight-bold q-mt-sm">File Complaint</div>
                <div class="text-caption text-grey-7">Dispute with landlord</div>
              </q-card-section>
            </q-card>
          </div>
          <div class="col-6">
            <q-card flat bordered class="custom-card cursor-pointer" @click="goToMessages">
              <q-card-section class="text-center q-py-md">
                <q-icon name="chat" size="32px" color="blue-7" />
                <div class="text-subtitle2 text-weight-bold q-mt-sm">Messages</div>
                <div class="text-caption text-grey-7">Chat with landlord</div>
              </q-card-section>
            </q-card>
          </div>
          <div class="col-6">
            <q-card flat bordered class="custom-card cursor-pointer" @click="goToHistory">
              <q-card-section class="text-center q-py-md">
                <q-icon name="history" size="32px" color="teal-7" />
                <div class="text-subtitle2 text-weight-bold q-mt-sm">History</div>
                <div class="text-caption text-grey-7">Past stays & payments</div>
              </q-card-section>
            </q-card>
          </div>
        </div>

        <div v-if="error" class="text-negative q-mt-md text-center">{{ error }}</div>
      </div>
    </template>
  </q-page>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue';
import { useRouter } from 'vue-router';
import { supabase } from '@/shared/utils/supabase';
import { useAuthStore } from '@/stores/auth';

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

interface StudentProfileRow {
  student_id: string | null;
  college: string | null;
  program: string | null;
  year_level: number | null;
  full_name?: string | null;
  initials?: string | null;
}

interface UserRow {
  full_name: string | null;
  initials: string | null;
}

const router = useRouter();
const authStore = useAuthStore();

const loading = ref(true);
const error = ref<string | null>(null);

const profile = ref<StudentProfileRow | null>(null);
const initials = ref<string | null>(null);
const lease = ref<LeaseRow | null>(null);
const nextPayment = ref<PaymentRow | null>(null);

// Derived display values
const stayTitle = ref('No Active Lease');
const staySubtitle = ref('You are not checked into a boarding house yet.');
const paymentTitle = ref('₱0.00');
const paymentSubtitle = ref('No pending balances');

function formatPeso(amount: number): string {
  return (
    '₱' +
    amount.toLocaleString('en-PH', {
      minimumFractionDigits: 2,
      maximumFractionDigits: 2,
    })
  );
}

function formatDate(dateStr: string | null): string {
  if (!dateStr) return '—';
  const d = new Date(dateStr);
  return d.toLocaleDateString('en-PH', { year: 'numeric', month: 'short', day: 'numeric' });
}

function shortCollege(full: string): string {
  const match = full.match(/\(([^)]+)\)/);
  return match?.[1] ?? full;
}

function paymentStatusLabel(status: string): string {
  switch (status) {
    case 'overdue':
      return 'Overdue';
    case 'pending_verification':
      return 'Awaiting verification';
    case 'due':
      return 'Due';
    default:
      return status;
  }
}

async function loadDashboard() {
  loading.value = true;
  error.value = null;
  try {
    const {
      data: { user },
    } = await supabase.auth.getUser();

    if (!user) {
      void router.push('/login');
      return;
    }

    // Load profile from public.users + student_profiles in parallel
    const [userResult, studentProfileResult] = await Promise.all([
      supabase.from('users').select('full_name, initials').eq('id', user.id).maybeSingle(),
      supabase
        .from('student_profiles')
        .select('student_id, college, program, year_level')
        .eq('user_id', user.id)
        .maybeSingle(),
    ]);

    if (userResult.data) {
      const u = userResult.data as unknown as UserRow;
      initials.value = u.initials ?? null;
      // Also set the profile with user data for the header
      profile.value = {
        student_id: null,
        college: null,
        program: null,
        year_level: null,
        full_name: u.full_name,
        initials: u.initials,
      };
    }

    if (studentProfileResult.data) {
      profile.value = {
        ...(profile.value ?? ({} as StudentProfileRow)),
        ...(studentProfileResult.data as unknown as StudentProfileRow),
      };
    }

    // Load active lease
    const { data: leaseData, error: leaseError } = await supabase
      .from('leases')
      .select(
        'id, status, start_date, end_date, monthly_rent, room:rooms(room_number, property:properties(name, address))',
      )
      .eq('student_id', user.id)
      .eq('status', 'active')
      .maybeSingle();

    if (leaseError) throw leaseError;

    if (leaseData) {
      lease.value = leaseData as unknown as LeaseRow;
      const prop = lease.value.room?.property;
      const roomNum = lease.value.room?.room_number;
      stayTitle.value = prop?.name
        ? `${prop.name}${roomNum ? ` · Room ${roomNum}` : ''}`
        : 'Active Lease';
      const rent = lease.value.monthly_rent ?? 0;
      staySubtitle.value =
        rent > 0
          ? `Monthly rent ${formatPeso(rent)}`
          : 'Active lease — no rent set';
    }

    // Load next pending payment
    if (leaseData?.id) {
      const { data: paymentData, error: paymentError } = await supabase
        .from('payments')
        .select('amount, status, month, description')
        .eq('lease_id', (leaseData as unknown as LeaseRow).id)
        .in('status', ['due', 'overdue', 'pending_verification'])
        .order('month', { ascending: true })
        .maybeSingle();

      if (paymentError) throw paymentError;

      if (paymentData) {
        nextPayment.value = paymentData as unknown as PaymentRow;
        paymentTitle.value = formatPeso(nextPayment.value.amount);
        const label = paymentStatusLabel(nextPayment.value.status);
        paymentSubtitle.value = [
          label,
          nextPayment.value.month
            ? formatDate(nextPayment.value.month)
            : null,
          nextPayment.value.description,
        ]
          .filter((s): s is string => s != null)
          .join(' · ');
      }
    }
  } catch (e) {
    error.value = e instanceof Error ? e.message : 'Failed to load dashboard';
  } finally {
    loading.value = false;
  }
}

function handleLogout() {
  authStore.clearCachedRole();
  supabase.auth.signOut().finally(() => {
    void router.push('/login');
  });
}

function goToFindRoom() {
  // Placeholder — will navigate to room search when built
  void router.push('/student/stay');
}

function goToPayments() {
  void router.push('/student/stay');
}

function goToConcerns() {
  void router.push('/student/stay');
}

function goToComplaints() {
  void router.push('/student/stay');
}

function goToMessages() {
  void router.push('/student/stay');
}

function goToHistory() {
  void router.push('/student/stay');
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
