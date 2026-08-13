<template>
  <q-page class="bg-grey-1 q-pb-lg">
    <!-- Unverified Banner -->
    <q-banner inline-actions rounded class="q-ma-md" style="background:#FFF3E0;">
      <template #avatar>
        <q-icon name="error" color="orange-9" size="28px" />
      </template>
      <span class="text-body2 text-orange-9 text-weight-medium">Enrollment not verified</span>
      <template #action>
        <q-btn unelevated color="orange-9" label="Verify Now" size="sm" dense no-caps class="rounded-borders text-weight-bold" @click="verifyNow" />
      </template>
    </q-banner>

    <!-- Profile Header Card -->
    <q-card flat class="q-mx-md q-mb-md custom-card overflow-hidden">
      <div class="profile-gradient">
        <!-- Avatar -->
        <div class="row justify-center" style="margin-top:28px;">
          <q-avatar size="96px" color="white" class="profile-avatar shadow-4">
            <span class="text-teal-8 text-weight-bold" style="font-size:32px">{{ initials }}</span>
          </q-avatar>
        </div>
        <!-- Badge -->
        <div class="row justify-center q-mt-sm">
          <q-badge color="amber" text-color="dark" label="Pending Verification" class="q-px-md q-py-xs rounded-borders text-weight-medium" />
        </div>
        <!-- Name + Student ID -->
        <div class="text-center q-mt-sm q-pb-md">
          <div class="text-white text-h6 text-weight-bold">{{ fullName }}</div>
          <div class="text-white-7 text-caption">{{ studentId }}</div>
        </div>
      </div>

      <!-- 2x2 Detail Grid -->
      <q-card-section>
        <div class="row q-col-gutter-sm">
          <div class="col-6">
            <q-card flat bordered class="detail-box">
              <q-card-section class="q-py-sm">
                <div class="text-caption text-grey-6">Course</div>
                <div class="text-subtitle2 text-weight-bold q-mt-xs">{{ course }}</div>
              </q-card-section>
            </q-card>
          </div>
          <div class="col-6">
            <q-card flat bordered class="detail-box">
              <q-card-section class="q-py-sm">
                <div class="text-caption text-grey-6">Campus</div>
                <div class="text-subtitle2 text-weight-bold q-mt-xs">{{ campus }}</div>
              </q-card-section>
            </q-card>
          </div>
          <div class="col-6">
            <q-card flat bordered class="detail-box">
              <q-card-section class="q-py-sm">
                <div class="text-caption text-grey-6">Email</div>
                <div class="text-subtitle2 text-weight-bold q-mt-xs" style="word-break:break-all">{{ email }}</div>
              </q-card-section>
            </q-card>
          </div>
          <div class="col-6">
            <q-card flat bordered class="detail-box">
              <q-card-section class="q-py-sm">
                <div class="text-caption text-grey-6">Contact</div>
                <div class="text-subtitle2 text-weight-bold q-mt-xs">{{ contact }}</div>
              </q-card-section>
            </q-card>
          </div>
        </div>
      </q-card-section>
    </q-card>

    <!-- Stats Row -->
    <div class="row q-col-gutter-sm q-px-md q-mb-md">
      <div class="col-4">
        <q-card flat bordered class="custom-card">
          <q-card-section class="text-center q-py-md">
            <q-icon name="payments" color="teal-8" size="24px" />
            <div class="text-h6 text-weight-bold q-mt-xs">2/12</div>
            <div class="text-caption text-grey-6">Months Paid</div>
          </q-card-section>
        </q-card>
      </div>
      <div class="col-4">
        <q-card flat bordered class="custom-card">
          <q-card-section class="text-center q-py-md">
            <q-icon name="bed" color="blue-8" size="24px" />
            <div class="text-h6 text-weight-bold q-mt-xs">3+mo</div>
            <div class="text-caption text-grey-6">Stay</div>
          </q-card-section>
        </q-card>
      </div>
      <div class="col-4">
        <q-card flat bordered class="custom-card">
          <q-card-section class="text-center q-py-md">
            <q-icon name="star" color="amber-7" size="24px" />
            <div class="text-h6 text-weight-bold q-mt-xs">4.8</div>
            <div class="text-caption text-grey-6">Tenant Score</div>
          </q-card-section>
        </q-card>
      </div>
    </div>

    <!-- Current Accommodation -->
    <q-card flat bordered class="q-mx-md q-mb-md custom-card">
      <q-card-section>
        <div class="text-subtitle1 text-weight-bold">{{ accommodation.name }}</div>
        <div class="text-caption text-grey-6 q-mt-xs">
          <q-icon name="place" size="14px" /> {{ accommodation.address }}
        </div>
        <div class="q-mt-sm">
          <q-rating :model-value="accommodation.rating" max="5" size="20px" color="amber-8" readonly />
        </div>
      </q-card-section>
      <q-separator />
      <q-card-section class="row text-center">
        <div class="col-4">
          <div class="text-caption text-grey-6">Monthly Rent</div>
          <div class="text-subtitle2 text-weight-bold">{{ accommodation.monthlyRent }}</div>
        </div>
        <div class="col-4">
          <div class="text-caption text-grey-6">Check-in</div>
          <div class="text-subtitle2 text-weight-bold">{{ accommodation.checkIn }}</div>
        </div>
        <div class="col-4">
          <div class="text-caption text-grey-6">Room Unit</div>
          <div class="text-subtitle2 text-weight-bold">{{ accommodation.roomUnit }}</div>
        </div>
      </q-card-section>
    </q-card>

    <!-- Verification QR -->
    <q-card flat bordered class="q-mx-md q-mb-md custom-card">
      <q-card-section class="text-center">
        <div class="text-subtitle1 text-weight-bold">Verification QR</div>
        <div class="text-caption text-grey-6 q-mt-xs">
          Show this QR to your landlord to verify your enrollment.
        </div>
        <div class="row justify-center q-mt-md">
          <div class="qr-placeholder column items-center justify-center">
            <q-icon name="lock" size="48px" color="grey-5" />
            <div class="text-caption text-grey-6 text-weight-bold q-mt-sm">LOCKED</div>
          </div>
        </div>
        <q-btn
          unelevated color="teal-8" label="Verify Now"
          class="rounded-borders text-weight-bold q-mt-md full-width"
          no-caps @click="verifyNow"
        />
      </q-card-section>
    </q-card>

    <!-- Boarding History -->
    <q-card flat bordered class="q-mx-md q-mb-md custom-card">
      <q-card-section>
        <div class="text-subtitle1 text-weight-bold q-mb-md">Boarding History</div>

        <div class="timeline">
          <div v-for="entry in history" :key="entry.id" class="timeline-item">
            <div class="timeline-marker">
              <div class="timeline-dot" :style="{ background: entry.dotColor }" />
              <div v-if="!entry.last" class="timeline-line" />
            </div>
            <div class="timeline-content q-pb-md">
              <div class="row justify-between items-start">
                <div class="text-weight-bold">{{ entry.name }}</div>
                <q-badge :color="entry.badgeColor" :label="entry.status" class="q-px-sm" />
              </div>
              <div class="text-caption text-grey-6">{{ entry.address }}</div>
              <div class="text-caption text-grey-5 q-mt-xs">{{ entry.dateRange }}</div>
            </div>
          </div>
        </div>
      </q-card-section>
    </q-card>

    <!-- Emergency Contact -->
    <q-card flat bordered class="q-mx-md q-mb-md custom-card">
      <q-card-section class="row items-center">
        <q-avatar size="48px" color="teal-1" text-color="teal-8">
          <q-icon name="person" size="28px" />
        </q-avatar>
        <div class="q-ml-md col">
          <div class="text-subtitle2 text-weight-bold">{{ emergency.name }}</div>
          <div class="text-caption text-grey-6">{{ emergency.relation }} · {{ emergency.phone }}</div>
        </div>
        <q-btn unelevated color="orange-9" icon="call" label="Call" no-caps class="rounded-borders text-weight-bold" @click="callEmergency" />
      </q-card-section>
    </q-card>

    <!-- Actions List -->
    <div class="q-px-md">
      <q-list bordered class="custom-card bg-white rounded-borders">
        <q-item clickable v-ripple>
          <q-item-section avatar><q-icon name="settings" color="grey-7" /></q-item-section>
          <q-item-section>Settings</q-item-section>
        </q-item>
        <q-separator />
        <q-item clickable v-ripple>
          <q-item-section avatar><q-icon name="notifications" color="grey-7" /></q-item-section>
          <q-item-section>Notifications</q-item-section>
        </q-item>
        <q-separator />
        <q-item clickable v-ripple @click="handleLogout">
          <q-item-section avatar><q-icon name="logout" color="negative" /></q-item-section>
          <q-item-section class="text-negative text-weight-medium">Log Out</q-item-section>
        </q-item>
      </q-list>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { ref } from 'vue';
import { useRouter } from 'vue-router';
import { useQuasar } from 'quasar';
import { supabase } from '@/shared/utils/supabase';
import { useAuthStore } from '@/stores/auth';

const router = useRouter();
const $q = useQuasar();
const authStore = useAuthStore();

// Profile data (static for now, wired to Supabase later)
const initials = ref('JD');
const fullName = ref('Juan Dela Cruz');
const studentId = ref('2024-00456');
const course = ref('BS in Information Technology');
const campus = ref('ISU Echague');
const email = ref('juan@accommo.test');
const contact = ref('+639123456789');

const accommodation = {
  name: 'Santos Boarding House',
  address: '123 Rizal St., Barangay 4, Echague',
  rating: 4.5,
  monthlyRent: '₱2,500',
  checkIn: 'Aug 2026',
  roomUnit: 'Room 2B',
};

const history = [
  { id: 1, name: 'Pinzon Student Hub', address: 'Blk 5, Pinzon Subdivision, Echague', dateRange: 'Aug 2024 – May 2025', status: 'Moved Out', badgeColor: 'grey', dotColor: '#bdbdbd', last: false },
  { id: 2, name: 'Dong\'s Dormitory', address: '456 Rizal St., Barangay 3, Echague', dateRange: 'Jun 2025 – Jul 2025', status: 'Evicted', badgeColor: 'negative', dotColor: '#e53935', last: false },
  { id: 3, name: 'Santos Boarding House', address: '123 Rizal St., Barangay 4, Echague', dateRange: 'Aug 2026 – Present', status: 'Current', badgeColor: 'teal', dotColor: '#00897b', last: true },
];

const emergency = {
  name: 'Maria Dela Cruz',
  relation: 'Mother',
  phone: '+639987654321',
};

function verifyNow() {
  $q.notify({
    message: 'Enrollment verification is not available yet.',
    color: 'amber-9',
    position: 'top',
    classes: 'custom-notify',
  });
}

function callEmergency() {
  $q.notify({
    message: 'Calling ' + emergency.name + '...',
    color: 'orange-9',
    position: 'top',
    classes: 'custom-notify',
    icon: 'call',
  });
}

async function handleLogout() {
  authStore.clearCachedRole();
  await supabase.auth.signOut();
  void router.push('/login');
}
</script>

<style scoped>
.profile-gradient {
  background: linear-gradient(135deg, #00897b 0%, #5e35b1 100%);
  border-radius: 0 0 24px 24px;
}

.profile-avatar {
  border: 4px solid rgba(255, 255, 255, 0.5);
}

.detail-box {
  border-radius: 12px;
  background: white;
}

.custom-card {
  border-radius: 16px;
  background: white;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.04);
}

.qr-placeholder {
  width: 160px;
  height: 160px;
  border: 3px dashed #bdbdbd;
  border-radius: 16px;
  background: #fafafa;
}

/* Timeline */
.timeline-item {
  display: flex;
}

.timeline-marker {
  display: flex;
  flex-direction: column;
  align-items: center;
  margin-right: 16px;
}

.timeline-dot {
  width: 16px;
  height: 16px;
  border-radius: 50%;
  border: 3px solid white;
  box-shadow: 0 0 0 2px rgba(0, 0, 0, 0.08);
  flex-shrink: 0;
}

.timeline-line {
  width: 2px;
  flex: 1;
  background: #e0e0e0;
  margin: 4px 0;
}

.timeline-content {
  flex: 1;
  min-width: 0;
}

.text-white-7 {
  color: rgba(255, 255, 255, 0.7);
}
</style>
