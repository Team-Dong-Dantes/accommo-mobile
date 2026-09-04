<template>
<q-page class="profile-page">
  <main class="profile-content">
    <div v-if="loading" class="profile-state" role="status" aria-live="polite">
      <q-spinner color="primary" size="32px" />
      <span>Loading profile…</span>
    </div>
    <div v-else-if="error" class="profile-state profile-state--error" role="alert">
      <IconifyIcon icon="lucide:circle-alert" width="24" />
      <strong>We couldn’t load your profile.</strong>
      <span>{{ error }}</span>
      <q-btn outline no-caps color="primary" label="Try again" class="profile-state-action" @click="loadProfile" />
    </div>

    <template v-else>
      <!-- Identity -->
      <section class="surface-card identity-card" aria-label="Your details">
        <button type="button" class="identity-card-edit" aria-label="Edit profile" @click="openEditProfile">
          <IconifyIcon icon="lucide:pencil" width="16" />
        </button>
        <div class="identity-main">
          <q-avatar size="72px" class="identity-avatar text-white" @click="openEditProfile">
            <img v-if="profileImageUrl" :src="profileImageUrl" :alt="`${fullName} profile photo`" />
            <span v-else>{{ initials }}</span>
          </q-avatar>
          <div class="identity-copy">
            <h1 class="identity-name">{{ fullName }}</h1>
            <p class="identity-sub">{{ studentId }} · {{ course }}</p>
          </div>
        </div>
      </section>

      <!-- Student QR (same card as the manager QR scanner tile) -->
      <section class="surface-card qr-tool" aria-label="Your student QR code">
        <span class="qr-tool-icon" aria-hidden="true">
          <IconifyIcon icon="lucide:qr-code" width="22" />
        </span>
        <div class="qr-tool-copy">
          <h2>My student QR</h2>
          <p>{{ osasVerified ? 'Show this at check-in to confirm your verified seat.' : 'Locked until OSAS verifies your enrollment.' }}
            <q-btn v-if="!osasVerified" flat dense no-caps color="primary" class="qr-tool-link" @click="goOSAS">Verify now</q-btn>
          </p>
        </div>
        <span class="qr-tool-mock" aria-hidden="true">
          <img v-if="osasVerified && qrDataUrl" :src="qrDataUrl" alt="Your student QR code" class="qr-mock-img" />
          <IconifyIcon v-else icon="lucide:lock-keyhole" width="22" class="qr-mock-lock" />
        </span>
        <q-btn v-if="osasVerified" flat round dense class="qr-tool-expand" aria-label="Expand QR" @click="openQrSheet">
          <IconifyIcon icon="lucide:maximize-2" width="16" />
        </q-btn>
      </section>

      <!-- Your tenant rating -->
      <section v-if="tenantRating && tenantRating.show" class="rating-kpi surface-card" aria-label="Your tenant rating">
        <div class="rk-label">{{ tenantRating.label }}</div>
        <div class="rk-main">
          <strong class="rk-value">{{ tenantRating.value }}</strong>
          <span class="rk-stars" aria-hidden="true">
            <IconifyIcon v-for="n in 5" :key="n" icon="lucide:star" width="15" :class="{ 'rk-on': tenantRating.stars >= n }" />
          </span>
        </div>
        <div class="rk-sub">{{ tenantRating.countLabel }}</div>
      </section>

      <!-- Stay -->
      <nav class="list-group" aria-label="Your stay">
        <p class="list-eyebrow">Your stay</p>
        <div class="surface-card list-card">
          <button type="button" class="list-row" @click="leasePresent && openAccommodation()">
            <span class="list-icon list-icon--primary"><IconifyIcon icon="lucide:building-2" width="19" /></span>
            <span class="list-copy"><strong>Current accommodation</strong><small>{{ accommodationRowSub }}</small></span>
            <span class="list-chevron"><IconifyIcon icon="lucide:chevron-right" width="18" /></span>
          </button>
          <span class="list-divider" role="separator" />
          <button type="button" class="list-row" @click="openHistory">
            <span class="list-icon list-icon--primary"><IconifyIcon icon="lucide:clock-3" width="19" /></span>
            <span class="list-copy"><strong>Boarding history</strong><small>{{ history.length ? `${history.length} past stay${history.length === 1 ? '' : 's'}` : 'No stays yet' }}</small></span>
            <span class="list-chevron"><IconifyIcon icon="lucide:chevron-right" width="18" /></span>
          </button>
        </div>
      </nav>
      <!-- Contact -->
      <nav class="list-group" aria-label="Contact">
        <p class="list-eyebrow">Contact</p>
        <div class="surface-card list-card">
          <button type="button" class="list-row" @click="openEmergency">
            <span class="list-icon list-icon--warning"><IconifyIcon icon="lucide:phone" width="19" /></span>
            <span class="list-copy"><strong>Emergency contact</strong><small>{{ emergencyRowSub }}</small></span>
            <span class="list-chevron"><IconifyIcon icon="lucide:chevron-right" width="18" /></span>
          </button>
        </div>
      </nav>

      <!-- Settings -->
      <nav class="list-group" aria-label="Settings" data-bottom>
        <p class="list-eyebrow">Settings</p>
        <div class="surface-card list-card">
          <button type="button" class="list-row" @click="openEditProfile">
            <span class="list-icon list-icon--neutral"><IconifyIcon icon="lucide:settings" width="19" /></span>
            <span class="list-copy"><strong>Settings</strong><small>Edit profile, photo and contact details</small></span>
            <span class="list-chevron"><IconifyIcon icon="lucide:chevron-right" width="18" /></span>
          </button>
          <span class="list-divider" role="separator" />
          <button type="button" class="list-row list-row--danger" @click="handleLogout">
            <span class="list-icon list-icon--danger"><IconifyIcon icon="lucide:log-out" width="19" /></span>
            <span class="list-copy"><strong>Log out</strong><small>Sign out of this device</small></span>
          </button>
        </div>
      </nav>
    </template>
  </main>

  <!-- Sheet: Current accommodation -->
  <q-dialog v-model="accommodationSheet" position="bottom">
    <q-card class="sheet-card full-width pb-safe">
      <div class="sheet-header">
        <span class="sheet-grip" aria-hidden="true" />
        <h2 class="sheet-title">Current accommodation</h2>
      </div>
      <template v-if="leasePresent">
        <div class="sheet-body">
          <div class="sheet-block">
            <div class="sheet-block-top">
              <h3>{{ accommodation.name }}</h3>
              <q-rating :model-value="accommodation.rating" max="5" size="15px" color="amber-6" readonly />
            </div>
            <p class="sheet-address"><IconifyIcon icon="lucide:map-pin" width="14" /> {{ accommodation.address }}</p>
          </div>
          <div class="stay-facts">
            <div><span>Monthly</span><strong>{{ accommodation.monthlyRent }}</strong></div>
            <div><span>Checked in</span><strong>{{ accommodation.checkIn }}</strong></div>
            <div><span>Room</span><strong>{{ accommodation.roomUnit }}</strong></div>
          </div>
          <q-btn unelevated no-caps color="primary" label="Done" class="sheet-cta" v-close-popup />
        </div>
      </template>
      <template v-else>
        <div class="sheet-body sheet-body--center">
          <span class="empty-icon"><IconifyIcon icon="lucide:building-2" width="28" /></span>
          <p class="sheet-loading-title">No active stay yet</p>
          <p class="sheet-loading-sub">Once you sign a lease, your accommodation and room details will appear here.</p>
        </div>
      </template>
    </q-card>
  </q-dialog>

  <!-- Sheet: Boarding history -->
  <q-dialog v-model="historySheet" position="bottom">
    <q-card class="sheet-card full-width pb-safe housesheet">
      <div class="sheet-header sheet-header--fixed">
        <span class="sheet-grip sheet-grip--inline" aria-hidden="true" />
        <h2 class="sheet-title">Boarding history</h2>
      </div>
      <div class="sheet-body sheet-body--scroll">
        <p v-if="!history.length" class="empty-note">No boarding history yet.</p>
        <div v-else class="timeline">
          <div v-for="entry in history" :key="entry.id" class="timeline-item">
            <span class="timeline-dot" :style="{ background: entry.dotColor }" aria-hidden="true"><span v-if="!entry.last" class="timeline-line" /></span>
            <div class="timeline-content">
              <div class="timeline-head">
                <div class="timeline-copy">
                  <strong>{{ entry.name }}</strong>
                  <small>{{ entry.address }}</small>
                  <small><IconifyIcon icon="lucide:calendar" width="12" /> {{ entry.dateRange }}</small>
                </div>
                <q-chip dense square :color="entry.badgeColor" :text-color="entry.textColor || 'white'" class="timeline-chip">{{ entry.status }}</q-chip>
              </div>
            </div>
          </div>
        </div>
      </div>
    </q-card>
  </q-dialog>

  <!-- Sheet: Edit profile -->
  <q-dialog v-model="editDialog" position="bottom">
    <q-card class="sheet-card full-width pb-safe">
      <div class="sheet-header">
        <span class="sheet-grip" aria-hidden="true" />
        <h2 class="sheet-title">Edit profile</h2>
      </div>
      <div class="sheet-body">
        <button type="button" class="edit-avatar" aria-label="Change profile photo" @click="avatarInputRef.pickFiles()">
          <span class="edit-avatar__preview">
            <template v-if="avatarPreview || profileImageUrl">
              <img :src="(avatarPreview || profileImageUrl) || ''" alt="Profile photo preview" />
              <span class="edit-avatar__cam"><IconifyIcon icon="lucide:camera" width="14" /></span>
            </template>
            <IconifyIcon v-else icon="lucide:image-plus" width="26" class="edit-avatar__ph" />
          </span>
          <span class="edit-avatar__copy">
            <strong>Profile photo</strong>
            <small>{{ avatarFile || profileImageUrl ? 'Tap to change' : 'Tap to add a photo' }}</small>
          </span>
        </button>
        <q-file ref="avatarInputRef" v-model="avatarFile" style="display:none" accept="image/jpeg,image/png,image/webp" @update:model-value="onAvatarChosen" />
        <button type="button" class="edit-sync-google" :disabled="savingProfile" @click="useGooglePhoto">
          <IconifyIcon icon="lucide:user-round" width="15" />
          <span>Use my Google photo</span>
        </button>

        <label class="field-label">Full name</label>
        <q-input v-model="editFullName" outlined dense class="field-input" placeholder="Your full name" />
        <label class="field-label">Phone number</label>
        <q-input v-model="editPhone" outlined dense class="field-input" placeholder="+63..." />
        <label class="field-label">Sex</label>
        <q-select v-model="editSex" outlined dense class="field-input" bg-color="white"
          :options="[{ label: 'Male', value: 'M' }, { label: 'Female', value: 'F' }]" emit-value map-options clearable />
        <q-btn unelevated no-caps color="primary" label="Save changes" class="sheet-cta" :loading="savingProfile" @click="saveProfile" />
      </div>
    </q-card>
  </q-dialog>

  <!-- Sheet: Emergency contact -->
  <q-dialog v-model="emergencyDialog" position="bottom">
    <q-card class="sheet-card full-width pb-safe">
      <div class="sheet-header">
        <span class="sheet-grip" aria-hidden="true" />
        <h2 class="sheet-title">Emergency contact</h2>
      </div>
      <div class="sheet-body">
        <label class="field-label">Full name</label>
        <q-input v-model="emergencyName" outlined dense class="field-input" placeholder="Contact name" />
        <label class="field-label">Relationship</label>
        <q-input v-model="emergencyRelation" outlined dense class="field-input" placeholder="e.g. Mother, Guardian" />
        <label class="field-label">Phone</label>
        <q-input v-model="emergencyPhone" outlined dense class="field-input" placeholder="+63..." />
        <q-btn unelevated no-caps color="primary" label="Save contact" class="sheet-cta" :loading="savingEmergency" @click="saveEmergency" />
        <q-btn v-if="hasEmergency" outline no-caps color="negative" label="Call this contact" class="sheet-cta sheet-cta--ghost" @click="callEmergency" />
      </div>
    </q-card>
  </q-dialog>

  <!-- Sheet: My student QR -->
  <q-dialog v-model="qrSheet" position="bottom">
    <q-card class="sheet-card full-width pb-safe">
      <div class="sheet-header">
        <span class="sheet-grip" aria-hidden="true" />
        <h2 class="sheet-title">My student QR</h2>
      </div>
      <template v-if="osasVerified && qrDataUrl">
        <div class="sheet-body sheet-slim">
          <div class="qr-sheet-canvas">
            <img :src="qrDataUrl" alt="Your student QR code" width="176" height="176" class="qr-code" />
          </div>
          <p class="qr-caption">Show this code at check-in so your manager can confirm you’re an active, verified student.</p>
        </div>
      </template>
      <template v-else>
        <div class="sheet-body sheet-body--center">
          <span class="empty-icon"><IconifyIcon icon="lucide:lock-keyhole" width="26" /></span>
          <p class="sheet-loading-title">QR code locked</p>
          <p class="sheet-loading-sub">Get verified by OSAS to unlock your student QR code.</p>
          <q-btn unelevated no-caps color="primary" class="sheet-cta" @click="goOSAS">Verify with OSAS</q-btn>
        </div>
      </template>
    </q-card>
  </q-dialog>
</q-page>
</template>
<script setup lang="ts">
import { ref, computed, onMounted } from 'vue';
import { useRouter } from 'vue-router';
import { useQuasar } from 'quasar';
import { supabase } from '@/shared/utils/supabase';
import { useAuthStore } from '@/stores/auth';
import { uploadDocument, uploadToCloudinary } from '@/shared/utils/upload';
import { restoreGooglePhoto } from '@/shared/utils/avatar';
import QRCode from 'qrcode';

interface UserRow {
  full_name: string | null;
  initials: string | null;
  email: string | null;
  phone: string | null;
  status: string | null;
  avatar_color: string | null;
  sex: string | null;
}

interface StudentProfileRow {
  student_id: string | null;
  program: string | null;
  college: string | null;
  year_level: number | null;
  emergency_contact_json: unknown;
  osas_verified_at: string | null;
  school_id_url: string | null;
  assessment_of_fees_url: string | null;
}

interface LeaseRow {
  id: string;
  status: string;
  start_date: string | null;
  end_date: string | null;
  monthly_rent: number | null;
  room: {
    room_number: string | null;
    accommodation: { name: string | null; address: string | null; rating_avg: number | null } | null;
  } | null;
}

const router = useRouter();
const $q = useQuasar();
const authStore = useAuthStore();

const loading = ref(true);
const error = ref<string | null>(null);

// Profile data (from Supabase, empty until loaded)
const initials = ref('U');
const fullName = ref('Student');
const studentId = ref('—');
const course = ref('—');
const campus = ref('ISU Echague');
const email = ref('—');
const contact = ref('—');
const verified = ref(false);
const osasVerified = ref(false);
const pendingReview = ref(false);
const sex = ref<string | null>(null);
const qrDataUrl = ref('');
const qrSheet = ref(false);
const profileImageUrl = ref<string | null>(null);
const avatarInputRef = ref<any>(null);
const avatarFile = ref<File | null>(null);
const avatarPreview = ref<string | null>(null);
const stayLabel = ref('—');
const yearLevel = ref('3rd Year'); // Default fallback

// OSAS Verification Dialog State
const verificationDialog = ref(false);
const submitting = ref(false);
const verifiedSuccess = ref(false);

const assessmentRef = ref<any>(null);
const schoolIdRef = ref<any>(null);
const assessmentFile = ref<File | null>(null);
const schoolIdFile = ref<File | null>(null);

// Edit Profile Dialog State
const editDialog = ref(false);
const savingProfile = ref(false);
const editFullName = ref('');
const editPhone = ref('');
const editSex = ref('');

// Emergency Contact Dialog State
const emergencyDialog = ref(false);
const savingEmergency = ref(false);
const emergencyName = ref('');
const emergencyRelation = ref('');
const emergencyPhone = ref('');

const isVerificationReady = computed(() => !!assessmentFile.value && !!schoolIdFile.value);
// ---------- Redesign: sheet + list presentation helpers ----------
const accommodationSheet = ref(false);
const historySheet = ref(false);
const qrFullscreenDialog = ref(false);

function openQrFullscreen() {
  qrFullscreenDialog.value = true;
}

const leasePresent = computed(() => accommodation.value.name !== 'No active stay');
const verificationStatusLabel = computed(() => (osasVerified.value
  ? 'OSAS verified'
  : pendingReview.value ? 'In review' : 'Not verified'));
const verificationToneClass = computed(() => (osasVerified.value
  ? 'status-pill--verified'
  : pendingReview.value ? 'status-pill--review' : 'status-pill--unverified'));
const verificationRowSub = computed(() => (osasVerified.value
  ? 'Verified and ready to scan'
  : pendingReview.value ? 'Documents under review' : 'Verify to unlock your QR code'));
const accommodationRowSub = computed(() => (leasePresent.value
  ? `${accommodation.value.name} · ${accommodation.value.roomUnit}`
  : 'No active stay'));
const hasEmergencyContact = computed(() => Boolean(emergency.value.name) && emergency.value.name !== 'Emergency Contact');
const hasEmergency = computed(() => Boolean(emergency.value.phone) && emergency.value.phone !== '—');
const emergencyRowSub = computed(() => {
  if (!hasEmergencyContact.value) return 'Add an emergency contact';
  const parts = [emergency.value.name,
    emergency.value.relation && emergency.value.relation !== '—' ? emergency.value.relation : null];
  return parts.filter(Boolean).join(' · ');
});

function openVerification() { verificationDialog.value = true; }
function openAccommodation() { accommodationSheet.value = true; }
function openHistory() { historySheet.value = true; }

// Accommodation (from active lease)
const accommodation = ref({
  name: 'No active lease',
  address: '—',
  rating: 0,
  monthlyRent: '₱0.00',
  checkIn: '—',
  roomUnit: '—',
});

const stats = ref({ monthsPaid: '0/12', stay: '—', tenantScore: '—' });
const tenantRating = ref<{ show: boolean; value: string; stars: number; label: string; countLabel: string }>({
  show: false, value: '—', stars: 0, label: 'Tenant rating', countLabel: '',
});

// Emergency contact remains static-safe: parse from JSON if present
const emergency = ref({ name: 'Emergency Contact', relation: '—', phone: '—' });

const history = ref<{ id: number; name: string; address: string; dateRange: string; status: string; badgeColor: string; textColor?: string; dotColor: string; last: boolean }[]>([]);

function formatPeso(amount: number): string {
  return '\u20B1' + amount.toLocaleString('en-PH', { minimumFractionDigits: 0, maximumFractionDigits: 0 });
}

function ordinal(n: number): string {
  const mod100 = n % 100;
  if (mod100 >= 11 && mod100 <= 13) return 'th';
  switch (n % 10) {
    case 1: return 'st';
    case 2: return 'nd';
    case 3: return 'rd';
    default: return 'th';
  }
}

function yearLevelLabel(y: number): string {
  return `${y}${ordinal(y)} Year`;
}

async function loadProfile() {
  loading.value = true;
  error.value = null;
  try {
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) { void router.push('/login'); return; }
    const metadata = user.user_metadata as Record<string, unknown> | undefined;
    const picture = typeof metadata?.avatar_url === 'string'
      ? metadata.avatar_url
      : (typeof metadata?.picture === 'string' ? metadata.picture : '');
    profileImageUrl.value = picture || null;

    // Fetch user + student profile + active lease in parallel
    const [userResult, profileResult, leaseResult] = await Promise.all([
      supabase.from('users').select('full_name, initials, email, phone, status, avatar_color, sex').eq('id', user.id).maybeSingle(),
      supabase.from('student_profiles').select('student_id, program, college, year_level, emergency_contact_json, osas_verified_at, school_id_url, assessment_of_fees_url').eq('user_id', user.id).maybeSingle(),
      (supabase as any).from('leases')
        .select('id, status, start_date, end_date, monthly_rent, room:rooms(room_number, accommodation:accommodations(name, address, rating_avg))')
        .eq('student_id', user.id).eq('status', 'active').maybeSingle(),
    ]);

    if (userResult.data) {
      const u = userResult.data as unknown as UserRow;
      fullName.value = u.full_name ?? 'Student';
      initials.value = u.initials ?? 'U';
      email.value = u.email ?? '—';
      contact.value = u.phone ?? '—';
      verified.value = u.status === 'verified';
      sex.value = u.sex ?? null;
    }

    let totalMonths = 12;
    if (profileResult.data) {
      const p = profileResult.data as unknown as StudentProfileRow;
      studentId.value = p.student_id ?? '—';
      course.value = p.program ?? '—';
      campus.value = p.college ? p.college.replace(/^.*\((.*)\)$/, '$1') : 'ISU Echague';
      osasVerified.value = !!p.osas_verified_at;
      // "Under review" = documents submitted but OSAS has not approved yet.
      pendingReview.value = !p.osas_verified_at && (!!p.school_id_url || !!p.assessment_of_fees_url);

      if (p.year_level) {
        yearLevel.value = yearLevelLabel(p.year_level);
      }

      if (p.emergency_contact_json) {
        try {
          const ec = p.emergency_contact_json as { name?: string; relation?: string; phone?: string };
          emergency.value = {
            name: ec.name ?? 'Emergency Contact',
            relation: ec.relation ?? '—',
            phone: ec.phone ?? '—',
          };
        } catch { /* ignore malformed JSON */ }
      }
    }

    // Accommodation from active lease
    if (leaseResult.data) {
      const l = leaseResult.data as unknown as LeaseRow;
      accommodation.value = {
        name: l.room?.accommodation?.name ?? 'Active lease',
        address: l.room?.accommodation?.address ?? '—',
        rating: l.room?.accommodation?.rating_avg ?? 0,
        monthlyRent: formatPeso(l.monthly_rent ?? 0),
        checkIn: l.start_date ? new Date(l.start_date).toLocaleDateString('en-PH', { month: 'short', year: 'numeric' }) : '—',
        roomUnit: l.room?.room_number ? `Unit ${l.room.room_number}` : '—',
      };
      if (l.start_date && l.end_date) {
        const s = new Date(l.start_date);
        const e = new Date(l.end_date);
        totalMonths = Math.max(1, (e.getFullYear() - s.getFullYear()) * 12 + (e.getMonth() - s.getMonth()) + 1);
      }
      stayLabel.value = l.start_date
        ? new Date(l.start_date).toLocaleDateString('en-PH', { month: 'short', year: 'numeric' })
        : '—';
    }

    // Derive profile stats from real data
    let paidCount = 0;
    let tenantScore = '—';
    if (leaseResult.data) {
      const leaseId = (leaseResult.data as unknown as LeaseRow).id;

      const { data: payments } = await supabase
        .from('payments')
        .select('id')
        .eq('lease_id', leaseId)
        .eq('status', 'paid');
      paidCount = payments?.length ?? 0;

      const { data: trev } = await supabase
        .from('tenant_reviews')
        .select('rating')
        .eq('lease_id', leaseId);
      const ratings = (trev ?? []).map((r) => (r as { rating: number }).rating);
      if (ratings.length > 0) {
        tenantScore = (ratings.reduce((a, b) => a + b, 0) / ratings.length).toFixed(1);
      }
    }

    stats.value = {
      monthsPaid: `${paidCount}/${totalMonths}`,
      stay: stayLabel.value,
      tenantScore,
    };

    // Tenant rating KPI: average of ALL ratings this student received across stays.
    try {
      const { data: leaseRowsAll } = await (supabase as any).from('leases').select('id').eq('student_id', user.id)
      const ids = ((leaseRowsAll ?? []) as Array<{ id: string }>).map((l) => l.id)
      let myRatings: number[] = []
      if (ids.length) {
        const { data: trAll } = await (supabase as any).from('tenant_reviews').select('rating').in('lease_id', ids)
        myRatings = ((trAll ?? []) as Array<{ rating: number }>).map((r) => r.rating)
      }
      if (myRatings.length) {
        const avg = myRatings.reduce((s2, r) => s2 + r, 0) / myRatings.length
        tenantRating.value = { show: true, value: avg.toFixed(1), stars: Math.round(avg), label: 'Tenant rating', countLabel: `${myRatings.length} rating${myRatings.length === 1 ? '' : 's'} from accommodation managers` }
      } else {
        tenantRating.value = { show: true, value: '—', stars: 0, label: 'Tenant rating', countLabel: 'No ratings yet' }
      }
    } catch {
      /* rating KPI is non-critical */
    }

    // Boarding history (real)
    const { data: bh } = await (supabase as any)
      .from('boarding_history')
      .select('id, accommodation_name, period_start, period_end, room_type, end_reason')
      .eq('student_id', user.id)
      .order('period_start', { ascending: false });

    const rows = (bh ?? []) as unknown as Array<{
      id: string; accommodation_name: string | null; period_start: string; period_end: string; room_type: string | null; end_reason: string | null;
    }>;

    history.value = rows.map((h, i) => {
      const start = new Date(h.period_start).toLocaleDateString('en-PH', { month: 'short', year: 'numeric' });
      const end = new Date(h.period_end).toLocaleDateString('en-PH', { month: 'short', year: 'numeric' });
      const active = !h.end_reason;
      return {
        id: i + 1,
        name: h.accommodation_name ?? 'Boarding House',
        address: h.room_type ? `${h.room_type} room` : '—',
        dateRange: `${start} – ${end}`,
        status: active ? 'Current' : h.end_reason === 'evicted' ? 'Evicted' : 'Moved Out',
        badgeColor: active ? 'teal-1' : h.end_reason === 'evicted' ? 'red-1' : 'grey-3',
        textColor: active ? 'teal-7' : h.end_reason === 'evicted' ? 'red-5' : 'grey-7',
        dotColor: active ? '#00897B' : h.end_reason === 'evicted' ? '#EF5350' : '#BDBDBD',
        last: false,
      };
    });
    const lastRow = history.value.at(-1);
    if (lastRow) lastRow.last = true;

    // The QR code is only generated once the student is OSAS-verified.
    qrDataUrl.value = '';
    if (osasVerified.value && studentId.value && studentId.value !== '—') {
      await generateQr();
    }
  } catch (e) {
    error.value = e instanceof Error ? e.message : 'Failed to load profile';
  } finally {
    loading.value = false;
  }
}

function openQrSheet() {
  qrSheet.value = true;
}
function goOSAS() {
  qrSheet.value = false;
  void router.push('/student/support');
}
function verifyNow() {
  verificationDialog.value = true;
}

function openEditProfile() {
  editFullName.value = fullName.value === 'Student' ? '' : fullName.value;
  editPhone.value = contact.value === '—' ? '' : contact.value;
  editSex.value = sex.value ?? '';
  avatarFile.value = null;
  avatarPreview.value = null;
  editDialog.value = true;
}

function onAvatarChosen() {
  const file = avatarFile.value;
  if (!file) { avatarPreview.value = null; return; }
  if (avatarPreview.value) URL.revokeObjectURL(avatarPreview.value);
  avatarPreview.value = URL.createObjectURL(file);
}

async function useGooglePhoto() {
  const url = await restoreGooglePhoto();
  if (!url) {
    $q.notify({ message: 'No Google photo to use.', color: 'warning', position: 'top', classes: 'custom-notify' });
    return;
  }
  if (avatarPreview.value) URL.revokeObjectURL(avatarPreview.value);
  avatarPreview.value = null;
  avatarFile.value = null;
  profileImageUrl.value = url;
  try {
    const evt = new CustomEvent('accommo:avatar-change', { detail: { url } });
    window.dispatchEvent(evt);
  } catch { /* noop */ }
  $q.notify({ message: 'Profile photo synced with Google.', color: 'teal-8', position: 'top', classes: 'custom-notify' });
}

async function saveProfile() {
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) { void router.push('/login'); return; }

  const name = editFullName.value.trim();
  if (!name) {
    $q.notify({ message: 'Full name is required.', color: 'warning', position: 'top', classes: 'custom-notify' });
    return;
  }

  savingProfile.value = true;
  try {
    const { error } = await supabase
      .from('users')
      .update({ full_name: name, phone: editPhone.value.trim() || '+639000000000', sex: editSex.value || null })
      .eq('id', user.id);
    if (error) throw error;

    if (avatarFile.value) {
      const [uploaded] = await uploadToCloudinary([avatarFile.value]);
      const newAvatarUrl = uploaded?.url ?? null;
      if (newAvatarUrl) {
        try {
          const { error: metaError } = await supabase.auth.updateUser({ data: { avatar_url: newAvatarUrl } });
          if (metaError) throw metaError;
          profileImageUrl.value = newAvatarUrl;
          const evt = new CustomEvent('accommo:avatar-change', { detail: { url: newAvatarUrl } });
          window.dispatchEvent(evt);
        } catch { /* metadata update failed; keep old avatar */ }
      }
    }
    if (avatarPreview.value) URL.revokeObjectURL(avatarPreview.value);
    avatarFile.value = null;
    avatarPreview.value = null;

    editDialog.value = false;
    $q.notify({ message: 'Profile updated.', color: 'teal-8', position: 'top', classes: 'custom-notify', icon: 'check_circle' });
    await loadProfile();
  } catch (e) {
    $q.notify({ message: e instanceof Error ? e.message : 'Failed to update profile', color: 'negative', position: 'top', classes: 'custom-notify' });
  } finally {
    savingProfile.value = false;
  }
}

function openEmergency() {
  emergencyName.value = emergency.value.name === 'Emergency Contact' ? '' : emergency.value.name;
  emergencyRelation.value = emergency.value.relation === '—' ? '' : emergency.value.relation;
  emergencyPhone.value = emergency.value.phone === '—' ? '' : emergency.value.phone;
  emergencyDialog.value = true;
}

async function saveEmergency() {
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) { void router.push('/login'); return; }

  if (!emergencyName.value.trim()) {
    $q.notify({ message: 'Emergency contact name is required.', color: 'warning', position: 'top', classes: 'custom-notify' });
    return;
  }

  savingEmergency.value = true;
  try {
    const { error } = await supabase
      .from('student_profiles')
      .update({
        emergency_contact_json: {
          name: emergencyName.value.trim(),
          relation: emergencyRelation.value.trim() || null,
          phone: emergencyPhone.value.trim() || null,
        },
      })
      .eq('user_id', user.id);
    if (error) throw error;
    emergencyDialog.value = false;
    $q.notify({ message: 'Emergency contact saved.', color: 'teal-8', position: 'top', classes: 'custom-notify', icon: 'check_circle' });
    await loadProfile();
  } catch (e) {
    $q.notify({ message: e instanceof Error ? e.message : 'Failed to save emergency contact', color: 'negative', position: 'top', classes: 'custom-notify' });
  } finally {
    savingEmergency.value = false;
  }
}

function goNotifications() {
  void router.push('/student/notifications');
}

async function generateQr() {
  const id = studentId.value;
  if (!id || id === '—') {
    qrDataUrl.value = '';
    return;
  }
  try {
    qrDataUrl.value = await QRCode.toDataURL(id, {
      width: 160,
      margin: 1,
      color: { dark: '#111827', light: '#ffffff' },
    });
  } catch {
    qrDataUrl.value = '';
  }
}

async function submitVerification() {
  if (!assessmentFile.value || !schoolIdFile.value) {
    $q.notify({
      message: 'Please attach both your Assessment of Fees and School ID.',
      color: 'warning',
      position: 'top',
      classes: 'custom-notify',
      icon: 'error',
    });
    return;
  }

  const { data: { user } } = await supabase.auth.getUser();
  if (!user) { void router.push('/login'); return; }

  submitting.value = true;
  try {
    // Upload both documents to the 'documents' storage bucket in parallel.
    const [assessmentUrl, schoolIdUrl] = await Promise.all([
      uploadDocument(assessmentFile.value, user.id, 'assessment'),
      uploadDocument(schoolIdFile.value, user.id, 'school_id'),
    ]);

    // Persist the document URLs on the student profile for OSAS review.
    const { error: profileError } = await supabase
      .from('student_profiles')
      .update({
        assessment_of_fees_url: assessmentUrl,
        school_id_url: schoolIdUrl,
      })
      .eq('user_id', user.id);

    if (profileError) throw profileError;

    const { error: docError } = await supabase.from('verification_documents').insert([
      { user_id: user.id, doc_type: 'assessment_of_fees', file_url: assessmentUrl, filename: assessmentFile.value.name, status: 'pending' },
      { user_id: user.id, doc_type: 'school_id', file_url: schoolIdUrl, filename: schoolIdFile.value.name, status: 'pending' },
    ]);
    if (docError) throw docError;

    // Re-open the queue through the RPC (SECURITY DEFINER) rather than PATCHing
    // users.status directly: a DB trigger (lock_user_privileges) forbids a
    // student from changing their own status, which made every re-submission
    // after a rejection fail with P0001 (400). resubmit_verification() only ever
    // moves the caller back to 'pending' — never to verified.
    const { error: userError } = await (supabase as any).rpc('resubmit_verification')
    if (userError) throw userError;

    pendingReview.value = true;
    verifiedSuccess.value = true;

    // Give the user a moment to read the success message before closing.
    setTimeout(() => {
      verificationDialog.value = false;
      assessmentFile.value = null;
      schoolIdFile.value = null;
      verifiedSuccess.value = false;
      void loadProfile();
    }, 2500);
  } catch (e) {
    $q.notify({
      message: e instanceof Error ? e.message : 'Failed to submit documents',
      color: 'negative',
      position: 'top',
      classes: 'custom-notify',
      icon: 'error',
    });
  } finally {
    submitting.value = false;
  }
}

function callEmergency() {
  const phone = emergency.value.phone;
  if (!phone || phone === '—') {
    $q.notify({
      message: 'No phone number saved for this contact.',
      color: 'warning',
      position: 'top',
      classes: 'custom-notify',
      icon: 'call',
    });
    return;
  }
  window.location.href = 'tel:' + phone.replace(/[^+0-9]/g, '');
}

async function handleLogout() {
  authStore.clearCachedRole();
  await supabase.auth.signOut();
  void router.push('/login');
}

onMounted(loadProfile);
</script>



<style scoped>
.profile-page { min-height: 100vh; background: var(--m-bg); color: var(--m-text); }
.profile-content { width: min(100%, 760px); margin: 0 auto; padding: max(var(--m-space-3), env(safe-area-inset-top)) max(var(--m-page-gutter), env(safe-area-inset-right)) calc(var(--m-space-8) + env(safe-area-inset-bottom)) max(var(--m-page-gutter), env(safe-area-inset-left)); }

/* ---------- Identity card ---------- */
.identity-card { position: relative; margin-bottom: var(--m-space-3); padding: var(--m-space-5) var(--m-space-5) var(--m-space-4); }
.identity-edit { position: absolute; top: var(--m-space-3); right: var(--m-space-3); display: grid; width: 32px; height: 32px; place-items: center; border: 1px solid var(--m-border); border-radius: 8px; background: var(--m-surface); color: var(--m-muted); cursor: pointer; }
.identity-edit:hover { border-color: var(--m-primary); color: var(--m-primary-dark); }
.identity-main { display: flex; align-items: flex-start; gap: var(--m-space-4); padding-right: 44px; }
.identity-avatar { flex: 0 0 auto; background: linear-gradient(135deg, var(--m-primary-dark), var(--m-primary)); font-size: 26px; font-weight: 800; cursor: pointer; }
.identity-copy { min-width: 0; flex: 1; }
.identity-name { margin: 0; color: var(--m-ink); font-family: var(--m-font-display); font-size: 21px; font-weight: 700; line-height: 1.2; overflow-wrap: anywhere; }
.identity-sub { margin: 3px 0 10px; color: var(--m-muted); font-size: 12px; }
.status-pill { display: inline-flex; min-height: 26px; align-items: center; gap: 6px; padding: 0 10px; border: 1px solid transparent; border-radius: 999px; font-size: 11px; font-weight: 750; }
.status-pill--verified { border-color: color-mix(in srgb, var(--m-success) 26%, transparent); background: var(--m-success-soft); color: var(--m-success); }
.status-pill--review { border-color: color-mix(in srgb, var(--m-warning) 30%, transparent); background: var(--m-warning-soft); color: var(--m-warning); }
.status-pill--unverified { border-color: var(--m-border); background: var(--m-bg); color: var(--m-muted); }

.enrollment-strip { display: flex; align-items: flex-start; gap: var(--m-space-3); margin-top: var(--m-space-4); padding: var(--m-space-3); border: 1px solid color-mix(in srgb, var(--m-warning) 26%, transparent); border-radius: var(--m-radius-sm); background: var(--m-warning-soft); }
.enrollment-strip--review { border-color: color-mix(in srgb, var(--m-info) 26%, transparent); background: var(--m-info-soft); }
.enrollment-strip__icon { display: grid; width: 34px; height: 34px; flex: 0 0 auto; place-items: center; border-radius: 8px; background: var(--m-surface); color: var(--m-warning); }
.enrollment-strip--review .enrollment-strip__icon { color: var(--m-info); }
.enrollment-strip__copy { display: flex; min-width: 0; flex-direction: column; }
.enrollment-strip__copy strong { color: var(--m-ink); font-size: 13px; line-height: 1.3; }
.enrollment-strip__copy span { margin-top: 2px; color: var(--m-muted); font-size: 11px; line-height: 1.4; }

/* ---------- Metrics ---------- */
.metrics-strip { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); margin-bottom: var(--m-space-4); padding: var(--m-space-1) 0; overflow: hidden; }
.metric { display: flex; min-width: 0; flex-direction: column; align-items: center; padding: var(--m-space-3); }
.metric + .metric { border-left: 1px solid var(--m-border); }
.metric strong { max-width: 100%; overflow: hidden; color: var(--m-ink); font-family: var(--m-font-display); font-size: 18px; font-weight: 800; letter-spacing: -0.01em; text-overflow: ellipsis; white-space: nowrap; }
.metric span { margin-top: 2px; color: var(--m-muted); font-size: 9px; font-weight: 800; letter-spacing: 0.04em; text-transform: uppercase; }
.rating-kpi { display: flex; align-items: center; flex-direction: column; margin-bottom: var(--m-space-4); padding: var(--m-space-4); text-align: center; }
.rating-kpi .rk-label { color: var(--m-muted); font-size: 10px; font-weight: 800; letter-spacing: 0.08em; text-transform: uppercase; }
.rating-kpi .rk-main { display: flex; align-items: center; gap: var(--m-space-3); margin-top: var(--m-space-2); }
.rating-kpi .rk-value { color: var(--m-ink); font-family: var(--m-font-display); font-size: 34px; font-weight: 800; letter-spacing: -0.03em; line-height: 1; }
.rating-kpi .rk-stars { display: inline-flex; align-items: center; gap: 2px; }
.rating-kpi .rk-stars svg { color: #d4d8de; }
.rating-kpi .rk-stars .rk-on { color:  var(--m-warning); }
.rating-kpi .rk-sub { margin-top: var(--m-space-2); color: var(--m-muted); font-size: 12px; }

/* ---------- Grouped list ---------- */
.list-group { margin-bottom: var(--m-space-4); }
.list-eyebrow { margin: 0 0 var(--m-space-2); padding: 0 var(--m-space-1); color: var(--m-muted); font-size: 10px; font-weight: 800; letter-spacing: 0.08em; text-transform: uppercase; }
.list-card { overflow: hidden; }
.list-row { display: flex; width: 100%; min-height: 64px; align-items: center; gap: var(--m-space-3); padding: var(--m-space-3) var(--m-space-4); border: 0; background: transparent; color: var(--m-ink); cursor: pointer; font: inherit; text-align: left; -webkit-tap-highlight-color: transparent; transition: background-color 0.12s ease; }
.list-row:active { background: color-mix(in srgb, var(--m-primary) 6%, transparent); }
.list-icon { display: grid; width: 36px; height: 36px; flex: 0 0 auto; place-items: center; border-radius: 9px; }
.list-icon--primary { background: var(--m-primary-soft); color: var(--m-primary-dark); }
.list-icon--warning { background: var(--m-warning-soft); color: var(--m-warning); }
.list-icon--neutral { background: var(--m-bg); color: var(--m-muted); }
.list-icon--danger { background: var(--m-danger-soft); color: var(--m-danger); }
.list-copy { display: flex; min-width: 0; flex: 1; flex-direction: column; gap: 2px; }
.list-copy strong { color: var(--m-ink); font-size: 14px; font-weight: 700; line-height: 1.3; }
.list-copy small { overflow: hidden; color: var(--m-muted); font-size: 12px; line-height: 1.4; text-overflow: ellipsis; white-space: nowrap; }
.list-row--danger .list-copy strong { color: var(--m-danger); }
.list-chevron { flex: 0 0 auto; color: #c2c8d0; }
.list-divider { display: block; height: 1px; margin: 0 var(--m-space-4); background: var(--m-border); }

/* ---------- Loading / error ---------- */
.profile-state { display: grid; min-height: 260px; align-content: center; justify-items: center; gap: var(--m-space-3); padding: var(--m-space-6); color: var(--m-muted); text-align: center; }
.profile-state--error { color: var(--m-danger); }
.profile-state-action { min-height: 44px; border-radius: var(--m-radius-sm); }

.surface-card { border: 1px solid var(--m-border); border-radius: var(--m-radius); background: var(--m-surface); }

/* ---------- Student QR section ---------- */
.qr-section { display: flex; align-items: center; justify-content: space-between; gap: var(--m-space-4); margin-bottom: var(--m-space-4); padding: var(--m-space-4); }
.qr-section-head { display: flex; min-width: 0; align-items: flex-start; gap: var(--m-space-3); flex: 1; }
.qr-section-icon { display: grid; width: 34px; height: 34px; flex: 0 0 auto; place-items: center; border-radius: 9px; background: var(--m-primary-soft); color: var(--m-primary-dark); }
.qr-section-head h2 { margin: 0; color: var(--m-ink); font-size: 14px; font-weight: 700; line-height: 1.3; }
.qr-section-head p { margin: 3px 0 0; color: var(--m-muted); font-size: 11px; line-height: 1.4; }
.qr-section-head p.qr-locked-copy { display: inline-flex; align-items: center; gap: 5px; color: var(--m-warning); font-weight: 650; }
.qr-section-head p.qr-locked-copy--live { color: var(--m-muted); font-weight: 400; }
.qr-wrap { display: grid; width: 118px; height: 118px; flex: 0 0 auto; place-items: center; }
.qr-code-large { width: 118px; height: 118px; border: 1px solid var(--m-border); border-radius: var(--m-radius-sm); padding: var(--m-space-2); }
.qr-locked { display: grid; width: 118px; height: 118px; place-items: center; border: 1.5px dashed var(--m-border); border-radius: var(--m-radius-sm); color: #c8ccd3; }

/* ---------- Sheet chrome ---------- */
.sheet-card { grid-column: 1 / -1; border: 0; border-radius: var(--m-radius-lg) var(--m-radius-lg) 0 0; box-shadow: 0 -8px 30px rgba(15, 23, 42, 0.14); color: var(--m-text); }
.housesheet { display: flex; max-height: 82vh; flex-direction: column; }
.housesheet .sheet-body--scroll { min-height: 0; }
.sheet-header { display: flex; min-height: 52px; align-items: flex-start; justify-content: space-between; flex-wrap: wrap; column-gap: var(--m-space-2); padding: var(--m-space-2) var(--m-space-4) var(--m-space-2); box-sizing: border-box; }
.sheet-header--fixed { flex: 0 0 auto; border-bottom: 1px solid var(--m-border); }
.sheet-grip { order: -1; flex: 1 1 100%; display: flex; align-items: center; justify-content: center; width: auto; height: auto; margin: 0 0 2px; padding: 6px 0 2px; background: transparent; }
.sheet-grip::after { content: ''; width: 40px; height: 4px; border-radius: 999px; background: #d8dce2; }
.sheet-grip--inline { flex: 0 0 auto; }
.sheet-title { margin: 0; color: var(--m-ink); font-family: var(--m-font-display); font-size: 18px; font-weight: 700; letter-spacing: -0.01em; }
.sheet-body { padding: var(--m-space-2) var(--m-space-4) var(--m-space-5); }
.sheet-slim { padding-top: var(--m-space-4); }
.sheet-body--center { display: flex; align-items: center; flex-direction: column; text-align: center; padding-top: var(--m-space-6); }
.sheet-loading-title { margin: var(--m-space-4) 0 0; color: var(--m-ink); font-size: 15px; font-weight: 700; }
.sheet-loading-sub { margin: var(--m-space-1) 0 0; color: var(--m-muted); font-size: 13px; line-height: 1.5; }
.sheet-footnote { margin: var(--m-space-4) 0 0; color: var(--m-muted); font-size: 11px; text-align: center; }
.sheet-success-icon { display: grid; width: 60px; height: 60px; margin-top: var(--m-space-4); place-items: center; border-radius: 50%; background: var(--m-success-soft); color: var(--m-success); }
.sheet-success-icon svg { box-sizing: content-box; padding: 14px; border: 2px solid var(--m-success); border-radius: 50%; }
.sheet-cta { width: 100%; min-height: 48px; margin-top: var(--m-space-4); border-radius: var(--m-radius-sm); font-weight: 800; }
.q-btn.sheet-cta:not(.q-btn--outline) { background: var(--m-primary-dark); }
.q-btn.sheet-cta.q-btn--outline { border-color: color-mix(in srgb, var(--m-danger) 30%, transparent); color: var(--m-danger); }
.q-btn.sheet-cta.q-btn--disabled { opacity: 0.55; }
.sheet-cta--ghost { width: 100%; }

/* ---------- Verification / QR ---------- */
.qr-panel { display: flex; justify-content: center; margin: var(--m-space-2) 0 var(--m-space-4); }
.qr-code { padding: var(--m-space-3); border: 1px solid var(--m-border); border-radius: var(--m-radius); }
.qr-empty { display: grid; width: 176px; height: 176px; place-items: center; border: 2px dashed var(--m-border); border-radius: var(--m-radius); color: #c8ccd3; }
.qr-caption { margin: 0 0 var(--m-space-3); color: var(--m-muted); font-size: 13px; line-height: 1.5; text-align: center; }
.confirm-card { display: flex; align-items: center; gap: var(--m-space-3); padding: var(--m-space-3); border: 1px solid var(--m-border); border-radius: var(--m-radius-sm); background: var(--m-bg); }
.confirm-copy { display: flex; min-width: 0; flex-direction: column; gap: 2px; }
.confirm-copy strong { overflow-wrap: anywhere; color: var(--m-ink); font-size: 13px; line-height: 1.3; }
.confirm-copy small { color: var(--m-muted); font-size: 11px; line-height: 1.4; }
.confirm-note { margin: var(--m-space-3) 0 var(--m-space-4); color: var(--m-muted); font-size: 12px; line-height: 1.5; }
.upload-card { display: flex; width: 100%; min-height: 70px; align-items: center; gap: var(--m-space-3); margin-bottom: var(--m-space-3); padding: var(--m-space-3); border: 1px solid var(--m-border); border-radius: var(--m-radius-sm); background: var(--m-surface); color: var(--m-ink); cursor: pointer; font: inherit; text-align: left; transition: border-color 0.15s ease, background-color 0.15s ease; }
.upload-card:hover { border-color: var(--m-primary); }
.upload-card--done { border-color: color-mix(in srgb, var(--m-success) 30%, transparent); background: var(--m-success-soft); }
.upload-icon { display: grid; width: 38px; height: 38px; flex: 0 0 auto; place-items: center; border-radius: 9px; background: var(--m-primary-soft); color: var(--m-primary-dark); }
.upload-icon--done { background: var(--m-surface); color: var(--m-success); }
.upload-copy { display: flex; min-width: 0; flex-direction: column; gap: 3px; }
.upload-copy strong { font-size: 13px; font-weight: 700; }
.upload-copy small { overflow: hidden; color: var(--m-muted); font-size: 11px; line-height: 1.35; text-overflow: ellipsis; white-space: nowrap; }

/* ---------- Accommodation sheet ---------- */
.sheet-block-top { display: flex; align-items: flex-start; justify-content: space-between; gap: var(--m-space-2); }
.sheet-block h3 { margin: 0; overflow-wrap: anywhere; color: var(--m-ink); font-family: var(--m-font-display); font-size: 17px; font-weight: 700; line-height: 1.3; }
.sheet-address { display: flex; align-items: center; gap: 5px; margin: 6px 0 0; color: var(--m-muted); font-size: 12px; line-height: 1.4; }
.sheet-address svg { flex: 0 0 auto; }
.stay-facts { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: var(--m-space-2); margin-top: var(--m-space-4); }
.stay-facts > div { min-width: 0; padding: var(--m-space-3); border-radius: var(--m-radius-sm); background: var(--m-bg); }
.stay-facts span { display: block; color: var(--m-muted); font-size: 9px; font-weight: 800; letter-spacing: 0.05em; text-transform: uppercase; }
.stay-facts strong { display: block; margin-top: 4px; overflow: hidden; color: var(--m-ink); font-size: 12px; line-height: 1.4; text-overflow: ellipsis; white-space: nowrap; }
.empty-icon { display: grid; width: 56px; height: 56px; margin-top: var(--m-space-4); place-items: center; border-radius: var(--m-radius-sm); background: var(--m-primary-soft); color: var(--m-primary-dark); }
.empty-note { margin: 0; padding: var(--m-space-4) 0; color: var(--m-muted); font-size: 13px; text-align: center; }

/* ---------- Timeline (history) ---------- */
.timeline-item { display: flex; }
.timeline-dot { position: relative; display: flex; width: 12px; margin-right: 14px; justify-content: center; flex-shrink: 0; }
.timeline-dot::before { content: ''; width: 12px; height: 12px; margin-top: 4px; border-radius: 50%; background: inherit; box-shadow: inset 0 0 0 2px var(--m-surface); }
.timeline-line { position: absolute; top: 22px; bottom: 0; width: 2px; background: var(--m-border); }
.timeline-item:last-child .timeline-line { display: none; }
.timeline-content { flex: 1; min-width: 0; padding-bottom: var(--m-space-4); }
.timeline-head { display: flex; align-items: flex-start; justify-content: space-between; gap: var(--m-space-2); }
.timeline-copy { display: flex; min-width: 0; flex-direction: column; gap: 2px; }
.timeline-copy strong { color: var(--m-ink); font-size: 14px; line-height: 1.3; }
.timeline-copy small { display: flex; align-items: center; gap: 5px; color: var(--m-muted); font-size: 12px; line-height: 1.4; }
.timeline-copy small svg { flex: 0 0 auto; }
.timeline-chip { flex: 0 0 auto; font-size: 11px; font-weight: 750; }

/* ---------- Fields ---------- */
.field-label { display: block; margin: 0 0 6px; color: var(--m-muted); font-size: 12px; font-weight: 650; }
.edit-avatar { display: flex; width: 100%; align-items: center; gap: var(--m-space-3); margin-bottom: var(--m-space-4); padding: var(--m-space-2); border: 0; background: transparent; color: var(--m-ink); cursor: pointer; font: inherit; text-align: left; -webkit-tap-highlight-color: transparent; }
.edit-avatar__preview { position: relative; display: grid; width: 72px; height: 72px; flex: 0 0 auto; place-items: center; overflow: hidden; border-radius: 50%; background: linear-gradient(135deg, var(--m-primary-dark), var(--m-primary)); color: #fff; font-size: 24px; font-weight: 800; }
.edit-avatar__preview img { width: 100%; height: 100%; object-fit: cover; }
.edit-avatar__ph { color: rgba(255, 255, 255, 0.95); }
.edit-avatar__cam { position: absolute; right: 1px; bottom: 1px; display: grid; width: 24px; height: 24px; place-items: center; border: 0; border-radius: 50%; background: var(--m-surface); color: var(--m-primary-dark); box-shadow: 0 0 0 1px var(--m-border); }
.edit-avatar__copy strong { display: block; font-size: 14px; font-weight: 700; }
.edit-avatar__copy small { color: var(--m-muted); font-size: 12px; }
.edit-sync-google { display: inline-flex; min-height: 40px; align-items: center; gap: 7px; padding: 0 4px; margin: -6px 0 14px; border: 0; background: transparent; color: var(--m-primary-dark); cursor: pointer; font: inherit; font-size: 13px; font-weight: 700; -webkit-tap-highlight-color: transparent; }
.edit-sync-google:disabled { opacity: 0.5; }
.field-input { width: 100%; margin-bottom: var(--m-space-4); }
.field-input :deep(.q-field__control) { min-height: 48px; border-radius: var(--m-radius-sm); }
.field-input:last-of-type { margin-bottom: 0; }

.pb-safe { padding-bottom: calc(var(--m-space-5) + env(safe-area-inset-bottom)); }

@media (prefers-reduced-motion: reduce) {
  * { scroll-behavior: auto !important; transition-duration: 0.01ms !important; }
}

/* Identity (manager-profile look) */
.surface-card { border: 1px solid var(--m-border); border-radius: var(--m-radius); background: var(--m-surface); }
.identity-card { position: relative; margin-bottom: var(--m-space-4); padding: var(--m-space-5) var(--m-space-5) var(--m-space-4); }
.identity-card-edit { position: absolute; top: var(--m-space-3); right: var(--m-space-3); display: grid; width: 32px; height: 32px; place-items: center; border: 1px solid var(--m-border); border-radius: 8px; background: var(--m-surface); color: var(--m-muted); cursor: pointer; }
.identity-card .identity-main { display: flex; align-items: center; gap: var(--m-space-4); margin: 0; padding: 0; }
.identity-card .identity-name { margin: 0; color: var(--m-ink); font-family: var(--m-font-display); font-size: 21px; font-weight: 700; line-height: 1.2; overflow-wrap: anywhere; }
.identity-card .identity-sub { margin: 3px 0 0; color: var(--m-muted); font-size: 12px; }
.identity-card .identity-copy { min-width: 0; flex: 1; }


/* QR sheet */
.qr-sheet-canvas { display: flex; justify-content: center; margin: var(--m-space-2) 0 var(--m-space-4); }
.qr-sheet-canvas img.qr-code { border: 1px solid var(--m-border); border-radius: var(--m-radius); padding: var(--m-space-3); }
.qr-caption { margin: 0 0 var(--m-space-3); color: var(--m-muted); font-size: 13px; line-height: 1.5; text-align: center; }
.sheet-slim { padding-top: var(--m-space-4); }



/* Student QR as a manager-style tile (QR mockup on the right) */
.qr-tool { display: flex; align-items: center; gap: var(--m-space-3); margin-bottom: var(--m-space-4); padding: var(--m-space-4); border-radius: var(--m-radius); }
.qr-tool-icon { display: grid; width: 46px; height: 46px; flex: 0 0 auto; place-items: center; border-radius: 11px; background: var(--m-primary-soft); color: var(--m-primary-dark); }
.qr-tool-copy { min-width: 0; flex: 1; }
.qr-tool-copy h2 { margin: 0; color: var(--m-ink); font-family: var(--m-font-display); font-size: 15px; font-weight: 700; line-height: 1.3; }
.qr-tool-copy p { display: flex; align-items: center; flex-wrap: wrap; gap: 2px 6px; margin: 3px 0 0; color: var(--m-muted); font-size: 12px; line-height: 1.4; }
.qr-tool-link { padding: 0; font-size: 12px; font-weight: 700; }
.qr-tool-mock { display: grid; width: 64px; height: 64px; flex: 0 0 auto; place-items: center; border-radius: 8px; background: var(--m-surface); color: var(--m-muted); border: 1px dashed var(--m-primary); overflow: hidden; }
.qr-mock-img { width: 100%; height: 100%; object-fit: contain; }
.qr-mock-lock { color: var(--m-warning); }
.qr-tool-expand { flex: 0 0 auto; color: var(--m-primary-dark); }

</style>
