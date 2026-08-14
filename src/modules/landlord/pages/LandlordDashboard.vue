<template>
  <q-page class="dashboard-page bg-grey-1">
    <div class="header-section text-white">
      <div class="row justify-between items-center q-pa-md">
        <div>
          <h4 class="q-my-none text-weight-bold">{{ businessName }}</h4>
          <p class="text-subtitle1 text-white-7 q-mb-none">
            Overview of your properties and tenants
          </p>
        </div>
        <q-btn flat round dense icon="logout" @click="handleLogout" />
      </div>
    </div>

    <div class="content-section q-pa-md">
      <div class="row q-col-gutter-md">
        <div class="col-12 col-sm-6 col-md-4">
          <q-card flat bordered class="custom-card">
            <q-card-section>
              <div class="text-overline text-teal-9">Active Tenants</div>
              <div class="text-h3 q-mt-sm text-weight-bold">{{ activeTenants }}</div>
              <div class="text-subtitle2 text-grey-7">
                {{ activeTenantsLabel }}
              </div>
            </q-card-section>
          </q-card>
        </div>

        <div class="col-12 col-sm-6 col-md-4">
          <q-card flat bordered class="custom-card">
            <q-card-section>
              <div class="text-overline text-teal-9">Pending Payments</div>
              <div class="text-h3 q-mt-sm text-weight-bold">{{ pendingPayments }}</div>
              <div class="text-subtitle2 text-grey-7">{{ pendingAmountLabel }}</div>
            </q-card-section>
            <q-card-actions align="right" class="q-pa-md">
              <q-btn flat color="teal-9" class="text-weight-bold" label="View Details" />
            </q-card-actions>
          </q-card>
        </div>

        <div class="col-12 col-md-4">
          <q-card flat bordered class="custom-card">
            <q-card-section>
              <div class="text-overline text-teal-9">Properties</div>
              <div class="text-h3 q-mt-sm text-weight-bold">{{ properties.length }}</div>
              <div class="text-subtitle2 text-grey-7">{{ propertiesSubtitle }}</div>
            </q-card-section>
            <q-card-actions align="right" class="q-pa-md">
              <q-btn unelevated color="teal-9" class="action-btn" label="Add Property" @click="goToAddProperty" />
            </q-card-actions>
          </q-card>
        </div>
      </div>

      <template v-if="verificationRequests.length > 0">
        <h6 class="q-my-md text-weight-bold">Payment Requests</h6>
        <q-list bordered separator class="rounded-borders bg-white">
          <q-item v-for="payment in verificationRequests" :key="payment.id">
            <q-item-section>
              <q-item-label class="text-weight-bold">
                {{ payment.lease?.student?.full_name ?? 'Student' }} ·
                {{ formatPeso(payment.amount) }}
              </q-item-label>
              <q-item-label caption>
                {{ payment.month ?? 'Unspecified month' }} ·
                {{ payment.lease?.room?.property?.name ?? 'Property' }}
                {{ payment.lease?.room?.room_number ?? '' }}
              </q-item-label>
            </q-item-section>
            <q-item-section side>
              <q-badge color="amber" label="Awaiting review" />
            </q-item-section>
          </q-item>
        </q-list>
      </template>

      <h6 class="q-my-md text-weight-bold">Your Properties</h6>
      <q-list v-if="properties.length > 0" bordered separator class="rounded-borders bg-white">
        <q-item v-for="property in properties" :key="property.id">
          <q-item-section>
            <q-item-label class="text-weight-bold">{{ property.name }}</q-item-label>
            <q-item-label caption>{{ property.address || 'No address set' }}</q-item-label>
          </q-item-section>
          <q-item-section side>
            <q-badge :color="statusColor(property.status)" :label="property.status" />
          </q-item-section>
        </q-item>
      </q-list>
      <q-card v-else flat bordered class="custom-card q-mt-sm">
        <q-card-section class="text-center">
          <div class="text-subtitle2 text-grey-7 q-py-md">
            No properties yet — tap "Add Property" to get started.
          </div>
        </q-card-section>
      </q-card>

      <div v-if="error" class="text-negative q-mt-md">{{ error }}</div>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue';
import { useRouter } from 'vue-router';
import { supabase } from '@/shared/utils/supabase';
import { useAuthStore } from '@/stores/auth';
import { createNotification, fetchNotifications, showToast } from '@/boot/notify';

// Check if running in demo mode (same pattern as supabase.ts)
const isDemoMode = (import.meta.env.VITE_DEMO_MODE as unknown) === 'true';

interface PropertyRow {
  id: string;
  name: string;
  address: string | null;
  status: string;
}

interface PaymentWithDetails {
  id: string;
  amount: number;
  status: string;
  month: string | null;
  lease: {
    student: { full_name: string } | null;
    room: {
      room_number: string | null;
      property: { name: string | null } | null;
    } | null;
  } | null;
}

interface NotificationPreview {
  id: string;
  title: string;
  body: string;
  type: string;
  read_at: string | null;
}

const router = useRouter();

const businessName = ref('Property Manager');
const activeTenants = ref(0);
const activeTenantsLabel = ref('No tenants yet');
const pendingPayments = ref(0);
const pendingAmountLabel = ref('No pending balances');
const verificationRequests = ref<PaymentWithDetails[]>([]);
const properties = ref<PropertyRow[]>([]);
const propertiesSubtitle = ref('No properties listed');
const error = ref<string | null>(null);
const notifications = ref<NotificationPreview[]>([]);
const unreadCount = ref(0);

function formatPeso(amount: number): string {
  return '₱' + amount.toLocaleString('en-PH', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
}

function statusColor(status: string): string {
  switch (status) {
    case 'accredited':
      return 'teal';
    case 'reviewing':
      return 'blue';
    case 'pending':
      return 'amber';
    case 'rejected':
      return 'negative';
    case 'delisted':
      return 'grey';
    default:
      return 'grey';
  }
}

// Show a toast notification using Quasar Notify
function showLandlordToast(title: string, body: string, type: 'positive' | 'negative' | 'warning' | 'info' = 'info') {
  showToast(title, body, type);
}

// Fetch notifications for the current landlord
async function loadNotifications() {
  try {
    // In demo mode, skip Supabase queries and show empty state
    if (isDemoMode) {
      notifications.value = [];
      unreadCount.value = 0;
      showToast('Demo Mode', 'Connect to real Supabase for full notification functionality', 'info');
      return;
    }

    const {
      data: { user },
      error: userError,
    } = await supabase.auth.getUser();

    if (!user) return;

    const fetched = await fetchNotifications(user.id);
    notifications.value = fetched.map((n: any) => ({
      id: n.id,
      title: n.title,
      body: n.body,
      type: n.type,
      read_at: n.read_at,
    }));

    // Update unread count
    unreadCount.value = fetched.filter((n: any) => !n.read_at).length;
  } catch (e) {
    console.error('Failed to load notifications:', e);
    if (isDemoMode) {
      // Already handled above, but just in case
      notifications.value = [];
      unreadCount.value = 0;
    }
  }
}

async function handleLogout() {
  useAuthStore().clearCachedRole();
  await supabase.auth.signOut();
  void router.push('/login');
}

function goToAddProperty() {
  void router.push('/landlord/properties/new');
}

// Load dashboard data (tenants, payments, properties)
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

    // Business name from accreditation profile
    const { data: landlordProfile, error: profileError } = await supabase
      .from('landlord_profiles')
      .select('business_name')
      .eq('user_id', user.id)
      .maybeSingle();

    if (profileError) throw profileError;
    if (landlordProfile?.business_name) {
      businessName.value = landlordProfile.business_name;
    }

    // Properties owned by this landlord
    const { data: props, error: propsError } = await supabase
      .from('properties')
      .select('id, name, address, status')
      .eq('landlord_id', user.id)
      .order('name');

    if (propsError) throw propsError;
    properties.value = (props ?? []) as unknown as PropertyRow[];

    const accreditedCount = properties.value.filter((property) => property.status === 'accredited').length;
    propertiesSubtitle.value =
      properties.value.length === 0
        ? 'Add a property to start accepting tenants.'
        : `${accreditedCount} accredited · ${properties.value.length} total`;

    // Active leases = current tenants
    const { data: leases, error: leasesError } = await supabase
      .from('leases')
      .select('id')
      .eq('landlord_id', user.id)
      .eq('status', 'active');

    if (leasesError) throw leasesError;
    activeTenants.value = leases?.length ?? 0;
    activeTenantsLabel.value =
      activeTenants.value === 1
        ? '1 tenant staying right now'
        : activeTenants.value > 1
          ? `${activeTenants.value} tenants staying right now`
          : 'No tenants yet';

    // Payments needing attention across this landlord's leases
    const { data: payments, error: paymentsError } = await supabase
      .from('payments')
      .select(
        'id, amount, status, month, lease:leases(student:users(full_name), room:rooms(room_number, property:properties(name)))',
      )
      .in('status', ['due', 'overdue', 'pending_verification'])
      .eq('lease.landlord_id', user.id);

    if (paymentsError) throw paymentsError;
    const typedPayments = (payments ?? []) as unknown as PaymentWithDetails[];
    pendingPayments.value = typedPayments.length;
    pendingAmountLabel.value =
      typedPayments.length > 0
        ? `${formatPeso(typedPayments.reduce((sum, payment) => sum + payment.amount, 0))} outstanding`
        : 'No pending balances';
    verificationRequests.value = typedPayments.filter(
      (payment) => payment.status === 'pending_verification',
    );
  } catch (e) {
    error.value = e instanceof Error ? e.message : 'Failed to load dashboard';
  }
}

onMounted(() => {
  loadDashboard();
  loadNotifications();
});
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
.action-btn {
  border-radius: 12px;
  font-weight: 600;
  padding: 8px 24px;
}
</style>
