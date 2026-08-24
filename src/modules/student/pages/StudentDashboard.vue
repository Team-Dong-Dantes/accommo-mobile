<template>
  <q-page class="bg-grey-1 q-pb-xl">
    <template v-if="loading">
      <div class="q-pa-md">
        <q-skeleton height="240px" square class="q-mb-md border-radius-24" />
        <div class="row q-col-gutter-md">
          <div class="col-6"><q-skeleton height="160px" square class="border-radius-20" /></div>
          <div class="col-6"><q-skeleton height="160px" square class="border-radius-20" /></div>
        </div>
      </div>
    </template>

    <template v-else>
      <div class="row items-center justify-between q-px-md q-pt-md q-pb-sm">
        <div class="row items-center">
          <q-avatar size="48px" color="teal-8" text-color="white" class="text-weight-bold q-mr-sm">
            {{ userInitials }}
          </q-avatar>
          <div>
            <div class="text-caption text-grey-7" style="line-height: 1">Good evening</div>
            <div class="text-h6 text-weight-bold" style="line-height: 1.2">{{ userName }}</div>
          </div>
        </div>
      </div>

      <q-card flat class="q-mx-md q-mb-md custom-card border-radius-24 overflow-hidden">
        <q-img src="https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?w=600&h=300&fit=crop" height="200px">
          <div class="absolute-top-left bg-transparent q-pa-sm">
            <q-chip color="teal-7" text-color="white" size="sm" class="text-weight-bold" icon="verified">
              OSAS VERIFIED
            </q-chip>
          </div>
          <div class="absolute-top-right bg-transparent q-pa-sm">
            <div class="bg-black text-white text-caption text-weight-bold q-px-sm q-py-xs border-radius-12 opacity-8">
              {{ paymentTitle }}/mo
            </div>
          </div>
          <div class="absolute-bottom bg-transparent column justify-end" style="background: linear-gradient(180deg, rgba(0,0,0,0) 0%, rgba(0,0,0,0.8) 100%);">
            <div class="text-white text-h6 text-weight-bold line-height-tight">{{ stayTitle }}</div>
            <div class="text-white text-caption row items-center q-mt-xs opacity-8">
              <q-icon name="location_on" size="14px" class="q-mr-xs" />
              {{ propertyName || 'Location unavailable' }}
            </div>
            <div class="row q-gutter-xs q-mt-sm">
              <div class="amenity-chip"><q-icon name="wifi" class="q-mr-xs"/> WIFI</div>
              <div class="amenity-chip"><q-icon name="water_drop" class="q-mr-xs"/> Water</div>
              <div class="amenity-chip"><q-icon name="bolt" class="q-mr-xs"/> Elec</div>
              <div class="amenity-chip"><q-icon name="ac_unit" class="q-mr-xs"/> Aircon</div>
            </div>
          </div>
        </q-img>

        <q-card-section class="q-pa-md bg-white">
          <div class="row justify-between text-caption text-grey-8 q-mb-sm text-weight-medium">
            <div class="row items-center">
              <q-icon name="calendar_today" size="16px" class="q-mr-xs text-grey-5" />
              {{ leaseDateRange || 'No dates' }}
            </div>
            <div class="text-teal-7 row items-center">
              <q-icon name="schedule" size="16px" class="q-mr-xs" />
              {{ daysLeftLabel || '—' }}
            </div>
          </div>
          <q-linear-progress :value="leaseProgress" color="teal-6" track-color="grey-3" rounded size="6px" class="q-my-sm" />
          <div class="text-caption text-grey-6 q-mb-md">{{ leaseProgressPercent }}% of lease elapsed</div>

          <q-btn outline color="negative" class="full-width border-radius-12 text-weight-bold" no-caps flat style="background: #FFF1F1">
            <q-icon name="logout" size="18px" class="q-mr-sm" />
            Request to Leave
          </q-btn>
        </q-card-section>
      </q-card>

      <div class="row q-col-gutter-md q-px-md q-mb-md">
        <div class="col-6">
          <q-card flat bordered class="custom-card border-radius-20 h-full flex column justify-between">
            <q-card-section class="q-pa-md">
              <div class="text-overline text-grey-5 letter-spacing-1">PROPERTY OWNER</div>
              <div class="row items-center q-mt-xs q-mb-md">
                <q-avatar size="36px" color="teal-8" text-color="white" class="text-weight-bold">{{ landlordInitials }}</q-avatar>
                <div class="q-ml-sm col">
                  <div class="text-subtitle2 text-weight-bold line-height-tight">{{ landlordName || 'Property Owner' }}</div>
                  <div class="text-caption text-grey-6 text-ellipsis">{{ propertyName || 'Property' }}</div>
                </div>
              </div>
              <q-btn unelevated color="dark" class="full-width border-radius-12 text-weight-bold" no-caps @click="goToMessages">
                <q-icon name="chat_bubble_outline" size="16px" class="q-mr-sm" />
                Message
              </q-btn>
            </q-card-section>
          </q-card>
        </div>

        <div class="col-6">
          <q-card flat bordered class="custom-card border-radius-20 h-full">
            <q-card-section class="q-pa-md">
              <div class="row justify-between items-center">
                <div class="text-overline text-grey-5 letter-spacing-1">{{ roommateRoom || 'ROOM' }}</div>
                <div class="bg-teal-1 text-teal-8 text-caption text-weight-bold round-badge">{{ roommateCount }}</div>
              </div>

              <div class="column q-gutter-y-sm q-mt-sm">
                <div class="row items-center">
                  <q-avatar size="32px" color="teal-8" text-color="white" class="text-weight-bold">{{ userInitials }}</q-avatar>
                  <div class="q-ml-sm col">
                    <div class="text-caption text-weight-bold line-height-tight">{{ userName }}</div>
                    <div class="text-xs text-grey-6">You</div>
                  </div>
                </div>
                <div v-if="roommateName" class="row items-center">
                  <q-avatar size="32px" color="purple-5" text-color="white" class="text-weight-bold">{{ roommateInitials }}</q-avatar>
                  <div class="q-ml-sm col">
                    <div class="text-caption text-weight-bold line-height-tight">{{ roommateName }}</div>
                    <div class="text-xs text-grey-6">Roommate</div>
                  </div>
                </div>
              </div>
            </q-card-section>
          </q-card>
        </div>
      </div>

      <q-card flat class="q-mx-md q-mb-md custom-card border-radius-20" style="background: #FFF9E6; border: 1px solid #FFE4A0;">
        <q-card-section class="q-pa-md row items-center">
          <div class="bg-white q-pa-xs border-radius-8 border-orange">
            <q-icon name="warning_amber" color="orange-9" size="24px" />
          </div>
          <div class="q-ml-sm col">
            <div class="text-subtitle2 text-weight-bold text-dark">{{ rentDueTitle || 'No pending rent' }}</div>
            <div class="text-caption text-orange-9 text-weight-medium">{{ rentDueSubtitle }}</div>
          </div>
          <q-btn unelevated color="orange-8" label="Pay Now" icon-right="arrow_forward" class="border-radius-12 text-weight-bold q-px-sm" size="sm" no-caps @click="goToPayments" />
        </q-card-section>
      </q-card>

      <q-card flat bordered class="q-mx-md q-mb-xl custom-card border-radius-20">
        <q-card-section class="q-pa-md">
          <div class="row items-center justify-between">
            <div class="row items-center">
              <div class="bg-yellow-1 q-pa-sm border-radius-8 q-mr-sm">
                <q-icon name="star_outline" color="orange-8" size="20px" />
              </div>
              <div>
                <div class="text-subtitle2 text-weight-bold">Rate &amp; Review</div>
                <div class="text-caption text-grey-6">{{ reviewUnlockText }}</div>
              </div>
            </div>
            <q-icon name="lock_outline" color="grey-5" size="20px" />
          </div>
          <q-linear-progress :value="reviewProgress" color="grey-4" track-color="grey-2" rounded size="6px" class="q-mt-md q-mb-xs" />
          <div class="text-xs text-grey-5">{{ reviewMonthsText }}</div>
        </q-card-section>
      </q-card>

      <q-page-sticky position="bottom-right" :offset="[16, 16]">
        <q-btn fab icon="add" color="teal-7" class="shadow-4" />
      </q-page-sticky>

      <div v-if="error" class="text-negative text-center q-px-md">{{ error }}</div>
    </template>
  </q-page>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { supabase } from '@/shared/utils/supabase'

interface LeaseRow {
  id: string
  status: string
  start_date: string | null
  end_date: string | null
  monthly_rent: number | null
  room_id: string | null
  landlord_id: string | null
  room: {
    room_number: string | null
    property: { name: string | null; address: string | null; business_name: string | null } | null
  } | null
}

interface PaymentRow {
  amount: number
  status: string
  month: string | null
  description: string | null
}

const router = useRouter()

const loading = ref(true)
const error = ref<string | null>(null)
const lease = ref<LeaseRow | null>(null)
const nextPayment = ref<PaymentRow | null>(null)

const userName = ref('')
const userInitials = ref('')
const landlordName = ref('')
const landlordId = ref<string | null>(null)
const propertyName = ref('')
const roommateName = ref<string | null>(null)
const roommateRoom = ref('')
const roommateCount = ref(1)

const stayTitle = ref('No Active Lease')
const staySubtitle = ref('You are not checked in yet.')
const paymentTitle = ref('\u20B10.00')
const paymentSubtitle = ref('No pending balances')

// Derived display labels (replace the previous hardcoded mock text)
const leaseDateRange = ref('')
const daysLeftLabel = ref('')
const rentDueTitle = ref('')
const rentDueSubtitle = ref('')
const reviewUnlockText = ref('')
const reviewProgress = ref(0)
const reviewMonthsText = ref('')

function initialsOf(name: string): string {
  const parts = name.trim().split(/\s+/).filter(Boolean)
  if (parts.length === 0) return '?'
  if (parts.length === 1) return (parts[0] ?? '').slice(0, 2).toUpperCase()
  return ((parts[0]?.[0] ?? '') + (parts[parts.length - 1]?.[0] ?? '')).toUpperCase()
}

const landlordInitials = computed(() =>
  landlordName.value ? initialsOf(landlordName.value) : 'PO'
)

const roommateInitials = computed(() =>
  roommateName.value ? initialsOf(roommateName.value) : '?'
)

const leaseProgress = computed(() => {
  if (!lease.value?.start_date || !lease.value?.end_date) return 0
  const start = new Date(lease.value.start_date).getTime()
  const end = new Date(lease.value.end_date).getTime()
  const now = Date.now()
  if (now <= start) return 0
  if (now >= end) return 1
  return (now - start) / (end - start)
})

const leaseProgressPercent = computed(() => Math.round(leaseProgress.value * 100))

function formatPeso(amount: number): string {
  return '\u20B1' + amount.toLocaleString('en-PH', { minimumFractionDigits: 0, maximumFractionDigits: 0 })
}

function formatMonthYear(dateStr: string | null): string {
  if (!dateStr) return '\u2014'
  return new Date(dateStr).toLocaleDateString('en-PH', { month: 'short', year: 'numeric' })
}

function paymentStatusLabel(status: string): string {
  switch (status) {
    case 'overdue': return 'Overdue'
    case 'pending_verification': return 'Awaiting verification'
    case 'due': return 'Due'
    default: return status
  }
}

// Estimate days until a payment "month" (treated as due on the 1st of that month).
function daysUntilDue(month: string | null): number | null {
  if (!month) return null
  const due = new Date(month + '-01T00:00:00')
  if (isNaN(due.getTime())) return null
  return Math.ceil((due.getTime() - Date.now()) / 86400000)
}

async function loadDashboard() {
  loading.value = true
  error.value = null
  try {
    const { data: { user } } = await supabase.auth.getUser()
    if (!user) { void router.push('/login'); return }

    // Current user's display name
    const { data: me } = await supabase
      .from('users').select('full_name').eq('id', user.id).maybeSingle()
    const myName = (me as unknown as { full_name: string | null } | null)?.full_name
    const fallbackName = user.email ? (user.email.split('@')[0] ?? 'Student') : 'Student'
    userName.value = myName ?? fallbackName
    userInitials.value = initialsOf(userName.value)

    const { data: leaseData, error: leaseError } = await supabase
      .from('leases')
      .select('id, status, start_date, end_date, monthly_rent, landlord_id, room_id, room:rooms(room_number, property:properties(name, business_name))')
      .eq('student_id', user.id).eq('status', 'active').maybeSingle()

    if (leaseError) throw leaseError

    if (leaseData) {
      lease.value = leaseData as unknown as LeaseRow
      const prop = lease.value.room?.property
      const roomNum = lease.value.room?.room_number
      stayTitle.value = prop?.name ? `${prop.name}${roomNum ? ' \u00B7 Rm ' + roomNum : ''}` : 'Active Lease'
      propertyName.value = prop?.name ?? ''
      roommateRoom.value = roomNum ? `ROOM ${roomNum}` : 'ROOM'
      const rent = lease.value.monthly_rent ?? 3500
      paymentTitle.value = formatPeso(rent)
      staySubtitle.value = rent > 0 ? `Monthly rent ${formatPeso(rent)}` : 'Active lease \u2014 no rent set'

      // Lease date range + days left
      if (lease.value.start_date && lease.value.end_date) {
        leaseDateRange.value = `${formatMonthYear(lease.value.start_date)} \u2013 ${formatMonthYear(lease.value.end_date)}`
        const daysLeft = Math.ceil((new Date(lease.value.end_date).getTime() - Date.now()) / 86400000)
        daysLeftLabel.value = daysLeft > 0 ? `${daysLeft} days left` : 'Lease ended'
      } else {
        leaseDateRange.value = ''
        daysLeftLabel.value = ''
      }

      // Review unlock progress (unlocks after 6 months of tenancy)
      if (lease.value.start_date) {
        const monthsElapsed = (Date.now() - new Date(lease.value.start_date).getTime()) / (30 * 86400000)
        if (monthsElapsed >= 6) {
          reviewUnlockText.value = 'You can now rate & review'
          reviewProgress.value = 1
          reviewMonthsText.value = 'Helps OSAS monitor property standards'
        } else {
          const left = Math.max(0, Math.ceil(6 - monthsElapsed))
          reviewUnlockText.value = `Unlocks after 6 months \u00b7 ${left} month${left === 1 ? '' : 's'} left`
          reviewProgress.value = Math.min(1, monthsElapsed / 6)
          reviewMonthsText.value = `${Math.floor(monthsElapsed)} of 6 months \u00b7 Helps OSAS monitor property standards`
        }
      }

      const lid = lease.value.landlord_id
      landlordId.value = lid ?? null
      if (lid) {
        // Prefer the property's business_name (consistent with Discover); fall back to users.full_name.
        const { data: landlord } = await supabase
          .from('users').select('full_name').eq('id', lid).maybeSingle()
        const userName = (landlord as unknown as { full_name: string | null } | null)?.full_name ?? null
        landlordName.value = (prop?.business_name ?? userName) ?? ''
      }

      const roomId = lease.value.room_id
      if (roomId) {
        const { data: roomLeases } = await supabase
          .from('leases')
          .select('student_id')
          .eq('room_id', roomId)
          .eq('status', 'active')

        const others = (roomLeases ?? [])
          .map((l) => (l as { student_id: string }).student_id)
          .filter((id) => id !== user.id)

        roommateCount.value = others.length + 1
        if (others.length > 0 && others[0]) {
          const { data: roommate } = await supabase
            .from('users').select('full_name').eq('id', others[0]).maybeSingle()
          roommateName.value = (roommate as unknown as { full_name: string | null } | null)?.full_name ?? null
        } else {
          roommateName.value = null
        }
      }
    }

    if (lease.value?.id) {
      const { data: paymentData } = await supabase
        .from('payments')
        .select('amount, status, month, description')
        .eq('lease_id', lease.value.id)
        .in('status', ['due', 'overdue', 'pending_verification'])
        .order('month', { ascending: true }).maybeSingle()

      if (paymentData) {
        nextPayment.value = paymentData as unknown as PaymentRow
        paymentTitle.value = formatPeso(nextPayment.value.amount)
        paymentSubtitle.value = [
          paymentStatusLabel(nextPayment.value.status),
          nextPayment.value.month ? formatMonthYear(nextPayment.value.month) : null,
          nextPayment.value.description,
        ].filter((s): s is string => s != null).join(' \u00B7 ')

        const due = daysUntilDue(nextPayment.value.month)
        if (due !== null) {
          if (due < 0) rentDueTitle.value = 'Rent overdue'
          else if (due === 0) rentDueTitle.value = 'Rent due today'
          else rentDueTitle.value = `Rent due in ${due} day${due === 1 ? '' : 's'}`
        } else {
          rentDueTitle.value = paymentStatusLabel(nextPayment.value.status)
        }
        rentDueSubtitle.value = [
          formatPeso(nextPayment.value.amount),
          nextPayment.value.month ? formatMonthYear(nextPayment.value.month) : null,
        ].filter((s): s is string => s != null).join(' \u00B7 ')
      }
    }
  } catch (e) {
    error.value = e instanceof Error ? e.message : 'Failed to load dashboard'
  } finally {
    loading.value = false
  }
}

function goToPayments() { void router.push('/student/payments') }
function goToMessages() {
  const query = landlordId.value ? { landlord: landlordId.value } : {}
  void router.push({ path: '/student/messages', query })
}

onMounted(loadDashboard)
</script>

<style scoped>
.custom-card {
  background: white;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.03);
  border-color: rgba(0,0,0,0.05);
}

.border-radius-24 { border-radius: 24px; }
.border-radius-20 { border-radius: 20px; }
.border-radius-12 { border-radius: 12px; }
.border-radius-8 { border-radius: 8px; }

.opacity-8 { opacity: 0.8; }
.line-height-tight { line-height: 1.2; }
.letter-spacing-1 { letter-spacing: 1px; }

.h-full { height: 100%; }

.amenity-chip {
  background: rgba(255, 255, 255, 0.2);
  backdrop-filter: blur(4px);
  color: white;
  font-size: 11px;
  font-weight: 600;
  padding: 4px 8px;
  border-radius: 8px;
  display: flex;
  align-items: center;
}

.round-badge {
  width: 20px;
  height: 20px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
}

.text-xs { font-size: 11px; }
.text-ellipsis {
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.border-orange {
  border: 1px solid #FFE4A0;
}
</style>
