<template>
  <q-page class="dashboard-page bg-grey-1">
    <div class="header-section text-white">
      <div class="row justify-between items-center q-pa-md">
        <div>
          <h4 class="q-my-none text-weight-bold">My Tenants</h4>
          <p class="text-subtitle1 text-white-7 q-mb-none">
            Active tenants across your properties
          </p>
        </div>
        <q-btn flat round dense icon="logout" @click="handleLogout" />
      </div>
    </div>

    <div class="content-section q-pa-md">
      <q-list
        v-if="tenants.length > 0"
        bordered
        separator
        class="rounded-borders bg-white"
      >
        <q-item v-for="tenant in tenants" :key="tenant.lease_id">
          <q-item-section>
            <q-item-label class="text-weight-bold">
              {{ tenant.student_full_name }}
            </q-item-label>
            <q-item-label caption>
              {{ tenant.room_number }} · {{ tenant.property_name }}
            </q-item-label>
          </q-item-section>
          <q-item-section side>
            <q-badge color="teal" label="Active" />
          </q-item-section>
        </q-item>
      </q-list>

      <q-card v-if="tenants.length === 0" flat bordered class="custom-card q-mt-sm">
        <q-card-section class="text-center">
          <div class="text-subtitle2 text-grey-7 q-py-md">
            No active tenants yet — add a property and assign a room to get started.
          </div>
        </q-card-section>
      </q-card>

      <div v-if="error" class="text-negative q-mt-md">{{ error }}</div>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { ref, onMounted, useRouter } from 'vue';
import { supabase } from '@/shared/utils/supabase';
import { useAuthStore } from '@/stores/auth';
import { showToast } from '@/boot/notify';

// Check demo mode
const isDemo = (import.meta.env.VITE_DEMO_MODE as unknown) === 'true';

interface TenantRow {
  lease_id: string;
  student_full_name: string;
  room_number: string | null;
  property_name: string | null;
  start_date: string;
}

const error = ref<string | null>(null);

async function loadTenants() {
  error.value = null;
  try {
    // In demo mode, show placeholder data
    if (isDemo) {
      tenants.value = [];
      showToast('Demo Mode', 'Connect to real Supabase for tenant data', 'info');
      return;
    }

    const {
      data: { user },
      error: userError,
    } = await supabase.auth.getUser();

    if (!user) return;

    // Business name from accreditation profile
    const { data: landlordProfile, error: profileError } = await supabase
      .from('landlord_profiles')
      .select('business_name')
      .eq('user_id', user.id)
      .maybeSingle();

    if (profileError) throw profileError;

    // Active leases with student, room, and property details
    const { data: leases, error: leasesError } = await supabase
      .from('leases')
      .select(
        'id, start_date, status, room:rooms(room_number, property:properties(name)), student_id:student_id:users(full_name)',
      )
      .eq('landlord_id', user.id)
      .eq('status', 'active');

    if (leasesError) throw leasesError;

    const typedLeases = leases ?? [];
    tenants.value = typedLeases.map((lease) => {
      const typedLease = lease as unknown as {
        id: string;
        start_date: string;
        status: string;
        room: { room_number: string | null; property: { name: string | null } } | null;
        student_id: { full_name: string } | null;
      };

      return {
        lease_id: typedLease.id,
        student_full_name: typedLease.student_id?.full_name ?? 'Unknown Student',
        room_number: typedLease.room?.room_number ?? '—',
        property_name: typedLease.room?.property?.name ?? 'Unassigned',
        start_date: typedLease.start_date,
      } as TenantRow;
    });
  } catch (e) {
    error.value = e instanceof Error ? e.message : 'Failed to load tenants';
    console.error('loadTenants error:', e);
  }
}

const tenants = ref<TenantRow[]>([]);

if (isDemo) {
  showToast('Demo Mode', 'Connect to real Supabase for tenant data', 'info');
  onMounted(() => {});
} else {
  onMounted(loadTenants);
}

function handleLogout() {
  useAuthStore().clearCachedRole();
  supabase.auth.signOut();
}
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
</style>