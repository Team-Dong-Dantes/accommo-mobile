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

      <template v-else-if="!lease">
        <q-card flat bordered class="custom-card q-mb-md">
          <q-card-section class="text-center q-py-xl">
            <q-icon name="bed" size="64px" color="teal-8" />
            <div class="text-h6 text-weight-bold q-mt-md">No active stay</div>
            <div class="text-grey-6 q-mt-sm">
              You don't have an active lease yet. Browse rooms to get started.
            </div>
          </q-card-section>
        </q-card>
      </template>

      <template v-else>
        <!-- Property header -->
        <q-card flat bordered class="custom-card q-mb-md overflow-hidden">
          <q-img :src="lease.image" height="160px">
            <div class="absolute-bottom bg-transparent q-pa-sm" style="background: linear-gradient(180deg, transparent, rgba(0,0,0,0.7));">
              <div class="text-h6 text-weight-bold text-white">{{ lease.propertyName }}</div>
              <div class="text-caption text-white row items-center">
                <q-icon name="place" size="14px" class="q-mr-xs" /> {{ lease.address }}
              </div>
            </div>
          </q-img>
        </q-card>

        <!-- Key details -->
        <q-card flat bordered class="custom-card q-mb-md">
          <q-card-section>
            <div class="text-subtitle1 text-weight-bold q-mb-sm">Lease Details</div>
            <q-list dense separator>
              <q-item><q-item-section>Room Unit</q-item-section><q-item-section side class="text-weight-bold">{{ lease.roomUnit }}</q-item-section></q-item>
              <q-item><q-item-section>Monthly Rent</q-item-section><q-item-section side class="text-weight-bold">{{ lease.rent }}</q-item-section></q-item>
              <q-item><q-item-section>Advance Paid</q-item-section><q-item-section side class="text-weight-bold">{{ lease.advance }}</q-item-section></q-item>
              <q-item><q-item-section>Deposit Paid</q-item-section><q-item-section side class="text-weight-bold">{{ lease.deposit }}</q-item-section></q-item>
              <q-item><q-item-section>Lease Period</q-item-section><q-item-section side class="text-weight-medium">{{ lease.period }}</q-item-section></q-item>
              <q-item><q-item-section>Status</q-item-section><q-item-section side><q-badge :color="lease.statusColor" :label="lease.status" class="q-px-sm" /></q-item-section></q-item>
            </q-list>
          </q-card-section>
        </q-card>

        <!-- Landlord -->
        <q-card flat bordered class="custom-card q-mb-md cursor-pointer" @click="messageLandlord">
          <q-card-section class="row items-center">
            <q-avatar size="44px" color="teal-8" text-color="white" class="text-weight-bold">{{ lease.landlordInitials }}</q-avatar>
            <div class="q-ml-md col">
              <div class="text-subtitle2 text-weight-bold">{{ lease.landlordName }}</div>
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
      </template>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue';
import { useRouter } from 'vue-router';
import { supabase } from '@/shared/utils/supabase';
import { LEASE_STATUS, statusText, statusColor, formatPeso, initialsOf } from '@/shared/utils/format';

interface StayLease {
  propertyName: string;
  address: string;
  roomUnit: string;
  rent: string;
  advance: string;
  deposit: string;
  period: string;
  status: string;
  statusColor: string;
  landlordName: string;
  landlordInitials: string;
  landlordId: string | null;
  image: string;
}

const router = useRouter();
const loading = ref(true);
const error = ref<string | null>(null);
const lease = ref<StayLease | null>(null);

async function loadStay() {
  loading.value = true;
  error.value = null;
  try {
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) { void router.push('/login'); return; }

    const { data, error: qErr } = await supabase
      .from('leases')
      .select('id, status, start_date, end_date, monthly_rent, advance_paid, deposit_paid, landlord_id, room:rooms(room_number, property:properties(name, address, landlord_id, business_name))')
      .eq('student_id', user.id)
      .eq('status', 'active')
      .maybeSingle();

    if (qErr) throw qErr;
    if (!data) { lease.value = null; return; }

    const row = data as unknown as {
      id: string; status: string; start_date: string | null; end_date: string | null;
      monthly_rent: number | null; advance_paid: number | null; deposit_paid: number | null;
      landlord_id: string | null;
      room: { room_number: string | null; property: { name: string | null; address: string | null; landlord_id: string | null; business_name: string | null } | null } | null;
    };

    const landlordId = row.landlord_id ?? row.room?.property?.landlord_id ?? null;
    const propBiz = row.room?.property?.business_name ?? null;
    let landlordName = 'Landlord';
    if (landlordId) {
      const { data: u } = await supabase.from('users').select('full_name').eq('id', landlordId).maybeSingle();
      const full = (u as { full_name: string | null } | null)?.full_name;
      landlordName = propBiz || full || 'Landlord';
    }

    const startStr = row.start_date ? new Date(row.start_date).toLocaleDateString('en-PH', { month: 'short', year: 'numeric' }) : '—';
    const endStr = row.end_date ? new Date(row.end_date).toLocaleDateString('en-PH', { month: 'short', year: 'numeric' }) : '—';


    lease.value = {
      propertyName: row.room?.property?.name ?? 'Boarding House',
      address: row.room?.property?.address ?? '—',
      roomUnit: row.room?.room_number ? `Room ${row.room.room_number}` : '—',
      rent: formatPeso(row.monthly_rent ?? 0),
      advance: formatPeso(row.advance_paid ?? 0),
      deposit: formatPeso(row.deposit_paid ?? 0),
      period: `${startStr} – ${endStr}`,
      status: statusText(LEASE_STATUS, row.status),
      statusColor: statusColor(LEASE_STATUS, row.status),
      landlordName,
      landlordInitials: initialsOf(landlordName),
      landlordId,
      image: 'https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?w=600&h=300&fit=crop',
    };
  } catch (e) {
    error.value = e instanceof Error ? e.message : 'Failed to load stay';
  } finally {
    loading.value = false;
  }
}

function messageLandlord() {
  if (lease.value?.landlordId) {
    void router.push({ path: '/student/messages', query: { landlord: lease.value.landlordId } });
  }
}
function goConcerns() { void router.push('/student/concerns'); }
function goPayments() { void router.push('/student/payments'); }

onMounted(loadStay);
</script>

<style scoped>
.custom-card {
  border-radius: 16px;
  background: white;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.04);
}
</style>
