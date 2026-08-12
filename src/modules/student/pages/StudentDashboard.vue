<template>
  <q-layout view="hHh lpR fFf" class="bg-grey-1">
    <!-- Transparent Global Header -->
    <q-header elevated class="bg-transparent text-dark" style="backdrop-filter: blur(10px); -webkit-backdrop-filter: blur(10px);">
      <q-toolbar>
        <q-toolbar-title class="text-weight-bold">accommo</q-toolbar-title>
        <q-btn flat round dense @click="handleLogout">
          <q-avatar size="36px" color="blue" text-color="white" class="text-weight-bold">
            {{ userInitials }}
          </q-avatar>
        </q-btn>
      </q-toolbar>
    </q-header>

    <q-page-container>
      <q-page class="q-pb-xl">
        <!-- HOME TAB -->
        <div v-if="tab === 'home'" class="animate-fade">
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
        </div>

        <!-- DISCOVER TAB -->
        <div v-if="tab === 'discover'" class="animate-fade q-pa-md">
          <div class="row q-col-gutter-sm q-mb-md">
            <div class="col">
              <q-input v-model="searchQuery" outlined dense placeholder="Search rooms, barangay, type..." bg-color="white" class="rounded-input" />
            </div>
            <div class="col-auto">
              <q-btn outline icon="tune" label="Filter" color="grey-8" class="bg-white rounded-borders" no-caps />
            </div>
          </div>

          <div class="text-h6 text-weight-bold q-mb-md">Available Rooms <span class="text-teal-8">(11)</span></div>

          <q-card v-for="room in discoverRooms" :key="room.id" flat bordered class="q-mb-md custom-card overflow-hidden">
            <q-img :src="room.image" height="180px">
              <div class="absolute-top-left bg-transparent q-pa-sm">
                <q-chip color="white" text-color="orange" dense icon="bed" size="sm" class="text-weight-bold">{{ room.type }}</q-chip>
              </div>
              <div class="absolute-top-right bg-transparent q-pa-sm">
                <q-btn round flat color="white" icon="favorite_border" size="sm" class="bg-white-5" />
              </div>
              <div class="absolute-bottom bg-transparent q-pa-sm row justify-between items-end">
                <div>
                  <div class="text-h6 text-weight-bold text-white">{{ room.name }}</div>
                  <div class="text-caption text-white">{{ room.property }}</div>
                </div>
                <div class="bg-black text-white q-px-sm q-py-xs text-weight-bold" style="border-radius:8px">{{ formatPeso(room.rent) }}/mo</div>
              </div>
            </q-img>
            <q-card-section>
              <div class="text-caption text-grey-7 q-mb-sm row items-center">
                <q-icon name="place" class="q-mr-xs" /> {{ room.address }}
              </div>
              <div class="row justify-between items-center q-mb-md">
                <div class="row q-gutter-xs">
                  <q-chip v-for="amenity in room.amenities" :key="amenity.icon" dense outline :color="amenity.color" :icon="amenity.icon" size="sm">{{ amenity.label }}</q-chip>
                </div>
                <div class="text-caption text-grey-6">{{ room.floor }} · {{ room.slots }} slot{{ room.slots > 1 ? 's' : '' }} left</div>
              </div>
              <div class="row justify-between items-center">
                <div class="row items-center">
                  <q-avatar :color="room.landlord.color" text-color="white" size="32px" class="q-mr-sm">{{ room.landlord.initials }}</q-avatar>
                  <span class="text-weight-bold text-caption">{{ room.landlord.name }}</span>
                </div>
                <q-btn unelevated color="dark" label="View Details" class="rounded-borders text-caption text-weight-bold" no-caps />
              </div>
            </q-card-section>
          </q-card>
        </div>

        <!-- MESSAGES TAB -->
        <div v-if="tab === 'messages'" class="animate-fade q-pa-md">
          <div class="text-h4 text-weight-bold" style="letter-spacing: -0.5px">Messages</div>
          <div class="text-grey-6 q-mb-md">Landlord conversations</div>

          <q-input v-model="messageSearchQuery" outlined dense placeholder="Search conversations..." bg-color="white" class="q-mb-md rounded-input" />

          <q-list class="bg-white custom-card" bordered separator>
            <q-item v-for="chat in recentChats" :key="chat.id" clickable v-ripple class="q-py-md">
              <q-item-section avatar>
                <q-avatar :color="chat.avatarColor" text-color="white" size="48px">{{ chat.initials }}</q-avatar>
                <q-badge v-if="chat.unread" color="teal-8" floating rounded>{{ chat.unread }}</q-badge>
              </q-item-section>
              <q-item-section>
                <q-item-label class="text-weight-bold">{{ chat.name }}</q-item-label>
                <q-item-label caption>{{ chat.lastMessage }}</q-item-label>
              </q-item-section>
              <q-item-section side top>
                <q-item-label caption>{{ chat.time }}</q-item-label>
              </q-item-section>
            </q-item>
          </q-list>
        </div>

        <!-- NOTIFICATIONS TAB -->
        <div v-if="tab === 'notif'" class="animate-fade q-pa-md">
          <div class="row justify-between items-end q-mb-md">
            <div>
              <div class="text-h4 text-weight-bold" style="letter-spacing: -0.5px">Notifications</div>
              <div class="text-grey-6 text-caption">2 unread</div>
            </div>
            <q-btn flat color="teal-8" label="Mark all read" no-caps class="text-weight-bold bg-teal-1 rounded-borders q-px-sm" dense />
          </div>

          <div class="q-gutter-y-sm">
            <q-card v-for="notif in notifications" :key="notif.id" flat bordered class="custom-card">
              <q-item class="q-pa-md">
                <q-item-section avatar top>
                  <q-avatar :color="notif.avatarColor" :text-color="notif.avatarTextColor" :icon="notif.icon" />
                </q-item-section>
                <q-item-section>
                  <q-item-label class="text-weight-bold">{{ notif.title }}</q-item-label>
                  <q-item-label caption class="q-mt-xs">{{ notif.body }}</q-item-label>
                </q-item-section>
                <q-item-section side top class="items-end">
                  <q-item-label caption class="q-mb-xs">{{ notif.time }}</q-item-label>
                  <div v-if="notif.unread" class="bg-teal-8" style="width: 8px; height: 8px; border-radius: 50%;" />
                </q-item-section>
              </q-item>
            </q-card>
          </div>
        </div>
      </q-page>
    </q-page-container>

    <!-- Bottom Navigation -->
    <q-footer class="bg-white text-dark" style="border-top: 1px solid #eee;">
      <q-tabs v-model="tab" dense class="text-grey-7" active-color="teal-8" indicator-color="teal-8" align="justify">
        <q-tab name="home" icon="cottage" label="Home" />
        <q-tab name="discover" icon="travel_explore" label="Discover" />
        <q-tab name="messages" icon="forum" label="Messages" />
        <q-tab name="notif" icon="notifications" label="Alerts" />
      </q-tabs>
    </q-footer>

  </q-layout>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue';
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

interface DiscoverRoom {
  id: number;
  image: string;
  type: string;
  name: string;
  property: string;
  rent: number;
  address: string;
  floor: string;
  slots: number;
  amenities: { icon: string; color: string; label: string }[];
  landlord: { initials: string; name: string; color: string };
}

interface ChatItem {
  id: number;
  name: string;
  initials: string;
  avatarColor: string;
  lastMessage: string;
  time: string;
  unread: number;
}

interface NotificationItem {
  id: number;
  title: string;
  body: string;
  time: string;
  unread: boolean;
  icon: string;
  avatarColor: string;
  avatarTextColor: string;
}

const router = useRouter();
const authStore = useAuthStore();

const tab = ref('home');
const searchQuery = ref('');
const messageSearchQuery = ref('');
const loading = ref(true);
const error = ref<string | null>(null);

const lease = ref<LeaseRow | null>(null);
const nextPayment = ref<PaymentRow | null>(null);
const userInitials = ref('UN');
const landlordName = ref('Mario Santos');

const stayTitle = ref('No Active Lease');
const staySubtitle = ref('You are not checked in yet.');
const paymentTitle = ref('\u20B10.00');
const paymentSubtitle = ref('No pending balances');

const discoverRooms: DiscoverRoom[] = [
  {
    id: 1, image: 'https://images.unsplash.com/photo-1560185007-cde436f6a4d0?w=600&h=300&fit=crop',
    type: 'Bedspacer', name: 'Bed 1-A', property: 'Pinzon Student Hub', rent: 1800,
    address: 'Blk 5, Pinzon Subdivision, Echague', floor: 'Floor 1', slots: 1,
    amenities: [
      { icon: 'wifi', color: 'teal-5', label: 'WiFi' },
      { icon: 'water_drop', color: 'blue-5', label: 'Water' },
      { icon: 'bolt', color: 'orange-5', label: 'Electric' },
    ],
    landlord: { initials: 'JD', name: 'Juan Dela Cruz', color: 'teal-8' },
  },
  {
    id: 2, image: 'https://images.unsplash.com/photo-1560448204-e02f11c3d0e2?w=600&h=300&fit=crop',
    type: 'Solo', name: 'Room 301', property: "Dong's Dormitory", rent: 3500,
    address: '456 Rizal St., Barangay 3, Echague', floor: 'Floor 3', slots: 1,
    amenities: [
      { icon: 'wifi', color: 'teal-5', label: 'WiFi' },
      { icon: 'water_drop', color: 'blue-5', label: 'Water' },
      { icon: 'bolt', color: 'orange-5', label: 'Electric' },
      { icon: 'ac_unit', color: 'purple-5', label: 'AC' },
    ],
    landlord: { initials: 'MD', name: 'Maria Domingo', color: 'orange-8' },
  },
];

const recentChats: ChatItem[] = [
  { id: 1, name: 'Mario Santos', initials: 'MS', avatarColor: 'teal-8', lastMessage: "Sure, I'll fix the faucet tomorrow morning.", time: '2m ago', unread: 2 },
  { id: 2, name: 'Ana Banawa', initials: 'AB', avatarColor: 'orange-7', lastMessage: 'Are you staying for the sem break?', time: '1h ago', unread: 0 },
  { id: 3, name: 'Property Admin', initials: 'PA', avatarColor: 'blue-8', lastMessage: 'Your payment has been verified. Thank you!', time: '2d ago', unread: 0 },
];

const notifications: NotificationItem[] = [
  { id: 1, title: 'Rent Due Reminder', body: 'Your August rent of \u20B12,500 is overdue. Please settle immediately to avoid penalties.', time: '2 hours ago', unread: true, icon: 'credit_card', avatarColor: 'teal-1', avatarTextColor: 'teal-8' },
  { id: 2, title: 'Repair Update', body: 'Your faucet repair request (MR-002) is now In Progress. Technician scheduled for Aug 14.', time: '5 hours ago', unread: true, icon: 'build', avatarColor: 'orange-1', avatarTextColor: 'orange' },
  { id: 3, title: 'Payment Verified', body: 'Your July 2026 rent payment of \u20B12,500 has been verified by your landlord.', time: '1d ago', unread: false, icon: 'check_circle', avatarColor: 'green-1', avatarTextColor: 'green' },
];

const quickActions = [
  { label: 'Report Issue', icon: 'report_problem', color: 'amber-8', handler: goToStay },
  { label: 'File Complaint', icon: 'gavel', color: 'negative', handler: goToStay },
  { label: 'View History', icon: 'history', color: 'teal-7', handler: goToStay },
  { label: 'Review Stay', icon: 'star', color: 'yellow-8', handler: goToStay },
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

    const { data: userData } = await supabase
      .from('users').select('full_name, initials').eq('id', user.id).maybeSingle();
    if (userData) {
      const u = userData as unknown as { full_name: string | null; initials: string | null };
      userInitials.value = u.initials ?? 'UN';
    }

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

function handleLogout() {
  authStore.clearCachedRole();
  supabase.auth.signOut().finally(() => { void router.push('/login'); });
}

function goToStay() { void router.push('/student/stay'); }
function goToPayments() { void router.push('/student/stay'); }
function goToMessages() { tab.value = 'messages'; }

onMounted(loadDashboard);
</script>

<style scoped>
.animate-fade {
  animation: fadeIn 0.25s ease;
}

@keyframes fadeIn {
  from { opacity: 0; transform: translateY(8px); }
  to { opacity: 1; transform: translateY(0); }
}

.custom-card {
  border-radius: 16px;
  background: white;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.04);
}

.rounded-input :deep(.q-field__control) {
  border-radius: 12px;
}

.opacity-8 {
  opacity: 0.8;
}
</style>
