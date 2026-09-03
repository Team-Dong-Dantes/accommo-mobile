<template>
  <q-page class="bg-grey-1 q-pb-md">
    <div class="q-pa-md">
      <template v-if="loading">
        <q-skeleton height="120px" square class="q-mb-md" style="border-radius:16px" />
        <q-skeleton height="200px" square style="border-radius:16px" />
      </template>
      <template v-else-if="error">
        <div class="text-negative text-center q-py-xl">{{ error }}</div>
      </template>
      <!-- No active stay: student has not been accepted into a room yet -->
      <template v-else-if="!lease">
        <div class="column items-center justify-center q-py-xl text-center">
          <q-icon name="night_shelter" size="56px" class="text-grey-5 q-mb-md" />
          <div class="text-subtitle1 text-weight-bold">No active stay yet</div>
          <div class="text-body2 text-grey-6 q-mt-xs q-mb-lg">
            Once a manager accepts your application, your room details show up here.
          </div>
          <q-btn unelevated no-caps color="teal-8" label="Find a room" to="/student/discover" />
        </div>
      </template>
      <template v-else>
        <!-- Property hero: CSS gradient (no external image — the old Unsplash
             URL was blocked by the app's img-src Content-Security-Policy). -->
        <section class="stay-hero q-mb-md">
          <div class="stay-hero__top">
            <span class="stay-hero__badge" :class="`stay-hero__badge--${lease?.rawStatus}`">
              <q-icon name="circle" size="8px" class="q-mr-xs" />{{ lease?.status }}
            </span>
          </div>
          <h2 class="stay-hero__name">{{ lease?.propertyName }}</h2>
          <p class="stay-hero__addr">
            <q-icon name="place" size="14px" class="q-mr-xs" />{{ lease?.address }}
          </p>
          <div class="stay-hero__room">
            <q-icon name="meeting_room" size="16px" class="q-mr-xs" />{{ lease?.roomUnit }}
          </div>
        </section>

        <!-- Money at a glance -->
        <div class="stay-kpis q-mb-md">
          <div class="stay-kpi">
            <span class="stay-kpi__label">Monthly rent</span>
            <strong class="stay-kpi__value">{{ lease?.rent }}</strong>
          </div>
          <div class="stay-kpi">
            <span class="stay-kpi__label">Advance</span>
            <strong class="stay-kpi__value">{{ lease?.advance }}</strong>
          </div>
          <div class="stay-kpi">
            <span class="stay-kpi__label">Deposit</span>
            <strong class="stay-kpi__value">{{ lease?.deposit }}</strong>
          </div>
        </div>

        <!-- Key details -->
        <q-card flat bordered class="custom-card q-mb-md">
          <q-card-section>
            <div class="text-subtitle1 text-weight-bold q-mb-sm">Lease Details</div>
            <q-list dense separator>
              <q-item><q-item-section>Room Unit</q-item-section><q-item-section side class="text-weight-bold">{{ lease?.roomUnit }}</q-item-section></q-item>
              <q-item><q-item-section>Lease Period</q-item-section><q-item-section side class="text-weight-bold">{{ lease?.period }}</q-item-section></q-item>
              <q-item><q-item-section>Status</q-item-section><q-item-section side><q-badge :color="lease?.statusColor" :label="lease?.status" class="q-px-sm" /></q-item-section></q-item>
            </q-list>
          </q-card-section>
        </q-card>

        <!-- Landlord -->
        <q-card flat bordered class="custom-card q-mb-md cursor-pointer" @click="messageLandlord">
          <q-card-section class="row items-center">
            <q-avatar size="44px" color="teal-8" text-color="white" class="text-weight-bold">{{ lease?.landlordInitials }}</q-avatar>
            <div class="q-ml-md col">
              <div class="text-subtitle2 text-weight-bold">{{ lease?.landlordName }}</div>
              <div class="text-caption text-grey-6">Your landlord</div>
            </div>
            <q-btn flat color="teal-8" icon="forum" label="Message" no-caps dense class="text-weight-bold" />
          </q-card-section>
        </q-card>

        <div class="row q-col-gutter-sm">
          <div class="col-6">
            <q-btn outline color="teal-8" icon="report_problem" label="Concerns" class="full-width rounded-borders text-weight-bold" no-caps @click="goConcerns" />
          </div>
          <div class="col-6">
            <q-btn unelevated color="teal-8" icon="payments" label="Payments" class="full-width rounded-borders text-weight-bold" no-caps @click="goPayments" />
          </div>
        </div>

        <q-btn flat color="red-6" icon="logout" label="Request to leave" no-caps class="q-mt-md text-weight-bold full-width" @click="leaveDialog = true" />
      </template>
    </div>

    <q-dialog v-model="leaveDialog">
      <q-card class="rounded-borders" style="min-width:300px; max-width:90vw">
        <q-card-section>
          <div class="text-subtitle1 text-weight-bold">Request to leave?</div>
          <div class="text-grey-7 q-mt-xs">Your landlord will be notified. Your stay stays active until they confirm your request.</div>
        </q-card-section>
        <q-card-actions align="right">
          <q-btn flat label="Cancel" v-close-popup />
          <q-btn unelevated color="red-6" label="Request leave" :loading="leaving" @click="requestLeave" />
        </q-card-actions>
      </q-card>
    </q-dialog>
  </q-page>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue';
import { useRouter } from 'vue-router';
import { useQuasar } from 'quasar';
import { supabase } from '@/shared/utils/supabase';
import { createNotification } from '@/boot/notify';
import { LEASE_STATUS, statusText, statusColor, formatPeso, initialsOf } from '@/shared/utils/format';

interface StayLease {
  id: string;
  propertyName: string;
  address: string;
  roomUnit: string;
  rent: string;
  advance: string;
  deposit: string;
  period: string;
  status: string;
  statusColor: string;
  rawStatus: string;
  landlordName: string;
  landlordInitials: string;
  landlordId: string | null;
}

const router = useRouter()
const $q = useQuasar()
const loading = ref(true)
const error = ref<string | null>(null)
const lease = ref<StayLease | null>(null)
const leaveDialog = ref(false)
const leaving = ref(false)

async function loadStay() {
  loading.value = true
  error.value = null
  try {
    const { data: { user } } = await supabase.auth.getUser()
    if (!user) { void router.push('/login'); return }

    // A student should only ever have one current stay, but bad data (duplicate
    // accepted applications) can produce several. `.maybeSingle()` throws
    // PGRST116 on >1 row, which would blank the whole page — so take the most
    // recent current lease instead and render that.
    const { data: rows, error: qErr } = await (supabase as any)
      .from('leases')
      .select('id, status, start_date, end_date, monthly_rent, advance_paid, deposit_paid, accommodation_manager_id, room:rooms(room_number, accommodation:accommodations(name, address, business_name))')
      .eq('student_id', user.id)
      .in('status', ['active', 'leave_requested'])
      .order('start_date', { ascending: false })

    if (qErr) throw qErr
    const data = Array.isArray(rows) && rows.length ? rows[0] : null
    if (!data) { lease.value = null; return }

    const row = data as unknown as {
      id: string; status: string; start_date: string | null; end_date: string | null;
      monthly_rent: number | null; advance_paid: number | null; deposit_paid: number | null;
      accommodation_manager_id: string | null;
      room: { room_number: string | null; accommodation: { name: string | null; address: string | null; business_name: string | null } | null } | null;
    }

    const landlordId = row.accommodation_manager_id ?? null
    const propBiz = row.room?.accommodation?.business_name ?? null
    let landlordName = 'Landlord'
    if (landlordId) {
      const { data: u } = await supabase.from('users').select('full_name').eq('id', landlordId).maybeSingle()
      const full = (u as { full_name: string | null } | null)?.full_name
      landlordName = propBiz || full || 'Landlord'
    }

    const startStr = row.start_date ? new Date(row.start_date).toLocaleDateString('en-PH', { month: 'short', year: 'numeric' }) : '—'
    const endStr = row.end_date ? new Date(row.end_date).toLocaleDateString('en-PH', { month: 'short', year: 'numeric' }) : '—'

    lease.value = {
      id: row.id,
      propertyName: row.room?.accommodation?.name ?? 'Boarding House',
      address: row.room?.accommodation?.address ?? '—',
      roomUnit: row.room?.room_number ? `Room ${row.room.room_number}` : '—',
      rent: formatPeso(row.monthly_rent ?? 0),
      advance: formatPeso(row.advance_paid ?? 0),
      deposit: formatPeso(row.deposit_paid ?? 0),
      period: `${startStr} – ${endStr}`,
      status: statusText(LEASE_STATUS, row.status),
      statusColor: statusColor(LEASE_STATUS, row.status),
      rawStatus: row.status,
      landlordName,
      landlordInitials: initialsOf(landlordName),
      landlordId,
    }
  } catch (e) {
    error.value = e instanceof Error ? e.message : 'Failed to load stay'
  } finally {
    loading.value = false
  }
}

async function requestLeave() {
  if (!lease.value || leaving.value) return
  leaving.value = true
  try {
    const { data: { user } } = await supabase.auth.getUser()
    if (!user) { void router.push('/login'); return }
    const { error } = await (supabase as any)
      .from('leases')
      .update({ status: 'leave_requested', leave_requested_at: new Date().toISOString() })
      .eq('id', lease.value.id)
    if (error) throw error
    if (lease.value.landlordId) {
      try {
        await createNotification(lease.value.landlordId, 'Leave requested', `${lease.value.propertyName || 'Your tenant'} asked to leave (${lease.value.roomUnit}). Review it from Tenants.`, 'leave', '/landlord/tenants')
      } catch { /* non-critical */ }
    }
    leaveDialog.value = false
    await loadStay()
  } catch (e) {
    error.value = e instanceof Error ? e.message : 'Could not request leave'
  } finally {
    leaving.value = false
  }
}

function messageLandlord() {
  if (lease.value?.landlordId) {
    void router.push({ path: '/student/messages', query: { landlord: lease.value.landlordId } })
  }
}

function goConcerns() { void router.push('/student/concerns') }
function goPayments() { void router.push('/student/payments') }

onMounted(loadStay)
</script>

<style scoped>
.custom-card {
  border-radius: 16px;
  background: white;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.04);
}

/* Hero — pure CSS so nothing is fetched (CSP-safe) */
.stay-hero {
  position: relative;
  overflow: hidden;
  border-radius: 18px;
  padding: 20px;
  color: #fff;
  background: linear-gradient(135deg, #0f766e 0%, #14b8a6 55%, #0e7490 100%);
  box-shadow: 0 8px 20px rgba(13, 148, 136, 0.22);
}
/* subtle depth without an image */
.stay-hero::after {
  content: '';
  position: absolute;
  right: -40px;
  top: -60px;
  width: 180px;
  height: 180px;
  border-radius: 50%;
  background: rgba(255, 255, 255, 0.10);
}
.stay-hero__top { display: flex; justify-content: flex-end; }
.stay-hero__badge {
  display: inline-flex;
  align-items: center;
  padding: 4px 10px;
  border-radius: 999px;
  font-size: 11px;
  font-weight: 700;
  background: rgba(255, 255, 255, 0.18);
  backdrop-filter: blur(2px);
}
.stay-hero__badge--leave_requested { background: rgba(251, 191, 36, 0.30); }
.stay-hero__name {
  margin: 6px 0 2px;
  font-size: 21px;
  font-weight: 700;
  line-height: 1.2;
  letter-spacing: -0.02em;
}
.stay-hero__addr {
  margin: 0;
  font-size: 12.5px;
  opacity: 0.9;
  display: flex;
  align-items: center;
}
.stay-hero__room {
  display: inline-flex;
  align-items: center;
  margin-top: 14px;
  padding: 6px 12px;
  border-radius: 10px;
  font-size: 13px;
  font-weight: 600;
  background: rgba(255, 255, 255, 0.16);
}

/* Money at a glance */
.stay-kpis { display: grid; grid-template-columns: repeat(3, 1fr); gap: 8px; }
.stay-kpi {
  background: #fff;
  border: 1px solid rgba(0, 0, 0, 0.06);
  border-radius: 14px;
  padding: 12px 10px;
  text-align: center;
}
.stay-kpi__label {
  display: block;
  font-size: 10.5px;
  color: #6b7280;
  margin-bottom: 4px;
}
.stay-kpi__value { font-size: 14px; font-weight: 700; color: #0f172a; }
</style>