<template>
  <q-page class="bg-grey-1 q-pb-md">
    <div class="q-pa-md">
      <div class="row q-col-gutter-sm q-mb-md">
        <div class="col">
          <q-input v-model="searchQuery" outlined dense placeholder="Search rooms, barangay, type..." bg-color="white" class="rounded-input" />
        </div>
      </div>

      <template v-if="loading">
        <q-skeleton height="200px" square class="q-mb-md" style="border-radius:16px" />
        <q-skeleton height="200px" square class="q-mb-md" style="border-radius:16px" />
      </template>

      <template v-else-if="error">
        <div class="text-negative text-center q-py-xl">{{ error }}</div>
      </template>

      <template v-else>
        <div class="text-h6 text-weight-bold q-mb-md">Available Rooms <span class="text-teal-8">({{ rooms.length }})</span></div>

        <div v-if="rooms.length === 0" class="text-center text-grey-6 q-py-xl">
          No available rooms right now. Check back later.
        </div>

        <q-card v-for="room in rooms" :key="room.id" flat bordered class="q-mb-md custom-card overflow-hidden">
          <div class="row items-center q-pa-sm" style="background:#f0fdfa;">
            <q-icon name="bed" color="teal-8" size="20px" class="q-mr-sm" />
            <span class="text-weight-bold text-teal-9">{{ room.roomNumber }}</span>
            <q-space />
            <span class="text-caption text-grey-6">{{ formatPeso(room.rent) }}/mo</span>
          </div>
          <q-card-section>
            <div class="text-subtitle1 text-weight-bold">{{ room.propertyName }}</div>
            <div class="text-caption text-grey-7 q-mt-xs row items-center">
              <q-icon name="place" class="q-mr-xs" /> {{ room.address }}
            </div>
            <div class="row q-gutter-xs q-mt-md q-mb-sm">
              <q-chip dense outline color="teal-5" icon="meeting_room" size="sm">{{ room.type }}</q-chip>
              <q-chip v-if="room.floor" dense outline color="blue-5" icon="stairs" size="sm">Floor {{ room.floor }}</q-chip>
              <q-chip dense outline color="green-5" icon="check_circle" size="sm">{{ room.status }}</q-chip>
            </div>
            <q-btn unelevated color="dark" label="View Details" class="rounded-borders text-caption text-weight-bold full-width" no-caps />
          </q-card-section>
        </q-card>
      </template>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue';
import { supabase } from '@/shared/utils/supabase';

interface DiscoverRoom {
  id: string;
  roomNumber: string;
  propertyName: string;
  address: string;
  type: string;
  floor: string | null;
  status: string;
  rent: number;
}

const searchQuery = ref('');
const loading = ref(true);
const error = ref<string | null>(null);
const rooms = ref<DiscoverRoom[]>([]);

const filteredRooms = computed(() => {
  const q = searchQuery.value.trim().toLowerCase();
  if (!q) return rooms.value;
  return rooms.value.filter((r) =>
    r.propertyName.toLowerCase().includes(q) ||
    r.address.toLowerCase().includes(q) ||
    r.roomNumber.toLowerCase().includes(q)
  );
});

function formatPeso(amount: number): string {
  return '\u20B1' + amount.toLocaleString('en-PH', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
}

async function loadRooms() {
  loading.value = true;
  error.value = null;
  try {
    const { data, error: queryError } = await supabase
      .from('rooms')
      .select('id, room_number, floor, status, monthly_rent, property:properties(name, address, room_type, monthly_rent)')
      .eq('status', 'available');

    if (queryError) throw queryError;

    const rows = (data ?? []) as unknown as Array<{
      id: string;
      room_number: string | null;
      floor: string | null;
      status: string | null;
      monthly_rent: number | null;
      property: { name: string | null; address: string | null; room_type: string | null; monthly_rent: number | null } | null;
    }>;

    rooms.value = rows.map((r) => ({
      id: r.id,
      roomNumber: r.room_number ?? 'Room',
      propertyName: r.property?.name ?? 'Boarding House',
      address: r.property?.address ?? '—',
      type: r.property?.room_type ?? 'room',
      floor: r.floor ?? null,
      status: r.status ?? 'available',
      rent: r.monthly_rent ?? r.property?.monthly_rent ?? 0,
    }));
  } catch (e) {
    error.value = e instanceof Error ? e.message : 'Failed to load rooms';
  } finally {
    loading.value = false;
  }
}

onMounted(loadRooms);
</script>

<style scoped>
.custom-card {
  border-radius: 16px;
  background: white;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.04);
}
.rounded-input :deep(.q-field__control) {
  border-radius: 12px;
}
</style>
