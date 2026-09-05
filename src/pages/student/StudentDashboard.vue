<template>
  <q-page class="dash">
    <div v-if="loading" class="stack">
      <q-skeleton type="text" width="52%" height="26px" />
      <q-skeleton type="rect" height="64px" class="sk" />
      <q-skeleton type="rect" height="146px" class="sk" />
      <q-skeleton type="rect" height="120px" class="sk" />
      <q-skeleton type="rect" height="66px" class="sk" />
    </div>

    <div v-else-if="error" class="stack">
      <q-card flat bordered class="card card--pad text-center">
        <IconifyIcon icon="lucide:cloud-off" width="24" class="text-grey-6" />
        <p class="err-title">Couldn't load your dashboard</p>
        <p class="err-sub">{{ error }}</p>
        <q-btn unelevated rounded no-caps dense color="primary" label="Try again" class="q-mt-sm q-px-md" @click="load" />
      </q-card>
    </div>

    <div v-else class="stack">
      <div class="greet">
        <span class="greet-time">{{ greeting }},</span>
        <span class="greet-name">{{ firstName }}</span>
      </div>

      <!-- Stat tiles -->
      <template v-if="stay">
        <div class="tiles">
          <div class="tile tile--rent">
            <span class="tile-cap">Rent</span>
            <span class="tile-value">{{ formatPeso(stay.monthlyRent) }}<span class="tile-unit">/mo</span></span>
          </div>
          <div class="tile tile--lease" :class="{ 'tile--nudge': renewalSoon }">
            <template v-if="stay.status === 'pending'">
              <span class="tile-cap">Lease</span>
              <span class="tile-value tile-value--sm">Awaiting approval</span>
            </template>
            <template v-else>
              <div class="tile-left">
                <span class="tile-cap">{{ renewalSoon ? 'Ends soon' : 'Lease' }}</span>
                <span class="tile-value tile-value--sm">{{ daysLeft }}d left</span>
                <span v-if="renewalSoon" class="tile-note">Talk to your manager about renewing</span>
              </div>
              <svg viewBox="0 0 120 120" class="tile-ring" aria-hidden="true">
                <circle cx="60" cy="60" r="52" class="tile-ring-track" />
                <circle
                  cx="60" cy="60" r="52" class="tile-ring-fill"
                  :stroke-dasharray="`${(leaseProgressPct / 100) * 326.7} 326.7`"
                  transform="rotate(-90 60 60)"
                />
              </svg>
            </template>
          </div>
        </div>

        <div class="chips">
          <button type="button" class="chip chip--link" @click="go('/student/payments')">
            <span class="chip-value">{{ nextPayment ? formatPeso(nextPayment.amount) : 'None' }}</span>
            <span class="chip-label">{{ nextPayment ? (nextPayment.overdue ? 'Overdue' : 'Next due') : 'Dues on file' }}</span>
          </button>
          <div class="chip-div" />
          <div class="chip">
            <span class="chip-value">{{ attention.length || '✓' }}</span>
            <span class="chip-label">{{ attention.length ? 'Alerts' : 'All clear' }}</span>
          </div>
          <div class="chip-div" />
          <div class="chip">
            <span class="chip-value">{{ roommates.length || '—' }}</span>
            <span class="chip-label">{{ roommates.length ? 'Roommates' : 'Alone here' }}</span>
          </div>
        </div>
      </template>

      <!-- No active stay -->
      <div v-else class="stay stay--empty">
        <span class="stay-cap">No stay yet</span>
        <p class="stay-name">Find a place to stay</p>
        <p class="stay-room">Your room, rent and dates land here once a manager accepts you</p>
        <button type="button" class="stay-cta" @click="go('/student/discover')">
          Browse rooms
          <IconifyIcon icon="lucide:arrow-right" width="15" />
        </button>
      </div>

      <!-- Getting settled checklist -->
      <section v-if="showChecklist" class="sec">
        <div class="sec-head">
          <h2 class="sec-title">Getting settled</h2>
        </div>
        <div class="steps">
          <div v-for="row in checklist" :key="row.id" class="step">
            <template v-if="row.kind === 'row'">
              <span class="step-icon" :class="`step-icon--${row.state}`">
                <IconifyIcon :icon="row.icon" width="15" />
              </span>
              <span class="step-text">
                <span class="step-label">{{ row.label }}</span>
                <span v-if="row.hint" class="step-hint">{{ row.hint }}</span>
              </span>
              <button v-if="row.action" type="button" class="step-action" @click="go(row.route)">
                {{ row.action }}
              </button>
            </template>
            <template v-else>
              <div class="stepper">
                <span class="stepper-label">{{ row.label }}</span>
                <div class="stepper-track">
                  <span
                    v-for="(n, i) in ['Submitted', 'Under review', 'Decided']"
                    :key="n"
                    class="stepper-node"
                    :class="{ 'stepper-node--active': i === 1, 'stepper-node--done': i < 1 }"
                  >{{ n }}</span>
                </div>
              </div>
            </template>
          </div>
        </div>
      </section>

      <!-- Room identity -->
      <div v-if="stay" class="room-card">
        <div class="room-photo" :class="{ 'room-photo--empty': !stay.photoUrl }">
          <img v-if="stay.photoUrl" :src="stay.photoUrl" alt="" />
          <span v-else class="shot-empty">
            <IconifyIcon icon="lucide:image-off" width="24" />
            <span class="shot-empty-label">No photo</span>
          </span>
          <span class="room-tag">{{ statusLabel(stay.status) }}</span>
        </div>

        <div class="room-body">
          <p class="room-name">{{ stay.accommodationName }}</p>
          <p class="room-room">{{ roomLabel }}</p>
          <button v-if="mapUrl" type="button" class="room-map-link" @click="mapDialog = true">
            <IconifyIcon icon="lucide:map-pin" width="13" />
            View on map
          </button>

          <div v-if="houseRuleChips.length" class="rules">
            <span v-for="r in houseRuleChips" :key="r.label" class="rule-chip">{{ r.label }}: {{ r.value }}</span>
            <button type="button" class="rules-more" @click="go(`/student/listing/${stay.accommodationId}`)">
              View all
            </button>
          </div>

          <div v-if="manager" class="person">
            <span class="person-avatar">{{ manager.initials }}</span>
            <span class="person-body">
              <span class="person-name">{{ manager.name }}</span>
              <span class="person-role">
                Your manager<template v-if="manager.replyMinutes"> · replies in ~{{ manager.replyMinutes }} min</template>
              </span>
              <span v-if="manager.reviewCount > 0" class="person-rating">
                <IconifyIcon icon="lucide:star" width="11" />
                {{ manager.ratingAvg?.toFixed(1) }} ({{ manager.reviewCount }})
              </span>
            </span>
            <span class="person-actions">
              <button type="button" class="icon-btn" aria-label="Message manager" @click.stop="messageManager">
                <IconifyIcon icon="lucide:message-circle" width="17" />
              </button>
            </span>
          </div>

          <div v-if="roommates.length" class="mates">
            <span class="mates-stack" aria-hidden="true">
              <span v-for="m in roommates.slice(0, 4)" :key="m.id" class="mates-avatar">{{ m.initials }}</span>
              <span v-if="roommates.length > 4" class="mates-avatar mates-avatar--more">
                +{{ roommates.length - 4 }}
              </span>
            </span>
            <span class="mates-text">
              Sharing {{ stay?.roomNumber ? `Room ${stay.roomNumber}` : 'your room' }}
              with {{ roommates.length }} {{ roommates.length === 1 ? 'other' : 'others' }}
            </span>
          </div>
        </div>
      </div>

      <!-- Broadcast from OSAS -->
      <button v-if="notice" type="button" class="notice" @click="go('/student/support')">
        <span class="notice-icon"><IconifyIcon icon="lucide:megaphone" width="16" /></span>
        <span class="notice-body">
          <span class="notice-title">{{ notice.title }}</span>
          <span class="notice-text">{{ notice.body }}</span>
        </span>
        <span class="notice-when">{{ notice.when }}</span>
      </button>

      <!-- Needs attention: one actionable lead, the rest kept quiet -->
      <section class="sec">
        <div class="sec-head">
          <h2 class="sec-title">Needs attention</h2>
        </div>

        <div v-if="lead" class="lead" :class="`lead--${lead.tone}`">
          <div class="lead-top">
            <span class="lead-icon"><IconifyIcon :icon="lead.icon" width="18" /></span>
            <span class="lead-kind">{{ lead.kind }}</span>
            <span v-if="lead.when" class="lead-when">{{ lead.when }}</span>
          </div>
          <p class="lead-label">{{ lead.label }}</p>
          <p class="lead-hint">{{ lead.hint }}</p>
          <button v-if="lead.action" type="button" class="lead-action" @click="go(lead.route)">
            {{ lead.action }}
            <IconifyIcon icon="lucide:arrow-right" width="15" />
          </button>
        </div>

        <div v-if="rest.length" class="minors">
          <button
            v-for="item in rest"
            :key="item.id"
            type="button"
            class="minor"
            @click="go(item.route)"
          >
            <span class="minor-dot" :class="`minor-dot--${item.tone}`" />
            <span class="minor-text">
              <span class="minor-label">{{ item.label }}</span>
              <span class="minor-hint">{{ item.hint }}</span>
            </span>
            <span v-if="item.when" class="minor-when">{{ item.when }}</span>
          </button>
        </div>

        <div v-if="!attention.length" class="clear">
          <span class="clear-icon"><IconifyIcon icon="lucide:check" width="17" /></span>
          <span class="clear-text">
            <span class="clear-label">Nothing needs you</span>
            <span class="clear-hint">Concerns and manager replies land here</span>
          </span>
        </div>
      </section>
    </div>

    <q-dialog v-model="mapDialog" position="bottom" class="map-dialog">
      <div class="map-card">
        <span class="map-grip" aria-hidden="true" />
        <img v-if="mapUrl" :src="mapUrl" alt="Map showing your accommodation" class="map-image" />
        <q-btn flat dense no-caps color="grey-7" label="Close" class="map-close" @click="mapDialog = false" />
      </div>
    </q-dialog>
  </q-page>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { Icon as IconifyIcon } from '@iconify/vue'
import { supabase } from '@/utils/supabase'
import { formatPeso, initialsOf } from '@/utils/format'
import { ago } from '@/utils/profile'
import { resolveAsset } from '@/utils/cloudinaryUrl'
import { staticMapUrl } from '@/utils/geo'

interface Stay {
  id: string
  status: string
  startDate: string
  endDate: string
  monthlyRent: number
  accommodationId: string
  accommodationName: string
  roomNumber: string | null
  roomLabel: string | null
  lat: number | null
  lng: number | null
  photoUrl: string
  advancePaid: boolean
  depositPaid: boolean
}

interface AttentionItem {
  id: string
  icon: string
  kind: string
  label: string
  hint: string
  when: string
  /** Empty when there is nothing for the student to do but wait. */
  action: string
  route: string
  tone: 'danger' | 'warn' | 'info'
  rank: number
}

type ChecklistRow =
  | {
      kind: 'row'
      id: string
      icon: string
      label: string
      hint: string
      state: 'done' | 'pending' | 'action'
      action: string
      route: string
    }
  | { kind: 'stepper'; id: string; label: string }

interface HouseRuleChip {
  label: string
  value: string
}

interface NextPayment {
  amount: number
  overdue: boolean
}

interface Notice {
  title: string
  body: string
  when: string
}

interface Manager {
  id: string
  name: string
  initials: string
  replyMinutes: number | null
  ratingAvg: number | null
  reviewCount: number
}

interface Roommate {
  id: string
  initials: string
}

const MAX_MINOR = 3

const router = useRouter()

const loading = ref(true)
const error = ref('')
const firstName = ref('there')
const stay = ref<Stay | null>(null)
const attention = ref<AttentionItem[]>([])
const checklist = ref<ChecklistRow[]>([])
const houseRuleChips = ref<HouseRuleChip[]>([])
const nextPayment = ref<NextPayment | null>(null)
const notice = ref<Notice | null>(null)
const manager = ref<Manager | null>(null)
const roommates = ref<Roommate[]>([])
const mapDialog = ref(false)

const greeting = computed(() => {
  const h = new Date().getHours()
  return h < 12 ? 'Good morning' : h < 18 ? 'Good afternoon' : 'Good evening'
})

const lead = computed<AttentionItem | null>(() => attention.value[0] ?? null)
const rest = computed(() => attention.value.slice(1, 1 + MAX_MINOR))

const showChecklist = computed(() =>
  checklist.value.some((row) => (row.kind === 'row' ? row.state !== 'done' : true)),
)

const daysLeft = computed(() => {
  if (!stay.value) return null
  const end = new Date(stay.value.endDate).getTime()
  if (Number.isNaN(end)) return null
  return Math.ceil((end - Date.now()) / 86400000)
})

const leaseProgressPct = computed(() => {
  if (!stay.value) return 0
  const start = new Date(stay.value.startDate).getTime()
  const end = new Date(stay.value.endDate).getTime()
  if (Number.isNaN(start) || Number.isNaN(end) || end <= start) return 0
  const pct = ((Date.now() - start) / (end - start)) * 100
  return Math.min(100, Math.max(0, Math.round(pct)))
})

const renewalSoon = computed(
  () => stay.value?.status === 'active' && daysLeft.value !== null && daysLeft.value >= 0 && daysLeft.value <= 30,
)

const mapUrl = computed(() => (stay.value ? staticMapUrl(stay.value.lat, stay.value.lng) : ''))

const roomLabel = computed(() => {
  if (!stay.value) return ''
  const { roomNumber, roomLabel: label } = stay.value
  if (roomNumber && label) return `Room ${roomNumber} · ${label}`
  if (roomNumber) return `Room ${roomNumber}`
  return label || 'Room'
})

const STATUS_LABEL: Record<string, string> = {
  active: 'Active',
  pending: 'Pending',
  leave_requested: 'Leaving',
  ended: 'Ended',
  terminated: 'Ended',
}
function statusLabel(s: string) {
  return STATUS_LABEL[s] ?? s
}

function titleCase(raw: string | null | undefined) {
  if (!raw) return ''
  return raw.replace(/[_-]+/g, ' ').replace(/^\w/, (c) => c.toUpperCase())
}

function go(path: string) {
  void router.push(path)
}

// ?to= lets Messages find or create the thread with this manager.
function messageManager() {
  const id = manager.value?.id
  void router.push(id ? `/student/messages?to=${id}` : '/student/messages')
}

async function load() {
  loading.value = true
  error.value = ''
  try {
    const { data: auth } = await supabase.auth.getUser()
    const user = auth?.user
    if (!user) {
      void router.push('/login')
      return
    }

    const { data: profile } = await supabase
      .from('users')
      .select('full_name, status')
      .eq('id', user.id)
      .maybeSingle()
    firstName.value = String(profile?.full_name || 'there').split(' ')[0] || 'there'
    const verification = profile?.status || 'unverified'

    // A student holds at most one live lease, so one row is enough.
    const { data: leaseRow, error: leaseError } = await supabase
      .from('leases')
      .select(
        'id, status, start_date, end_date, monthly_rent, room_id, advance_paid, deposit_paid, rooms(room_number, label, monthly_rent, accommodations(id, name, accommodation_manager_id, lat, lng))',
      )
      .eq('student_id', user.id)
      .in('status', ['active', 'pending', 'leave_requested'])
      .order('start_date', { ascending: false })
      .limit(1)
      .maybeSingle()
    if (leaseError) throw leaseError

    type AccommodationEmbed = {
      id: string
      name: string
      accommodation_manager_id: string
      lat: number | null
      lng: number | null
    } | null

    if (leaseRow) {
      const room = leaseRow.rooms as unknown as {
        room_number: string | null
        label: string | null
        monthly_rent: number | null
        accommodations: AccommodationEmbed
      } | null
      const acc = room?.accommodations ?? null

      let photoUrl = ''
      houseRuleChips.value = []
      if (acc?.id) {
        const [{ data: imageRows }, { data: policyRow }] = await Promise.all([
          supabase
            .from('accommodation_images')
            .select('url, sort_order')
            .eq('accommodation_id', acc.id)
            .order('sort_order', { ascending: true })
            .limit(1),
          supabase
            .from('accommodation_policies')
            .select('curfew_time, quiet_hours, visitor_policy, cooking, laundry, pets, smoking')
            .eq('accommodation_id', acc.id)
            .maybeSingle(),
        ])
        photoUrl = imageRows?.[0]?.url ? resolveAsset(imageRows[0].url) : ''

        const chipCandidates: HouseRuleChip[] = policyRow
          ? [
              { label: 'Curfew', value: policyRow.curfew_time || '' },
              { label: 'Quiet hours', value: policyRow.quiet_hours || '' },
              { label: 'Visitors', value: policyRow.visitor_policy || '' },
              { label: 'Cooking', value: policyRow.cooking == null ? '' : policyRow.cooking ? 'Allowed' : 'Not allowed' },
              { label: 'Laundry', value: policyRow.laundry == null ? '' : policyRow.laundry ? 'Allowed' : 'Not allowed' },
              { label: 'Pets', value: policyRow.pets == null ? '' : policyRow.pets ? 'Allowed' : 'Not allowed' },
              { label: 'Smoking', value: policyRow.smoking == null ? '' : policyRow.smoking ? 'Allowed' : 'Not allowed' },
            ]
          : []
        houseRuleChips.value = chipCandidates.filter((c) => c.value).slice(0, 3)
      }

      stay.value = {
        id: leaseRow.id,
        status: leaseRow.status,
        startDate: leaseRow.start_date,
        endDate: leaseRow.end_date,
        monthlyRent: Number(leaseRow.monthly_rent ?? room?.monthly_rent ?? 0),
        accommodationId: acc?.id ?? '',
        accommodationName: acc?.name || 'Your accommodation',
        roomNumber: room?.room_number ?? null,
        roomLabel: room?.label ?? null,
        lat: acc?.lat ?? null,
        lng: acc?.lng ?? null,
        photoUrl,
        advancePaid: Boolean(leaseRow.advance_paid),
        depositPaid: Boolean(leaseRow.deposit_paid),
      }
    } else {
      stay.value = null
      houseRuleChips.value = []
    }

    // Newest live broadcast aimed at students.
    const { data: noticeRows } = await supabase
      .from('announcements')
      .select('title, body, published_at, expires_at')
      .in('audience', ['all', 'students'])
      .eq('archived', false)
      .or(`expires_at.is.null,expires_at.gt.${new Date().toISOString()}`)
      .order('published_at', { ascending: false })
      .limit(1)

    const top = noticeRows?.[0]
    notice.value = top
      ? { title: top.title, body: top.body || '', when: ago(top.published_at) }
      : null

    if (leaseRow) {
      const room = leaseRow.rooms as unknown as {
        accommodations: { accommodation_manager_id: string } | null
      } | null
      const managerId = room?.accommodations?.accommodation_manager_id

      if (managerId) {
        const [{ data: mgr }, { data: mgrProfile }, { data: mgrReviews }] = await Promise.all([
          supabase.from('users').select('full_name, initials').eq('id', managerId).maybeSingle(),
          supabase
            .from('accommodation_manager_profiles')
            .select('avg_response_minutes')
            .eq('user_id', managerId)
            .maybeSingle(),
          supabase.from('accommodation_manager_reviews').select('rating').eq('accommodation_manager_id', managerId),
        ])
        if (mgr) {
          const reviewRows = mgrReviews || []
          const reviewCount = reviewRows.length
          manager.value = {
            id: managerId,
            name: mgr.full_name,
            initials: mgr.initials || initialsOf(mgr.full_name),
            replyMinutes: mgrProfile?.avg_response_minutes ?? null,
            ratingAvg:
              reviewCount > 0
                ? reviewRows.reduce((sum, r) => sum + Number(r.rating || 0), 0) / reviewCount
                : null,
            reviewCount,
          }
        }
      }

      // Everyone else currently housed in the same room.
      const { data: mateRows } = await supabase
        .from('leases')
        .select('student_id, users!leases_student_id_fkey(full_name, initials)')
        .eq('room_id', leaseRow.room_id)
        .eq('status', 'active')
        .neq('student_id', user.id)

      roommates.value = (mateRows || []).map((m) => {
        const person = m.users as unknown as { full_name: string; initials: string | null } | null
        return {
          id: m.student_id,
          initials: person?.initials || initialsOf(person?.full_name || '?'),
        }
      })
    }

    const checklistRows: ChecklistRow[] = []

    // Verification: whether they must act depends on what they have already
    // submitted, so the pending documents decide the wording and the action.
    if (verification !== 'verified') {
      const { count: pendingDocs } = await supabase
        .from('verification_documents')
        .select('*', { count: 'exact', head: true })
        .eq('user_id', user.id)
        .eq('status', 'pending')

      if (verification === 'rejected' || verification === 'suspended') {
        checklistRows.push({
          kind: 'row',
          id: 'verify',
          icon: 'lucide:file-x',
          label: verification === 'rejected' ? 'Documents were rejected' : 'Account suspended',
          hint: verification === 'rejected' ? 'Upload clearer copies to get verified' : 'Contact OSAS to sort this out',
          state: 'action',
          action: verification === 'rejected' ? 'Re-upload documents' : 'Open OSAS',
          route: '/student/support',
        })
      } else if (pendingDocs && pendingDocs > 0) {
        checklistRows.push({
          kind: 'row',
          id: 'verify',
          icon: 'lucide:hourglass',
          label: 'OSAS is reviewing your documents',
          hint: `${pendingDocs} ${pendingDocs === 1 ? 'document' : 'documents'} submitted`,
          state: 'pending',
          action: '',
          route: '',
        })
      } else {
        checklistRows.push({
          kind: 'row',
          id: 'verify',
          icon: 'lucide:id-card',
          label: 'Finish your OSAS verification',
          hint: 'Managers can only accept verified students',
          state: 'action',
          action: 'Upload documents',
          route: '/student/support',
        })
      }
    } else {
      checklistRows.push({
        kind: 'row',
        id: 'verify',
        icon: 'lucide:shield-check',
        label: 'OSAS verified',
        hint: '',
        state: 'done',
        action: '',
        route: '',
      })
    }

    if (leaseRow?.status === 'pending') {
      checklistRows.push({ kind: 'stepper', id: 'application', label: 'Application status' })
    }

    if (stay.value) {
      checklistRows.push({
        kind: 'row',
        id: 'deposit',
        icon: stay.value.depositPaid ? 'lucide:check-circle' : 'lucide:circle-dashed',
        label: 'Security deposit',
        hint: stay.value.depositPaid ? 'Paid' : 'Not yet recorded as paid',
        state: stay.value.depositPaid ? 'done' : 'action',
        action: stay.value.depositPaid ? '' : 'Pay now',
        route: '/student/payments',
      })
      checklistRows.push({
        kind: 'row',
        id: 'advance',
        icon: stay.value.advancePaid ? 'lucide:check-circle' : 'lucide:circle-dashed',
        label: 'Advance payment',
        hint: stay.value.advancePaid ? 'Paid' : 'Not yet recorded as paid',
        state: stay.value.advancePaid ? 'done' : 'action',
        action: stay.value.advancePaid ? '' : 'Pay now',
        route: '/student/payments',
      })
    }

    checklist.value = checklistRows

    const items: AttentionItem[] = []

    if (leaseRow) {
      // Concerns the student filed against this stay, and any reply.
      const { data: concernRows } = await supabase
        .from('concerns')
        .select('id, category, status, reported_at, manager_response')
        .eq('lease_id', leaseRow.id)
        .neq('status', 'resolved')
        .order('reported_at', { ascending: false })
        .limit(4)

      for (const c of concernRows || []) {
        const answered = Boolean(c.manager_response)
        items.push({
          id: `concern-${c.id}`,
          icon: answered ? 'lucide:message-square-reply' : 'lucide:triangle-alert',
          kind: 'Your report',
          label: answered
            ? `Your manager replied about ${(titleCase(c.category) || 'your report').toLowerCase()}`
            : `${titleCase(c.category) || 'Concern'} still open`,
          hint: answered ? 'Read the reply and close it off' : 'Waiting on your manager',
          when: ago(c.reported_at),
          action: answered ? 'Read reply' : '',
          route: '/student/concerns',
          tone: answered ? 'warn' : 'info',
          rank: answered ? 0 : 3,
        })
      }

      // Unpaid rent, when payments are actually recorded — surfaced via the
      // "Next payment" stat tile instead of duplicated into this list.
      const { data: dueRows } = await supabase
        .from('payments')
        .select('id, amount, month, status')
        .eq('lease_id', leaseRow.id)
        .in('status', ['due', 'overdue'])
        .order('month', { ascending: true })
        .limit(1)

      const due = dueRows?.[0]
      nextPayment.value = due
        ? { amount: Number(due.amount || 0), overdue: due.status === 'overdue' }
        : null
    } else {
      nextPayment.value = null
    }

    // Unread messages from the manager.
    const { data: convos } = await supabase
      .from('conversations')
      .select('user_a_id, user_b_id, unread_a, unread_b')
      .or(`user_a_id.eq.${user.id},user_b_id.eq.${user.id}`)
    const unread = (convos || []).reduce((n, c) => {
      const mine = c.user_a_id === user.id ? c.unread_a : c.unread_b
      return n + Number(mine || 0)
    }, 0)
    if (unread > 0) {
      items.push({
        id: 'unread',
        icon: 'lucide:message-circle',
        kind: 'Messages',
        label: `${unread} unread ${unread === 1 ? 'message' : 'messages'}`,
        hint: 'From your accommodation manager',
        when: '',
        action: 'Open messages',
        route: '/student/messages',
        tone: 'warn',
        rank: 1,
      })
    }

    attention.value = items.sort((a, b) => a.rank - b.rank)
  } catch (e) {
    error.value = e instanceof Error ? e.message : 'Something went wrong.'
  } finally {
    loading.value = false
  }
}

onMounted(load)
</script>

<style scoped>
.dash { background: var(--m-bg); }
.stack {
  display: flex;
  flex-direction: column;
  gap: 7px;
  padding: 5px var(--m-page-gutter) 16px;
}
.sk { border-radius: var(--m-radius); }

.card { border-radius: var(--m-radius); background: var(--m-surface); overflow: hidden; }
.card--pad { padding: 18px 14px; }
.err-title { margin: 8px 0 0; color: var(--m-ink); font-size: 14px; font-weight: 700; }
.err-sub { margin: 2px 0 0; color: var(--m-muted); font-size: 12px; }

.greet { display: flex; align-items: baseline; gap: 5px; padding: 0 2px; flex-wrap: wrap; }
.greet-time { color: var(--m-muted); font-size: 15px; font-weight: 500; }
.greet-name {
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 20px;
  font-weight: 700;
  letter-spacing: -0.02em;
}

/* Getting settled checklist */
.steps { display: flex; flex-direction: column; gap: 3px; }
.step {
  display: flex;
  align-items: center;
  gap: 9px;
  padding: 8px 11px;
  border-radius: var(--m-radius-sm);
  background: var(--m-surface);
}
.step-icon { display: grid; width: 26px; height: 26px; flex: 0 0 26px; place-items: center; border-radius: 999px; }
.step-icon--done { background: var(--m-success-soft); color: var(--m-success); }
.step-icon--pending { background: var(--m-info-soft); color: var(--m-info); }
.step-icon--action { background: var(--m-warning-soft); color: var(--m-warning); }
.step-text { display: flex; min-width: 0; flex: 1 1 auto; flex-direction: column; gap: 1px; }
.step-label { color: var(--m-ink); font-size: 13px; font-weight: 600; }
.step-hint { color: var(--m-muted); font-size: 11.5px; }
.step-action {
  flex: 0 0 auto;
  min-height: 32px;
  padding: 0 11px;
  border: 0;
  border-radius: 999px;
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
  cursor: pointer;
  font: inherit;
  font-size: 12px;
  font-weight: 700;
  -webkit-tap-highlight-color: transparent;
}
.stepper { display: flex; width: 100%; flex-direction: column; gap: 6px; }
.stepper-label { color: var(--m-ink); font-size: 13px; font-weight: 600; }
.stepper-track { display: flex; align-items: center; gap: 4px; }
.stepper-node {
  flex: 1 1 0;
  padding: 5px 2px;
  border-radius: 999px;
  background: var(--m-border);
  color: var(--m-muted);
  font-size: 10px;
  font-weight: 700;
  text-align: center;
}
.stepper-node--done { background: var(--m-success-soft); color: var(--m-success); }
.stepper-node--active { background: var(--m-info-soft); color: var(--m-info); }

/* Stat tiles */
.tiles { display: grid; grid-template-columns: 1fr 1fr; gap: 7px; }
.tile {
  display: flex;
  flex-direction: column;
  justify-content: center;
  min-height: 84px;
  padding: 11px 13px;
  border-radius: var(--m-radius);
  background: var(--m-primary);
  color: #fff;
}
.tile--lease { flex-direction: row; align-items: center; justify-content: space-between; }
.tile--nudge { background: var(--m-warning); }
.tile-left { display: flex; min-width: 0; flex-direction: column; gap: 1px; }
.tile-cap { font-size: 10.5px; font-weight: 700; letter-spacing: 0.05em; text-transform: uppercase; opacity: 0.9; }
.tile-value {
  margin-top: 2px;
  font-family: var(--m-font-display);
  font-size: 22px;
  font-weight: 700;
  letter-spacing: -0.02em;
  line-height: 1;
}
.tile-value--sm { font-size: 16px; }
.tile-unit { font-size: 11px; font-weight: 600; opacity: 0.78; }
.tile-note { margin-top: 3px; font-size: 10.5px; line-height: 1.3; opacity: 0.92; text-wrap: pretty; }
.tile-ring { display: block; width: 46px; height: 46px; flex: 0 0 46px; }
.tile-ring-track { fill: none; stroke: rgba(255, 255, 255, 0.28); stroke-width: 12; }
.tile-ring-fill { fill: none; stroke: #fff; stroke-width: 12; stroke-linecap: round; transition: stroke-dasharray 0.5s ease; }

.chips { display: flex; align-items: stretch; border: 1px solid var(--m-border); border-radius: var(--m-radius); background: var(--m-surface); }
.chip { display: flex; flex: 1 1 0; min-width: 0; flex-direction: column; align-items: center; gap: 1px; padding: 8px 6px; text-align: center; }
.chip--link { border: 0; background: transparent; font: inherit; cursor: pointer; -webkit-tap-highlight-color: transparent; }
.chip-div { width: 1px; background: var(--m-border); }
.chip-value { color: var(--m-ink); font-family: var(--m-font-display); font-size: 15px; font-weight: 700; letter-spacing: -0.02em; }
.chip-label { color: var(--m-muted); font-size: 10.5px; font-weight: 600; }

/* Stay (empty state) */
.stay { display: flex; flex-direction: column; padding: 12px 13px; border-radius: var(--m-radius); }
.stay--empty { border: 1px dashed var(--m-border); background: var(--m-surface); color: var(--m-ink); }
.stay-cap { font-size: 11px; font-weight: 700; letter-spacing: 0.05em; text-transform: uppercase; color: var(--m-muted); }
.stay-name {
  margin: 5px 0 0;
  font-family: var(--m-font-display);
  font-size: 19px;
  font-weight: 700;
  letter-spacing: -0.02em;
  line-height: 1.15;
}
.stay-room { margin: 2px 0 0; font-size: 12.5px; color: var(--m-muted); }
.stay-cta {
  display: inline-flex;
  align-self: flex-start;
  align-items: center;
  gap: 6px;
  min-height: 40px;
  margin-top: 11px;
  padding: 0 15px;
  border: 0;
  border-radius: 999px;
  background: var(--m-primary);
  color: #fff;
  cursor: pointer;
  font: inherit;
  font-size: 13.5px;
  font-weight: 700;
  -webkit-tap-highlight-color: transparent;
}

/* Room identity */
.room-card { border-radius: var(--m-radius); background: var(--m-surface); border: 1px solid var(--m-border); overflow: hidden; }
.room-photo { position: relative; display: grid; height: 96px; place-items: center; background: var(--m-primary-soft); color: var(--m-primary-dark); }
.room-photo img { width: 100%; height: 100%; object-fit: cover; }
.room-photo--empty { background: linear-gradient(135deg, var(--m-border), var(--m-surface) 85%); }
.shot-empty { display: flex; flex-direction: column; align-items: center; gap: 4px; color: var(--m-muted); }
.shot-empty-label { font-size: 10.5px; font-weight: 700; letter-spacing: 0.02em; }
.room-tag {
  position: absolute;
  top: 8px;
  right: 8px;
  padding: 2px 9px;
  border-radius: 999px;
  background: rgba(0, 0, 0, 0.55);
  color: #fff;
  font-size: 10.5px;
  font-weight: 700;
}
.room-body { display: flex; flex-direction: column; gap: 6px; padding: 11px 13px 13px; }
.room-name { margin: 0; color: var(--m-ink); font-family: var(--m-font-display); font-size: 16px; font-weight: 700; letter-spacing: -0.02em; line-height: 1.2; }
.room-room { margin: 0; color: var(--m-muted); font-size: 12.5px; }
.room-map-link {
  display: inline-flex;
  align-self: flex-start;
  align-items: center;
  gap: 4px;
  border: 0;
  background: transparent;
  color: var(--m-primary-dark);
  cursor: pointer;
  font: inherit;
  font-size: 11.5px;
  font-weight: 700;
  -webkit-tap-highlight-color: transparent;
}

.rules { display: flex; flex-wrap: wrap; align-items: center; gap: 5px; margin-top: 2px; }
.rule-chip {
  padding: 3px 9px;
  border-radius: 999px;
  background: var(--m-bg);
  color: var(--m-text);
  font-size: 10.5px;
  font-weight: 600;
}
.rules-more {
  border: 0;
  background: transparent;
  color: var(--m-primary-dark);
  cursor: pointer;
  font: inherit;
  font-size: 10.5px;
  font-weight: 700;
  -webkit-tap-highlight-color: transparent;
}

/* People */
.person { display: flex; align-items: center; gap: 10px; margin-top: 4px; padding: 7px 0 0; border-top: 1px solid var(--m-border); }
.person-avatar {
  display: grid;
  width: 36px;
  height: 36px;
  flex: 0 0 36px;
  place-items: center;
  border-radius: 999px;
  background: var(--m-primary);
  color: #fff;
  font-size: 12.5px;
  font-weight: 800;
}
.person-body { display: flex; min-width: 0; flex: 1 1 auto; flex-direction: column; gap: 1px; }
.person-name { color: var(--m-ink); font-size: 14px; font-weight: 700; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.person-role { color: var(--m-muted); font-size: 11.5px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.person-rating { display: flex; align-items: center; gap: 3px; color: var(--m-warning); font-size: 11px; font-weight: 700; }
.person-actions { display: flex; flex: 0 0 auto; gap: 6px; }
.icon-btn {
  display: grid;
  width: 40px;
  height: 40px;
  place-items: center;
  border: 1px solid var(--m-border);
  border-radius: 999px;
  background: var(--m-surface);
  color: var(--m-primary-dark);
  cursor: pointer;
  text-decoration: none;
  -webkit-tap-highlight-color: transparent;
}

.mates { display: flex; align-items: center; gap: 10px; padding: 4px 0 0; }
.mates-stack { display: flex; flex: 0 0 auto; }
.mates-avatar {
  display: grid;
  width: 26px;
  height: 26px;
  place-items: center;
  margin-left: -7px;
  border: 2px solid var(--m-surface);
  border-radius: 999px;
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
  font-size: 9.5px;
  font-weight: 800;
}
.mates-avatar:first-child { margin-left: 0; }
.mates-avatar--more { background: var(--m-border); color: var(--m-text); }
.mates-text { color: var(--m-muted); font-size: 12px; font-weight: 600; }

/* Broadcast notice */
.notice {
  display: flex;
  width: 100%;
  align-items: flex-start;
  gap: 9px;
  padding: 9px 11px;
  border: 1px solid color-mix(in srgb, var(--m-info) 22%, var(--m-border));
  border-radius: var(--m-radius);
  background: var(--m-info-soft);
  cursor: pointer;
  font: inherit;
  text-align: left;
  -webkit-tap-highlight-color: transparent;
}
.notice-icon { display: grid; width: 26px; height: 26px; flex: 0 0 26px; place-items: center; border-radius: 999px; background: var(--m-surface); color: var(--m-info); }
.notice-body { display: flex; min-width: 0; flex: 1 1 auto; flex-direction: column; gap: 1px; }
.notice-title { color: var(--m-ink); font-size: 13px; font-weight: 700; line-height: 1.25; }
.notice-text {
  color: var(--m-text);
  font-size: 11.5px;
  line-height: 1.35;
  overflow: hidden;
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
}
.notice-when { flex: 0 0 auto; color: var(--m-muted); font-size: 11px; font-weight: 600; }

/* Sections */
.sec { display: flex; flex-direction: column; gap: 5px; }
.sec-head { display: flex; align-items: baseline; justify-content: space-between; gap: 8px; padding: 0 2px; }
.sec-title { margin: 0; color: var(--m-ink); font-size: 12.5px; font-weight: 700; letter-spacing: 0.02em; text-transform: uppercase; }

/* Lead */
.lead {
  display: flex;
  flex-direction: column;
  gap: 1px;
  padding: 11px;
  border-radius: var(--m-radius);
  background: var(--m-surface);
  border: 1px solid var(--m-border);
}
.lead--danger { border-color: color-mix(in srgb, var(--m-danger) 22%, var(--m-border)); }
.lead--warn { border-color: color-mix(in srgb, var(--m-warning) 26%, var(--m-border)); }
.lead--info { border-color: color-mix(in srgb, var(--m-info) 22%, var(--m-border)); }
.lead-top { display: flex; align-items: center; gap: 7px; }
.lead-icon { display: grid; width: 25px; height: 25px; flex: 0 0 25px; place-items: center; border-radius: 999px; }
.lead--danger .lead-icon { background: var(--m-danger-soft); color: var(--m-danger); }
.lead--warn .lead-icon { background: var(--m-warning-soft); color: var(--m-warning); }
.lead--info .lead-icon { background: var(--m-info-soft); color: var(--m-info); }
.lead-kind { flex: 1 1 auto; font-size: 11px; font-weight: 700; letter-spacing: 0.05em; text-transform: uppercase; }
.lead--danger .lead-kind { color: var(--m-danger); }
.lead--warn .lead-kind { color: var(--m-warning); }
.lead--info .lead-kind { color: var(--m-info); }
.lead-when { flex: 0 0 auto; color: var(--m-muted); font-size: 11.5px; font-weight: 600; }
.lead-label {
  margin: 3px 0 0;
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 15.5px;
  font-weight: 700;
  letter-spacing: -0.02em;
  line-height: 1.2;
  text-wrap: pretty;
}
.lead-hint { margin: 0; color: var(--m-muted); font-size: 11.5px; line-height: 1.3; text-wrap: pretty; }
.lead-action {
  display: inline-flex;
  align-self: flex-start;
  align-items: center;
  gap: 6px;
  min-height: 38px;
  margin-top: 7px;
  padding: 0 14px;
  border: 0;
  border-radius: 999px;
  background: var(--m-primary);
  color: #fff;
  cursor: pointer;
  font: inherit;
  font-size: 13.5px;
  font-weight: 700;
  -webkit-tap-highlight-color: transparent;
  transition: transform 0.12s ease;
}
.lead-action:active { transform: scale(0.97); }

/* Minors */
.minors { display: flex; flex-direction: column; gap: 3px; }
.minor {
  display: flex;
  width: 100%;
  min-height: 44px;
  align-items: center;
  gap: 9px;
  padding: 4px 11px;
  border: 0;
  border-radius: var(--m-radius-sm);
  background: var(--m-surface);
  cursor: pointer;
  font: inherit;
  text-align: left;
  -webkit-tap-highlight-color: transparent;
}
.minor-dot { width: 7px; height: 7px; flex: 0 0 7px; border-radius: 999px; }
.minor-dot--danger { background: var(--m-danger); }
.minor-dot--warn { background: var(--m-warning); }
.minor-dot--info { background: var(--m-info); }
.minor-text { display: flex; min-width: 0; flex: 1 1 auto; flex-direction: column; gap: 1px; }
.minor-label { color: var(--m-ink); font-size: 13px; font-weight: 600; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.minor-hint { color: var(--m-muted); font-size: 11.5px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.minor-when { flex: 0 0 auto; color: var(--m-muted); font-size: 11px; font-weight: 600; }

/* Clear */
.clear {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 10px 11px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius);
  background: var(--m-surface);
}
.clear-icon { display: grid; width: 30px; height: 30px; flex: 0 0 30px; place-items: center; border-radius: 999px; background: var(--m-success-soft); color: var(--m-success); }
.clear-text { display: flex; min-width: 0; flex-direction: column; gap: 2px; }
.clear-label { color: var(--m-ink); font-size: 14px; font-weight: 700; }
.clear-hint { color: var(--m-muted); font-size: 12px; }

/* Map bottom sheet */
.map-dialog :deep(.q-dialog__backdrop) { background: rgba(0, 0, 0, 0.5); }
.map-card {
  width: 100%;
  max-width: 480px;
  margin: 0 auto;
  padding: 10px 20px calc(20px + env(safe-area-inset-bottom, 0px));
  border-radius: var(--m-radius-lg) var(--m-radius-lg) 0 0;
  background: var(--m-surface);
  box-shadow: 0 -8px 30px rgba(0, 0, 0, 0.14);
  text-align: center;
}
.map-grip { display: block; width: 40px; height: 4px; margin: 0 auto 14px; border-radius: 999px; background: var(--m-border); }
.map-image { width: 100%; border-radius: var(--m-radius); }
.map-close { margin-top: 10px; }

@media (prefers-reduced-motion: reduce) {
  .lead-action { transition: none; }
  .tile-ring-fill { transition: none; }
}
</style>
