<template>
  <q-page class="person" :class="{ 'page-wide': split }">
    <!-- Mirrors PersonProfile's real shape — hero, overlapping card, tabs —
         so the layout does not jump when the data lands. On desktop that shape
         is the card's two halves, the person left and the history right. -->
    <div v-if="loading" :class="split ? 'desk-card' : 'stack'">
      <div :class="split ? 'desk-col' : 'desk-pass'">
        <q-skeleton type="rect" height="170px" square class="sk-hero" />
        <div class="sk-card">
          <q-skeleton type="circle" size="84px" style="margin-top: -42px; margin-bottom: 4px;" />
          <q-skeleton type="text" width="130px" height="17px" />
          <q-skeleton type="text" width="72px" height="18px" />
          <q-skeleton type="text" width="160px" height="12px" />
        </div>
        <div v-if="!split" class="sk-tabs">
          <q-skeleton type="rect" width="92px" height="38px" class="m-sk-tab" />
          <q-skeleton type="rect" width="92px" height="38px" class="m-sk-tab" />
        </div>
      </div>
      <div :class="split ? 'desk-col' : 'desk-pass'">
        <q-skeleton type="rect" height="120px" class="sk" />
      </div>
    </div>

    <EmptyState
      v-else-if="error"
      icon="lucide:user-x"
      title="Profile unavailable"
      :message="error"
    />

    <PersonProfile
      v-else
      v-model="tab"
      :tabs="TABS"
      :name="person.name"
      :initials="person.initials"
      :avatar-url="person.avatarUrl"
      :chip="chip.label"
      :chip-tone="chip.tone"
      :subtitle="subtitle"
      message-to
      :split="split"
      @message="message"
    >
      <div v-if="split || tab === 'overview'" class="sec">
        <template v-if="scan">
          <!-- Straight off a scan: this is the answer to "is this a real ISU
               student", so it leads. -->
          <div class="verdict" :class="scan.osasVerified ? 'verdict--ok' : 'verdict--no'">
            <IconifyIcon :icon="scan.osasVerified ? 'lucide:shield-check' : 'lucide:shield-alert'" width="20" />
            <div class="verdict-copy">
              <strong>{{ scan.osasVerified ? 'Verified ISU student' : 'Not verified by OSAS' }}</strong>
              <span>{{ scan.osasVerified
                ? 'OSAS checked this student\'s school ID and enrolment.'
                : 'OSAS has not confirmed this student\'s requirements. Do not treat this as proof.' }}</span>
            </div>
          </div>
          <p class="scan-note">
            Checked just now by {{ scan.method === 'manual' ? 'typed code' : 'QR scan' }}
          </p>

          <!-- Only a QR scan opens these: a typed number proves nobody is there. -->
          <div v-if="scan.method === 'qr'" class="docs">
            <span class="docs-label">Documents</span>
            <div class="docs-grid">
              <button
                v-for="d in scanDocList"
                :key="d.label"
                type="button"
                class="doc"
                :disabled="!d.file"
                @click="d.file && openDoc(d.file)"
              >
                <span class="doc-thumb" :class="{ 'doc-thumb--empty': !d.file }">
                  <q-spinner v-if="docsLoading" size="20px" />
                  <img v-else-if="d.file && !d.file.pdf" :src="d.file.url" alt="" />
                  <IconifyIcon v-else :icon="d.file ? 'lucide:file-text' : 'lucide:file-x'" width="24" />
                </span>
                <span class="doc-name">{{ d.label }}</span>
                <span v-if="!docsLoading && !d.file" class="doc-none">Not on file</span>
              </button>
            </div>
          </div>
        </template>

        <dl class="rows">
          <div v-if="person.studentId"><dt>Student number</dt><dd>{{ person.studentId }}</dd></div>
          <div v-if="person.program"><dt>Program</dt><dd>{{ person.program }}</dd></div>
          <div v-if="person.college"><dt>College</dt><dd>{{ person.college }}</dd></div>
          <div v-if="person.yearLevel"><dt>Year level</dt><dd>{{ person.yearLevel }}</dd></div>
          <div><dt>Role</dt><dd>{{ person.role === 'landlord' ? landlordTitle(person.sex) : 'Student' }}</dd></div>
        </dl>

        <div v-if="current" class="stay">
          <span class="stay-label">Currently boarding with you</span>
          <strong>{{ current.accommodationName }}</strong>
          <span class="stay-sub">{{ current.roomLabel }} · {{ formatPeso(current.rent) }}/mo</span>
        </div>
        <EmptyState
          v-else-if="person.role === 'student'"
          variant="compact"
          icon="lucide:door-closed"
          title="No active lease with you"
          message="This student does not currently board at your accommodation."
        />
      </div>

      <!-- The right half on desktop; the History tab elsewhere. -->
      <template #right>
      <div v-if="split || tab !== 'overview'" class="sec">
        <h2 v-if="split" class="desk-col-title">History</h2>
        <div v-if="history.length" class="hist">
          <div v-for="h in history" :key="h.id" class="hist-row">
            <span class="hist-icon"><IconifyIcon icon="lucide:building-2" width="17" /></span>
            <div class="hist-copy">
              <strong>{{ h.accommodationName }}</strong>
              <small>{{ h.roomLabel }}</small>
              <small>{{ h.period }}</small>
            </div>
            <span class="hist-tag" :class="h.current ? 'hist-tag--now' : ''">{{ h.current ? 'Current' : 'Past' }}</span>
          </div>
        </div>
        <EmptyState
          v-else
          variant="compact"
          icon="lucide:history"
          title="No shared history"
          message="No lease records between the two of you."
        />
      </div>
      </template>
    </PersonProfile>
    <PhotoViewer v-model="viewerUrl" />
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, reactive, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { Icon as IconifyIcon } from '@iconify/vue'
import { supabase, authUser } from '@/utils/supabase'
import { useQrStore } from '@/stores/qr'
import { isDesktop } from '@/utils/useTabletMode'
import { resolveAsset, AVATAR } from '@/utils/cloudinaryUrl'
import { initialsOf, formatPeso, landlordTitle } from '@/utils/format'
import { period } from '@/utils/profile'
import PersonProfile from '@/components/shared/PersonProfile.vue'
import EmptyState from '@/components/shared/EmptyState.vue'
import PhotoViewer from '@/components/shared/PhotoViewer.vue'
import { scannedStudentDocs, type ScanDoc } from '@/utils/upload'
import { openExternal } from '@/utils/openExternal'
import { fetchSharedLeaseHistory } from '@/api/leases';

// One profile screen for "the other person", reached from a conversation or
// straight off a QR scan. Academic details come from student_profiles when the
// lease relationship makes them readable, and from the scan payload otherwise —
// verify_student_qr() is the only path that may expose a non-tenant's details,
// and it logs every look.

const TABS = [
  { key: 'overview', label: 'Overview' },
  { key: 'history', label: 'History' },
] as const

const route = useRoute()
const router = useRouter()
const qrStore = useQrStore()

const role = computed<'manager' | 'student'>(() =>
  route.path.startsWith('/manager') ? 'manager' : 'student',
)
// Given directly when Messages shows this inside its right panel on desktop;
// otherwise it is the route's own :id.
const props = defineProps<{ personId?: string }>()
const targetId = computed(() => props.personId || String(route.params.id ?? ''))
// Desktop, as a page of its own: profile and overview on the left, history on
// the right. Not inside the Messages panel, which is already a half.
const split = computed(() => isDesktop.value && !props.personId)

const loading = ref(true)
const error = ref('')
const tab = ref<string>('overview')

const person = reactive({
  name: '',
  initials: '?',
  avatarUrl: null as string | null,
  role: '',
  studentId: null as string | null,
  program: null as string | null,
  college: null as string | null,
  yearLevel: null as number | null,
  osasVerified: false,
  // Drives the Landlord / Landlady chip below. Null is normal and falls back to
  // the neutral compound.
  sex: null as string | null,
})

const history = ref<{ id: string; accommodationName: string; roomLabel: string; period: string; current: boolean }[]>([])
const current = ref<{ accommodationName: string; roomLabel: string; rent: number } | null>(null)

// Only when this page was opened by scanning this very person.
const scan = computed(() =>
  qrStore.scannedStudent?.userId === targetId.value ? qrStore.scannedStudent : null,
)

// The scanned student's ID and assessment of fees, signed for 5 minutes.
const scanDocs = ref<{ schoolId: ScanDoc | null; assessmentOfFees: ScanDoc | null } | null>(null)
const docsLoading = ref(false)
const scanDocList = computed(() => [
  { label: 'School ID', file: scanDocs.value?.schoolId ?? null },
  { label: 'Assessment of fees', file: scanDocs.value?.assessmentOfFees ?? null },
])
const viewerUrl = ref('')
function openDoc(d: ScanDoc) {
  if (d.pdf) openExternal(d.url)
  else viewerUrl.value = d.url
}
async function loadScanDocs() {
  docsLoading.value = true
  try {
    scanDocs.value = await scannedStudentDocs(targetId.value)
  } finally {
    docsLoading.value = false
  }
}

const chip = computed<{ label: string; tone: 'good' | 'warn' | 'idle' }>(() => {
  if (person.role !== 'student') return { label: landlordTitle(person.sex), tone: 'idle' }
  return person.osasVerified
    ? { label: 'OSAS verified', tone: 'good' }
    : { label: 'Not verified', tone: 'warn' }
})

const subtitle = computed(() => {
  const bits = [person.program, person.yearLevel ? `Year ${person.yearLevel}` : ''].filter(Boolean)
  return bits.join(' · ')
})

function message() {
  void router.push(`/${role.value}/messages?to=${targetId.value}`)
}

onMounted(async () => {
  if (scan.value?.method === 'qr') void loadScanDocs()
  try {
    const { data: auth } = await authUser()
    const me = auth?.user?.id
    if (!me || !targetId.value) throw new Error('Not signed in.')

    const { data: user } = await supabase
      .from('users')
      .select('full_name, initials, avatar_url, role, sex')
      .eq('id', targetId.value)
      .maybeSingle()

    if (user) {
      person.name = user.full_name || 'Unknown'
      person.initials = user.initials || initialsOf(person.name)
      person.avatarUrl = user.avatar_url ? resolveAsset(user.avatar_url, AVATAR) : null
      person.role = user.role ?? ''
      person.sex = user.sex ?? null
    } else if (scan.value) {
      // users RLS (can_notify) hides anyone without a shared lease or
      // conversation — exactly who a manager scans. The scan payload stands in.
      person.name = scan.value.name
      person.initials = scan.value.initials
      person.avatarUrl = scan.value.avatarUrl
      person.role = 'student'
    } else {
      // Hidden by RLS and deleted look the same from here, so say both.
      throw new Error(
        role.value === 'manager'
          ? 'You can only view a student you have messaged or leased to. Scan their QR code to see their profile — or the account may have been deleted.'
          : 'You can only view someone you have messaged or leased with. The account may also have been deleted.',
      )
    }

    // Readable only when a lease already links us; the scan payload covers the
    // case where it does not.
    const { data: sp } = await supabase
      .from('student_profiles')
      .select('student_id, program, college, year_level, osas_verified_at')
      .eq('user_id', targetId.value)
      .maybeSingle()

    if (sp) {
      person.studentId = sp.student_id
      person.program = sp.program
      person.college = sp.college
      person.yearLevel = sp.year_level
      person.osasVerified = Boolean(sp.osas_verified_at)
    } else if (scan.value) {
      person.studentId = scan.value.studentId
      person.program = scan.value.program
      person.college = scan.value.college
      person.yearLevel = scan.value.yearLevel
      person.osasVerified = scan.value.osasVerified
    }

    // Leases between the two of us, whichever way round we are.
    const studentSide = person.role === 'student' ? targetId.value : me
    const managerSide = person.role === 'student' ? me : targetId.value
    const leases = await fetchSharedLeaseHistory(studentSide, managerSide)
    const rows = (leases ?? []) as unknown as {
      id: string
      status: string
      start_date: string | null
      end_date: string | null
      monthly_rent: number | null
      rooms: { room_number: string | null; label: string | null; accommodations: { name: string | null } | null } | null
    }[]

    history.value = rows.map((l) => ({
      id: l.id,
      accommodationName: l.rooms?.accommodations?.name || 'Accommodation',
      roomLabel: l.rooms?.label || (l.rooms?.room_number ? `Room ${l.rooms.room_number}` : 'Room'),
      period: period(l.start_date, l.end_date),
      current: l.status === 'active',
    }))

    const active = rows.find((l) => l.status === 'active')
    current.value = active
      ? {
          accommodationName: active.rooms?.accommodations?.name || 'Accommodation',
          roomLabel: active.rooms?.label || (active.rooms?.room_number ? `Room ${active.rooms.room_number}` : 'Room'),
          rent: Number(active.monthly_rent ?? 0),
        }
      : null
  } catch (e) {
    error.value = e instanceof Error ? e.message : 'Could not load this profile.'
  } finally {
    loading.value = false
  }
})
</script>

<style scoped>
.person { background: var(--m-bg); }
/* Desktop: the card fills the page below a gutter, like every other halves page. */
.person.page-wide { display: flex; flex-direction: column; padding: 8px var(--m-page-gutter) 0; }
.stack { display: flex; flex-direction: column; gap: 10px; padding-bottom: 20px; }
.sk { margin: 0 var(--m-page-gutter); border-radius: var(--m-radius); }
.sk-card {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 4px;
  margin: -85px var(--m-page-gutter) 0;
  padding: 0 var(--m-page-gutter) 14px;
  border-radius: var(--m-radius);
  background: var(--m-surface);
  box-shadow: var(--m-shadow);
}
.sk-tabs { display: flex; gap: 4px; margin: 0 var(--m-page-gutter); }
/* Desktop halves (app.scss): as PersonProfile's, the hero bleeds to the
   half's edges and the card overlaps it, so the half drops its gap. */
.desk-card .desk-col:first-child { gap: 0; }
.desk-card .sk-hero { width: auto; margin: -14px -18px 0; }
.desk-card .sk { margin: 0; }
.sec { display: flex; flex-direction: column; gap: 12px; }

.verdict {
  display: flex;
  align-items: flex-start;
  gap: 10px;
  padding: 11px 12px;
  border-radius: var(--m-radius);
}
.verdict--ok { background: var(--m-success-soft); color: var(--m-success); }
.verdict--no { background: var(--m-warning-soft); color: var(--m-warning); }
.verdict-copy { display: flex; flex-direction: column; gap: 2px; }
.verdict-copy strong { font-size: 13.5px; font-weight: 750; }
.verdict-copy span { color: var(--m-text); font-size: 11.5px; line-height: 1.4; }
.scan-note { margin: -6px 0 0; color: var(--m-muted); font-size: 11px; font-weight: 600; }

.docs { display: flex; flex-direction: column; gap: 8px; }
.docs-label {
  color: var(--m-muted);
  font-size: 10.5px;
  font-weight: 700;
  letter-spacing: 0.04em;
  text-transform: uppercase;
}
.docs-grid { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 10px; }
.doc {
  display: flex;
  min-width: 0;
  flex-direction: column;
  gap: 2px;
  padding: 0 0 9px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius);
  background: var(--m-bg);
  color: inherit;
  cursor: pointer;
  font: inherit;
  overflow: hidden;
  text-align: left;
  -webkit-tap-highlight-color: transparent;
}
.doc:disabled { cursor: default; }
.doc-thumb {
  display: grid;
  aspect-ratio: 4 / 3;
  margin-bottom: 6px;
  place-items: center;
  border-bottom: 1px solid var(--m-border);
  background: var(--m-surface);
  color: var(--m-primary-dark);
  overflow: hidden;
}
.doc-thumb img { width: 100%; height: 100%; object-fit: cover; }
.doc-thumb--empty { color: var(--m-muted); }
.doc-name { padding: 0 10px; color: var(--m-ink); font-size: 12.5px; font-weight: 700; }
.doc-none { padding: 0 10px; color: var(--m-muted); font-size: 11px; font-weight: 600; }

.rows { margin: 0; }
.rows > div {
  display: flex;
  align-items: baseline;
  justify-content: space-between;
  gap: 12px;
  padding: 9px 0;
}
.rows > div + div { border-top: 1px solid var(--m-border); }
.rows dt { color: var(--m-muted); font-size: 12px; font-weight: 600; }
.rows dd { margin: 0; color: var(--m-ink); font-size: 13px; font-weight: 700; text-align: right; }

.stay {
  display: flex;
  flex-direction: column;
  gap: 2px;
  padding: 11px 12px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius);
  background: var(--m-bg);
}
.stay-label {
  color: var(--m-muted);
  font-size: 10.5px;
  font-weight: 700;
  letter-spacing: 0.04em;
  text-transform: uppercase;
}
.stay strong { color: var(--m-ink); font-size: 14px; font-weight: 750; }
.stay-sub { color: var(--m-text); font-size: 12px; font-weight: 600; }

.hist { display: flex; flex-direction: column; gap: 8px; }
.hist-row {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 10px 12px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius);
  background: var(--m-bg);
}
.hist-icon {
  display: grid;
  width: 32px;
  height: 32px;
  flex: 0 0 32px;
  place-items: center;
  border-radius: 999px;
  background: var(--m-primary-soft);
  color: var(--m-primary);
}
.hist-copy { display: flex; min-width: 0; flex: 1 1 auto; flex-direction: column; }
.hist-copy strong { color: var(--m-ink); font-size: 13px; font-weight: 700; }
.hist-copy small { color: var(--m-muted); font-size: 11px; font-weight: 600; }
.hist-tag {
  flex: 0 0 auto;
  padding: 2px 8px;
  border-radius: 999px;
  background: var(--m-bg);
  color: var(--m-muted);
  font-size: 10.5px;
  font-weight: 700;
}
.hist-tag--now { background: var(--m-success-soft); color: var(--m-success); }
</style>
