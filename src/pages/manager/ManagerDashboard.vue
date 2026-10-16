<template>
  <q-page class="dash" :style-fn="fitScreen">
    <q-pull-to-refresh @refresh="onPull">
      <div v-if="loading" class="stack">
        <q-skeleton type="text" width="160px" height="26px" />
        <q-skeleton type="rect" height="132px" class="sk" />
        <q-skeleton type="rect" height="64px" class="sk" />
        <q-skeleton type="rect" height="176px" class="sk" />
      </div>

      <div v-else-if="error" class="stack">
        <ErrorCard title="Couldn't load your dashboard" :detail="error" :retry="load" />
      </div>

      <div v-else class="stack">
        <!-- The one-screen rule (390x844, no scroll): greeting, hero, one action, four tiles, two properties. -->
        <h1 class="greet">{{ unverified && !verification.inReview ? 'Welcome' : 'Hi' }}, {{ firstName }}</h1>

        <!-- Unverified: where the OSAS check stands (D-LE1 / D-LE2). Verified: this month's rent (D-L5 / D-LE3). -->
        <DashHero
          v-if="unverified"
          label="OSAS verification"
          :right="verification.inReview ? `Sent ${sentLabel}` : `Step ${Math.min(verification.done + 1, 3)} of 3`"
          :big="String(verification.done)"
          of="/ 3 steps done"
          :segments="verifySegments"
          :legend="verifyLegend"
          to="/manager/osas"
        />
        <DashHero
          v-else
          :label="`${monthName} rent`"
          :right="`${daysLeft} ${daysLeft === 1 ? 'day' : 'days'} left`"
          :big="formatPeso(rent.collected)"
          :of="`/ ${formatPeso(rent.total)}`"
          :segments="[
            { value: rent.collected, tone: 'success' },
            { value: rent.coming, tone: 'info' },
            { value: rent.late, tone: 'danger' },
          ]"
          :legend="[
            { label: 'Paid', value: formatPeso(rent.collected), tone: 'success' },
            { label: 'Coming', value: formatPeso(rent.coming), tone: 'info' },
            { label: 'Late', value: formatPeso(rent.late), tone: 'danger' },
          ]"
          to="/manager/tenants?tab=payments"
        />

        <DashAction
          v-if="action"
          :icon="action.icon"
          :tone="action.tone"
          :title="action.title"
          :sub="action.sub"
          :button="action.button"
          @action="go(action.route)"
        />

        <div class="tiles">
          <component
            :is="unverified ? 'div' : 'button'"
            v-for="t in tiles"
            :key="t.label"
            :type="unverified ? undefined : 'button'"
            class="tile"
            :class="{ 'tile--off': unverified, [`tile--${t.tone}`]: !unverified && t.tone }"
            @click="unverified || go(t.route)"
          >
            <span class="tile-val">{{ t.value }}</span>
            <span class="tile-label">{{ t.label }}</span>
            <span class="tile-sub">{{ t.sub }}</span>
          </component>
        </div>

        <section class="sec" aria-labelledby="myprops">
          <div class="sec-head">
            <h2 id="myprops" class="sec-title">My properties</h2>
            <button v-if="properties.length > shownProperties.length" type="button" class="sec-link" @click="go('/manager/properties')">
              See all
            </button>
          </div>

          <div v-if="hasProperties" class="plist">
            <DashPropertyCard
              v-for="p in shownProperties"
              :key="p.id"
              :property="p"
              :paid="propRent[p.id]?.paid ?? 0"
              :due="propRent[p.id]?.due ?? 0"
              :dot="propRent[p.id]?.dot ?? false"
              @open="openProperty"
            />
          </div>

          <PropertyCard v-else-if="auth.isVerifiedLandlord" add-label="Add your first accommodation" @add="go('/manager/properties/new')" />

          <div v-else class="locked">
            <span class="locked-icon"><IconifyIcon icon="lucide:lock" width="18" /></span>
            <span class="locked-text">
              <span class="locked-title">Add property</span>
              <span class="locked-sub">After OSAS verifies you</span>
            </span>
          </div>
        </section>
      </div>
    </q-pull-to-refresh>
  </q-page>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue'
import { useRouter } from 'vue-router'
import { Icon as IconifyIcon } from '@iconify/vue'
import { supabase, authUser } from '@/utils/supabase'
import { useLiveData } from '@/utils/useLiveData'
import { formatPeso } from '@/utils/format'
import { ago, listGaps, loadProfileGaps } from '@/utils/profile'
import { resolveAsset, CARD } from '@/utils/cloudinaryUrl'
import ErrorCard from '@/components/shared/ErrorCard.vue'
import DashHero from '@/components/shared/DashHero.vue'
import DashAction from '@/components/shared/DashAction.vue'
import DashPropertyCard from '@/components/manager/DashPropertyCard.vue'
import { fetchLandlordMoney } from '@/api/landlordMoney'
import { buildCollections, monthEndOf, type Collections } from '@/utils/collections'
import { BILL_TAG, manilaToday } from '@/utils/payments'
import { verificationSteps } from '@/utils/verificationSteps'
import { useAuthStore } from '@/stores/auth'
import PropertyCard from '@/components/manager/PropertyCard.vue'
import { healthTone, type Property } from '@/components/manager/property'
import type { Task } from '@/components/shared/dashboard'

const router = useRouter()

// One-screen rule: the page is exactly the space between header and bottom nav
// (QPage's style-fn gets both), and the layout below flexes inside it instead of
// scrolling. The flexible card (stay / property photos) absorbs the difference.
const fitScreen = (offset: number, height: number) => ({ height: `${height - offset}px` })
const auth = useAuthStore()

const loading = ref(true)
const error = ref('')
const firstName = ref('there')
const properties = ref<Property[]>([])
const attention = ref<Task[]>([])
const totalBeds = ref(0)
const tenants = ref(0)

// Money, worked out in load() so the kept-alive page and its cache hold plain numbers.
interface Rent { collected: number; coming: number; late: number; total: number }
interface LateAction { studentId: string; name: string; days: number; amount: number; property: string }
interface Tile { value: string; label: string; sub: string; route: string; tone?: 'warning' | undefined }
const rent = ref<Rent>({ collected: 0, coming: 0, late: 0, total: 0 })
const propRent = ref<Record<string, { paid: number; due: number; dot: boolean }>>({})
const lateAction = ref<LateAction | null>(null)
const confirmCount = ref(0)
const unpaidBills = ref<{ amount: number; sub: string }>({ amount: 0, sub: 'All paid' })
const applicants = ref<{ count: number; sub: string; route: string }>({ count: 0, sub: 'None new', route: '/manager/tenants' })
const docsSentAt = ref<string | null>(null)
const profileComplete = ref(true)

const hasProperties = computed(() => properties.value.length > 0)
const vacantBeds = computed(() => Math.max(0, totalBeds.value - tenants.value))

// Verified accounts see the rent dashboard; everyone else sees where the OSAS
// check stands (users.status is the truth, accountStatus mirrors it). An unknown
// status (still loading, demo mode) counts as verified so nothing flashes.
const unverified = computed(() => !!auth.accountStatus && auth.accountStatus !== 'verified')
const verification = computed(() =>
  verificationSteps({
    role: 'manager',
    status: auth.accountStatus ?? '',
    docsSentAt: docsSentAt.value,
    profileComplete: profileComplete.value,
  }),
)
const shortDate = (iso: string) => new Date(iso).toLocaleDateString('en-PH', { month: 'short', day: 'numeric' })
const sentLabel = computed(() => (docsSentAt.value ? shortDate(docsSentAt.value) : ''))
const verifySegments = computed(() => {
  const v = verification.value
  return [
    { value: v.done, tone: 'primary' },
    { value: v.inReview ? 1 : 0, tone: 'info' },
    { value: v.total - v.done - (v.inReview ? 1 : 0), tone: 'border' },
  ]
})
const verifyLegend = computed(() => {
  const v = verification.value
  return [
    { label: 'Done', value: String(v.done), tone: 'primary' },
    v.inReview
      ? { label: 'In review', value: '1', tone: 'info' }
      : { label: 'Left', value: String(v.total - v.done), tone: 'muted' },
  ]
})

const monthName = new Date().toLocaleDateString('en-PH', { month: 'long' })
const daysLeft = Math.max(0, Number(monthEndOf(manilaToday()).slice(8, 10)) - Number(manilaToday().slice(8, 10)))

// The attention list is ranked (0 = concern / hidden listings … 3 = chores). A rank-0 or
// 1 item outranks a late boarder; a late boarder outranks everything below that.
const SHORT_TONE = { danger: 'danger', warn: 'warning', info: 'info', done: 'success' } as const
const action = computed(() => {
  if (unverified.value) {
    const v = verification.value
    return v.next
      ? { icon: 'lucide:file-up', tone: 'warning', title: v.next.label, sub: 'Next step', button: 'Open', route: v.next.route }
      : { icon: 'lucide:hourglass', tone: 'info', title: 'OSAS is reviewing', sub: 'We’ll notify you', button: 'Ask OSAS', route: '/manager/support' }
  }
  const top = attention.value[0]
  const l = lateAction.value
  if (l && !(top && top.rank <= 1)) {
    return {
      icon: 'lucide:clock-alert',
      tone: 'danger',
      title: `${l.name} is ${l.days} ${l.days === 1 ? 'day' : 'days'} late`,
      sub: `${formatPeso(l.amount)} · ${l.property}`,
      button: 'Remind',
      route: `/manager/messages?to=${l.studentId}`,
    }
  }
  if (top) {
    return {
      icon: top.icon,
      tone: SHORT_TONE[top.tone],
      title: top.label,
      sub: top.kind,
      button: top.action.split(' ')[0] ?? '',
      route: top.route,
    }
  }
  const [y, m] = manilaToday().split('-').map(Number) as [number, number]
  const next = new Date(y, m, 1)
  return {
    icon: 'lucide:circle-check',
    tone: 'success',
    title: 'Nothing needs you',
    sub: `Next: ${next.toLocaleDateString('en-PH', { month: 'long' })} rent · ${next.toLocaleDateString('en-PH', { month: 'short' })} 1`,
    button: '',
    route: '',
  }
})

const todoCount = computed(() => attention.value.filter((t) => t.id !== 'payments-to-verify').length + confirmCount.value)
const tiles = computed<Tile[]>(() => {
  const off = unverified.value
  const open = vacantBeds.value
  return [
    {
      value: off ? '0' : String(todoCount.value),
      label: 'To do',
      sub: off ? 'Nothing yet' : confirmCount.value ? `${confirmCount.value} payment${confirmCount.value === 1 ? '' : 's'} to check` : todoCount.value ? 'Tap to start' : 'All done',
      route: confirmCount.value ? '/manager/tenants?tab=payments' : (attention.value[0]?.route ?? '/manager/properties'),
      tone: !off && todoCount.value ? 'warning' : undefined,
    },
    {
      value: `${tenants.value}/${totalBeds.value}`,
      label: 'Beds filled',
      sub: off || !totalBeds.value ? 'No rooms yet' : `${open} open`,
      route: '/manager/properties',
    },
    {
      value: formatPeso(unpaidBills.value.amount),
      label: 'Unpaid bills',
      sub: off ? 'No bills yet' : unpaidBills.value.sub,
      route: '/manager/tenants?tab=payments',
    },
    {
      value: String(applicants.value.count),
      label: 'Applicants',
      sub: off ? 'None yet' : applicants.value.sub,
      route: applicants.value.route,
    },
  ]
})

// Two property cards fit the screen; the rest are one tap away. Worst health first.
const HEALTH_RANK = { danger: 0, warn: 1, good: 2 } as const
const shownProperties = computed(() =>
  [...properties.value].sort((a, b) => HEALTH_RANK[healthTone(a)] - HEALTH_RANK[healthTone(b)]).slice(0, 2),
)

/** The boarder who is furthest behind, for the action card. */
function lateOf(col: Collections): LateAction | null {
  const o = [...col.late].sort((a, b) => (b.daysLate ?? 0) - (a.daysLate ?? 0))[0]
  if (!o) return null
  return {
    studentId: o.lease.studentId,
    name: o.lease.studentName.split(' ')[0] || 'A boarder',
    days: o.daysLate ?? 0,
    amount: o.amount,
    property: o.lease.accommodationName,
  }
}

function titleCase(raw: string | null | undefined) {
  if (!raw) return ''
  return raw.replace(/[_-]+/g, ' ').replace(/^\w/, (c) => c.toUpperCase())
}

function go(path: string) {
  void router.push(path)
}

function openProperty(id: string) {
  go(`/manager/properties/${id}`)
}

async function load(silent = false) {
  if (!silent) loading.value = true
  error.value = ''
  try {
    const { data: auth } = await authUser()
    const user = auth?.user
    if (!user) {
      void router.push('/login')
      return
    }

    // Everything keyed only off the landlord/landlady's own id goes out at once. These
    // ran as nine round trips in series, which was comfortably the slowest
    // thing about the first screen a landlord/landlady sees.
    const [
      { data: profile },
      { data: accRows, error: accError },
      { data: leaseRows, error: leaseError },
      { data: concernRows },
      { data: peopleRows },
      { count: paymentsToVerify },
      { data: docRowsSent },
      money,
    ] = await Promise.all([
      supabase.from('users').select('full_name').eq('id', user.id).maybeSingle(),
      supabase
        .from('accommodations')
        .select('id, name, status, address, barangay, purok, city, accommodation_type, total_rooms')
        .eq('landlord_id', user.id),
      supabase
        .from('leases')
        .select('id, status, monthly_rent, room_id')
        .eq('landlord_id', user.id)
        .in('status', ['active', 'pending', 'leave_requested']),
      supabase
        .from('concerns')
        .select(
          'id, category, reported_at, leases!inner(landlord_id, users!leases_student_id_fkey(full_name), rooms(accommodations(name)))',
        )
        .eq('leases.landlord_id', user.id)
        .neq('status', 'resolved')
        .order('reported_at', { ascending: false })
        .limit(6),
      supabase
        .from('leases')
        .select(
          'id, status, start_date, leave_requested_at, users!leases_student_id_fkey(full_name), rooms(room_number, accommodations(name))',
        )
        .eq('landlord_id', user.id)
        .in('status', ['pending', 'leave_requested'])
        .limit(6),
      // Only the number: the list itself lives on Tenants → Payments.
      supabase
        .from('payments')
        .select('id, leases!inner(landlord_id)', { count: 'exact', head: true })
        .eq('leases.landlord_id', user.id)
        .eq('status', 'pending_verification'),
      // "Sent Oct 13" on the verification hero: the newest upload.
      supabase
        .from('verification_documents')
        .select('uploaded_at')
        .eq('user_id', user.id)
        .order('uploaded_at', { ascending: false })
        .limit(1),
      // A failed money read leaves the rent card at zero rather than blanking the whole screen.
      fetchLandlordMoney(user.id).catch((e) => {
        console.warn('dashboard: money read failed', e)
        return null
      }),
    ])
    if (accError) throw accError
    if (leaseError) throw leaseError

    firstName.value = String(profile?.full_name || 'there').split(' ')[0] || 'there'

    const accs = accRows || []
    const accIds = accs.map((a) => a.id)
    const accName = new Map(accs.map((a) => [a.id, a.name]))

    // Second wave: rooms, photos and permits all key off the accommodation ids
    // above, so they couldn't join the first — but they can go out together.
    // Skipped entirely for a landlord/landlady with no accommodations, which is half of
    // them (see the data notes in CLAUDE.md).
    let roomRows: {
      id: string
      accommodation_id: string
      capacity: number | null
      water_billing: string | null
      electric_billing: string | null
      wifi_billing: string | null
    }[] = []
    let imageRows: { accommodation_id: string; url: string; sort_order: number | null }[] = []
    let docRows: {
      id: string
      doc_type: string
      expires_at: string | null
      accommodation_id: string
    }[] = []
    if (accIds.length) {
      const [rooms, images, docs] = await Promise.all([
        supabase
          .from('rooms')
          .select('id, accommodation_id, capacity, water_billing, electric_billing, wifi_billing')
          .in('accommodation_id', accIds),
        supabase
          .from('accommodation_images')
          .select('accommodation_id, url, sort_order')
          .in('accommodation_id', accIds)
          .order('sort_order', { ascending: true }),
        supabase
          .from('accommodation_documents')
          .select('id, doc_type, expires_at, accommodation_id')
          .in('accommodation_id', accIds),
      ])
      if (rooms.error) throw rooms.error
      roomRows = rooms.data || []
      imageRows = images.data || []
      docRows = docs.data || []
    }

    const leases = leaseRows || []
    const roomToAcc = new Map(roomRows.map((r) => [r.id, r.accommodation_id]))
    const filledByAcc = new Map<string, number>()
    for (const l of leases) {
      if (l.status !== 'active') continue
      const accId = roomToAcc.get(l.room_id)
      if (accId) filledByAcc.set(accId, (filledByAcc.get(accId) || 0) + 1)
    }

    const capacityByAcc = new Map<string, number>()
    const roomCountByAcc = new Map<string, number>()
    for (const r of roomRows) {
      capacityByAcc.set(r.accommodation_id, (capacityByAcc.get(r.accommodation_id) || 0) + Number(r.capacity || 0))
      roomCountByAcc.set(r.accommodation_id, (roomCountByAcc.get(r.accommodation_id) || 0) + 1)
    }

    totalBeds.value = roomRows.reduce((n, r) => n + Number(r.capacity || 0), 0)
    tenants.value = leases.filter((l) => l.status === 'active').length
    docsSentAt.value = (Array.isArray(docRowsSent) ? docRowsSent[0]?.uploaded_at : null) ?? null

    // A photo per accommodation, fetched once for the whole portfolio.
    const photoByAcc = new Map<string, string>()
    for (const img of imageRows) {
      if (!photoByAcc.has(img.accommodation_id)) {
        photoByAcc.set(img.accommodation_id, resolveAsset(img.url, CARD))
      }
    }

    // Document tracking
    const expiredByAcc = new Map<string, number>()
    const expiringSoonByAcc = new Map<string, number>()
    const items: Task[] = []

    {
      const now = Date.now()
      const soon = now + 30 * 24 * 60 * 60 * 1000

      for (const d of docRows) {
        if (!d.expires_at) continue
        const t = new Date(d.expires_at).getTime()
        const where = accName.get(d.accommodation_id) || 'Accommodation'
        if (t < now) {
          expiredByAcc.set(d.accommodation_id, (expiredByAcc.get(d.accommodation_id) || 0) + 1)
          items.push({
            id: `doc-${d.id}`,
            icon: 'lucide:file-warning',
            kind: 'OSAS',
            label: `${titleCase(d.doc_type)} expired`,
            hint: `${where} — accreditation is at risk until this is renewed`,
            when: ago(d.expires_at),
            action: 'Upload renewal',
            route: '/manager/osas',
            tone: 'danger',
            rank: 1,
          })
        } else if (t < soon) {
          expiringSoonByAcc.set(d.accommodation_id, (expiringSoonByAcc.get(d.accommodation_id) || 0) + 1)
          items.push({
            id: `doc-soon-${d.id}`,
            icon: 'lucide:calendar-clock',
            kind: 'OSAS',
            label: `${titleCase(d.doc_type)} expires soon`,
            hint: `${where} — renew it before it lapses`,
            when: '',
            action: 'Renew now',
            route: '/manager/osas',
            tone: 'warn',
            rank: 3,
          })
        }
      }
    }

    // Rooms that don't yet say how utilities are paid — every room from before
    // utilities were per room. Students see nothing for them, and a draft
    // can't be submitted until they're set, so it's a task, not a footnote.
    const unsetByAcc = new Map<string, number>()
    for (const r of roomRows) {
      if (r.water_billing && r.electric_billing && r.wifi_billing) continue
      unsetByAcc.set(r.accommodation_id, (unsetByAcc.get(r.accommodation_id) || 0) + 1)
    }
    for (const [accId, count] of unsetByAcc) {
      items.push({
        id: `utilities-${accId}`,
        icon: 'lucide:plug-zap',
        kind: 'Utilities',
        label: `Set utilities on ${count} room${count === 1 ? '' : 's'}`,
        hint: `${accName.get(accId) || 'Accommodation'} — students can't see how water, power and Wi-Fi are paid`,
        when: '',
        action: 'Set utilities',
        route: `/manager/properties/${accId}`,
        tone: 'warn',
        rank: 3,
      })
    }

    properties.value = accs.map((a) => ({
      id: a.id,
      name: a.name,
      status: a.status,
      type: titleCase(a.accommodation_type),
      address: a.address || [a.purok, a.barangay, a.city].filter(Boolean).join(', '),
      roomCount: a.total_rooms ?? roomCountByAcc.get(a.id) ?? null,
      capacity: capacityByAcc.get(a.id) || 0,
      filled: filledByAcc.get(a.id) || 0,
      image: photoByAcc.get(a.id) || '',
      expired: expiredByAcc.get(a.id) || 0,
      expiringSoon: expiringSoonByAcc.get(a.id) || 0,
    }))

    // Rest of attention items (concerns, applications, leave requests). Both
    // sets were fetched in the first wave; the ordering here still decides
    // where they land among the equal-rank items, since the sort below is
    // stable.
    for (const c of concernRows || []) {
      const lease = c.leases as unknown as {
        users: { full_name: string } | null
        rooms: { accommodations: { name: string } | null } | null
      } | null
      const who = lease?.users?.full_name || 'A boarder'
      const where = lease?.rooms?.accommodations?.name
      items.push({
        id: `concern-${c.id}`,
        icon: 'lucide:message-square-warning',
        kind: 'Student concern',
        label: `${titleCase(c.category) || 'Concern'} reported by ${who}`,
        hint: where ? `At ${where} — awaiting your reply` : 'Awaiting your reply',
        when: ago(c.reported_at),
        action: 'Reply',
        route: '/manager/support',
        tone: 'danger',
        rank: 0,
      })
    }

    // One grouped row, like "Set utilities": a busy month would otherwise bury
    // concerns and applications under a row per payment.
    if (paymentsToVerify) {
      items.push({
        id: 'payments-to-verify',
        icon: 'lucide:receipt',
        kind: 'Payments',
        label: `Verify ${paymentsToVerify} payment${paymentsToVerify === 1 ? '' : 's'}`,
        hint: 'Students are waiting for these to be marked paid',
        when: '',
        action: 'Verify',
        route: '/manager/tenants?tab=payments',
        tone: 'warn',
        rank: 2,
      })
    }

    for (const l of peopleRows || []) {
      const who =
        (l.users as unknown as { full_name: string } | null)?.full_name || 'A student'
      const room = l.rooms as unknown as {
        room_number: string | null
        accommodations: { name: string } | null
      } | null
      const where = [room?.room_number ? `Room ${room.room_number}` : '', room?.accommodations?.name]
        .filter(Boolean)
        .join(' · ')
      if (l.status === 'pending') {
        items.push({
          id: `app-${l.id}`,
          icon: 'lucide:user-plus',
          kind: 'Application',
          label: `${who} wants to move in`,
          hint: where || 'Waiting on your decision',
          when: ago(l.start_date),
          action: 'Review application',
          route: `/manager/tenant/${l.id}`,
          tone: 'warn',
          rank: 2,
        })
      } else {
        items.push({
          id: `leave-${l.id}`,
          icon: 'lucide:door-open',
          kind: 'Leave request',
          label: `${who} wants to move out`,
          hint: where || 'Waiting on your decision',
          when: ago(l.leave_requested_at),
          action: 'Review request',
          route: `/manager/tenant/${l.id}`,
          tone: 'warn',
          rank: 2,
        })
      }
    }

    // OSAS has hidden their listings (account_standing, written only by OSAS):
    // the first thing they should read, with the reason OSAS gave.
    const { data: standing } = await supabase
      .from('account_standing')
      .select('reason, restrictions')
      .eq('user_id', user.id)
      .maybeSingle()
    if (standing?.restrictions?.includes('listings')) {
      items.push({
        id: 'osas-listings',
        icon: 'lucide:eye-off',
        kind: 'OSAS',
        label: 'OSAS has hidden your listings',
        hint: standing.reason || 'Students cannot see your accommodations for now',
        when: '',
        action: 'Contact OSAS',
        route: '/manager/support',
        tone: 'danger',
        rank: 0,
      })
    }

    // Sex and birth date are blank on older accounts; one row opens the step-by-step flow.
    const missing = (await loadProfileGaps(user.id, false)).filter((g) => g.needed)
    if (missing.length) {
      items.push({
        id: 'profile',
        icon: 'lucide:user-round-pen',
        kind: 'Profile',
        label: 'Complete your profile',
        hint: `Add your ${listGaps(missing)}`,
        when: '',
        action: 'Continue',
        route: '/manager/profile/complete',
        tone: 'warn',
        rank: 3,
      })
    }

    attention.value = items.sort((a, b) => a.rank - b.rank)

    profileComplete.value = missing.length === 0

    // Applicants: pending leases, named from the first-wave people query.
    const pendingCount = leases.filter((l) => l.status === 'pending').length
    const firstPending = (peopleRows || []).find((l) => l.status === 'pending')
    const pRoom = firstPending?.rooms as unknown as { room_number: string | null } | null
    const pName = (firstPending?.users as unknown as { full_name: string } | null)?.full_name?.split(' ')[0]
    applicants.value = {
      count: pendingCount,
      sub: pName ? `${pName}${pRoom?.room_number ? ` · Room ${pRoom.room_number}` : ''}` : pendingCount ? 'Waiting on you' : 'None new',
      route: firstPending ? `/manager/tenant/${firstPending.id}` : '/manager/tenants',
    }

    // Rent card, late boarder, bills and per-property rent: all the same buildCollections the
    // Payments tab uses, so the numbers cannot disagree with it.
    if (money) {
      const day = manilaToday()
      const col = buildCollections(money.leases, money.ledger, money.payments, money.billUtility, money.billed, day)
      rent.value = {
        collected: col.collected,
        coming: col.toConfirm + col.toCome,
        late: col.overdue,
        total: col.collected + col.toConfirm + col.toCome + col.overdue,
      }
      confirmCount.value = col.confirm.length
      lateAction.value = lateOf(col)

      // Bill rows with something left to pay, on stays that are still running.
      const current = new Set(money.leases.filter((l) => l.status === 'active' || l.status === 'leave_requested').map((l) => l.id))
      const bills = money.ledger
        .filter((r) => r.kind === 'bill' && r.balance > 0.009 && current.has(r.leaseId))
        .sort((a, b) => (a.dueDate ?? '').localeCompare(b.dueDate ?? ''))
      const first = bills[0]
      unpaidBills.value = {
        amount: bills.reduce((n, r) => n + r.balance, 0),
        sub: first
          ? `${(BILL_TAG[money.billUtility[first.billId ?? ''] ?? 'water'] ?? 'Bill').replace(' bill', '')}${first.dueDate ? ` · due ${shortDate(first.dueDate)}` : ''}`
          : 'All paid',
      }

      const per: typeof propRent.value = {}
      for (const p of properties.value) {
        const ids = new Set(money.leases.filter((l) => l.accommodationId === p.id).map((l) => l.id))
        const c = buildCollections(
          money.leases.filter((l) => ids.has(l.id)),
          money.ledger.filter((r) => ids.has(r.leaseId)),
          money.payments.filter((x) => ids.has(x.leaseId)),
          money.billUtility,
          money.billed,
          day,
        )
        per[p.id] = {
          paid: c.collected,
          due: c.collected + c.toConfirm + c.toCome + c.overdue,
          dot: c.late.length > 0 || c.confirm.length > 0 || p.expired > 0,
        }
      }
      propRent.value = per
    } else {
      rent.value = { collected: 0, coming: 0, late: 0, total: 0 }
      propRent.value = {}
      lateAction.value = null
      confirmCount.value = 0
      unpaidBills.value = { amount: 0, sub: 'All paid' }
    }
  } catch (e) {
    error.value = e instanceof Error ? e.message : 'Something went wrong.'
  } finally {
    loading.value = false
  }
}

// Kept alive across tab switches (see MainLayout's KEEP_ALIVE_PAGES), so the
// database pushes lease changes here instead of the page re-asking on every
// return. utils/useLiveData.ts owns the whole policy — first load, the
// subscription's lifetime, and how stale the data may be on return.
type DashboardCache = {
  firstName: string
  properties: Property[]
  attention: Task[]
  totalBeds: number
  tenants: number
  rent: Rent
  propRent: Record<string, { paid: number; due: number; dot: boolean }>
  lateAction: LateAction | null
  confirmCount: number
  unpaidBills: { amount: number; sub: string }
  applicants: { count: number; sub: string; route: string }
  docsSentAt: string | null
  profileComplete: boolean
}

const { refresh } = useLiveData({
  // -v2: the 2026-10 redesign changed the cached shape (rent, tiles); an old
  // cache restored into it crashed the render on first launch after updating.
  key: 'manager-dashboard-v2',
  load,
  // leases/payments are not in the realtime publication; every payment and
  // lease event notifies this user, so their notifications are the signal.
  watch: (uid) => [
    { table: 'leases', filter: `landlord_id=eq.${uid}` },
    { table: 'notifications', filter: `user_id=eq.${uid}` },
  ],
  cache: {
    get: (): DashboardCache => ({
      firstName: firstName.value,
      properties: properties.value,
      attention: attention.value,
      totalBeds: totalBeds.value,
      tenants: tenants.value,
      rent: rent.value,
      propRent: propRent.value,
      lateAction: lateAction.value,
      confirmCount: confirmCount.value,
      unpaidBills: unpaidBills.value,
      applicants: applicants.value,
      docsSentAt: docsSentAt.value,
      profileComplete: profileComplete.value,
    }),
    set: (d) => {
      const c = d as DashboardCache
      firstName.value = c.firstName
      properties.value = c.properties
      attention.value = c.attention
      totalBeds.value = c.totalBeds
      tenants.value = c.tenants
      rent.value = c.rent
      propRent.value = c.propRent
      lateAction.value = c.lateAction
      confirmCount.value = c.confirmCount
      unpaidBills.value = c.unpaidBills
      applicants.value = c.applicants
      docsSentAt.value = c.docsSentAt
      profileComplete.value = c.profileComplete
      loading.value = false
    },
  },
})

// Pull-to-refresh goes through useLiveData's refresh rather than load(): it
// loads silently (no skeleton behind the spinner) and resets the freshness
// clock, so returning to the screen does not immediately fetch again.
function onPull(done: () => void) {
  void refresh().finally(done)
}
</script>

<style scoped>
.dash { overflow: hidden; background: var(--m-bg); }
.dash :deep(.q-pull-to-refresh),
.dash :deep(.q-pull-to-refresh__content) { height: 100%; }
.stack {
  display: flex;
  height: 100%;
  box-sizing: border-box;
  flex-direction: column;
  overflow: hidden;
  gap: 10px;
  /* Bottom room for BottomNav's raised centre button. */
  padding: 4px var(--m-page-gutter) 26px;
}
.sk { border-radius: var(--m-radius); }

.greet {
  margin: 0;
  padding: 0 2px;
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 22px;
  font-weight: 700;
  /* Quasar's global h1 line-height is 6rem; without this the greeting sits in a 96px band. */
  line-height: 1.2;
  letter-spacing: -0.02em;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.stack > * { flex-shrink: 0; }

.tiles { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 10px; }
.tile {
  display: flex;
  min-width: 0;
  flex-direction: column;
  gap: 2px;
  padding: 12px 14px;
  border: 0;
  border-radius: 20px;
  background: var(--m-surface);
  color: inherit;
  cursor: pointer;
  font: inherit;
  text-align: left;
  -webkit-tap-highlight-color: transparent;
}
.tile--warning { background: var(--m-warning-soft); }
.tile-val {
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 24px;
  font-weight: 700;
  line-height: 1.1;
}
.tile-label { color: var(--m-ink); font-size: 14px; font-weight: 600; }
.tile-sub { overflow: hidden; color: var(--m-muted); font-size: 12.5px; text-overflow: ellipsis; white-space: nowrap; }
/* Before OSAS verifies there is nothing to count: the tiles show their shape, greyed. */
.tile--off { cursor: default; }
.tile--off .tile-val { color: var(--m-muted); opacity: 0.6; }

.stack > .sec { display: flex; flex: 1 1 auto; min-height: 0; flex-direction: column; gap: 8px; }
.sec-head { display: flex; align-items: center; justify-content: space-between; gap: 8px; padding: 0 2px; }
.sec-title { margin: 0; color: var(--m-ink); font-family: var(--m-font-display); font-size: 18px; font-weight: 700; line-height: 1.2; }
.sec-link {
  min-height: 32px;
  padding: 0 8px;
  border: 0;
  border-radius: 999px;
  background: transparent;
  color: var(--m-primary-dark);
  cursor: pointer;
  font: inherit;
  font-size: 13px;
  font-weight: 700;
}
.plist { display: grid; flex: 1; min-height: 0; grid-template-columns: repeat(2, minmax(0, 1fr)); grid-template-rows: minmax(0, 1fr); gap: 10px; }

.locked {
  display: flex;
  align-items: center;
  gap: 14px;
  min-height: 76px;
  padding: 0 18px;
  border: 1.5px dashed var(--m-border);
  border-radius: 20px;
}
.locked-icon { display: grid; flex: 0 0 40px; width: 40px; height: 40px; place-items: center; border-radius: 999px; background: var(--m-bg); color: var(--m-muted); }
.locked-text { display: flex; flex-direction: column; }
.locked-title { color: var(--m-ink); font-size: 15px; font-weight: 600; }
.locked-sub { color: var(--m-muted); font-size: 12.5px; }
</style>
