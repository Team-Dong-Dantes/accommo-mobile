<template>
  <q-page class="bg-grey-1 q-pb-md">
    <div class="q-pa-md">
      <div class="row q-col-gutter-sm q-mb-md">
        <div class="col">
          <q-input v-model="searchQuery" outlined dense placeholder="Search rooms, barangay, type..." bg-color="white" class="rounded-input" />
        </div>
        <div class="col-auto">
          <q-btn outline icon="tune" label="Filter" color="grey-8" class="bg-white rounded-borders" no-caps />
        </div>
      </div>

      <div class="text-h6 text-weight-bold q-mb-md">Available Rooms <span class="text-teal-8">({{ rooms.length }})</span></div>

      <q-card v-for="room in rooms" :key="room.id" flat bordered class="q-mb-md custom-card overflow-hidden">
        <q-img :src="room.image" height="180px">
          <div class="absolute-top-left bg-transparent q-pa-sm">
            <q-chip color="white" text-color="orange" dense icon="bed" size="sm" class="text-weight-bold">{{ room.type }}</q-chip>
          </div>
          <div class="absolute-top-right bg-transparent q-pa-sm">
            <q-btn round flat color="white" icon="favorite_border" size="sm" class="bg-white-5" />
          </div>
          <div class="absolute-bottom bg-transparent q-pa-sm row justify-between items-end">
            <div>
              <div class="text-h6 text-weight-bold text-white">{{ room.name }}</div>
              <div class="text-caption text-white">{{ room.property }}</div>
            </div>
            <div class="bg-black text-white q-px-sm q-py-xs text-weight-bold" style="border-radius:8px">{{ formatPeso(room.rent) }}/mo</div>
          </div>
        </q-img>
        <q-card-section>
          <div class="text-caption text-grey-7 q-mb-sm row items-center">
            <q-icon name="place" class="q-mr-xs" /> {{ room.address }}
          </div>
          <div class="row justify-between items-center q-mb-md">
            <div class="row q-gutter-xs">
              <q-chip v-for="amenity in room.amenities" :key="amenity.icon" dense outline :color="amenity.color" :icon="amenity.icon" size="sm">{{ amenity.label }}</q-chip>
            </div>
            <div class="text-caption text-grey-6">{{ room.floor }} · {{ room.slots }} slot{{ room.slots > 1 ? 's' : '' }} left</div>
          </div>
          <div class="row justify-between items-center">
            <div class="row items-center">
              <q-avatar :color="room.landlord.color" text-color="white" size="32px" class="q-mr-sm">{{ room.landlord.initials }}</q-avatar>
              <span class="text-weight-bold text-caption">{{ room.landlord.name }}</span>
            </div>
            <q-btn unelevated color="dark" label="View Details" class="rounded-borders text-caption text-weight-bold" no-caps />
          </div>
        </q-card-section>
      </q-card>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { ref } from 'vue';

interface DiscoverRoom {
  id: number;
  image: string;
  type: string;
  name: string;
  property: string;
  rent: number;
  address: string;
  floor: string;
  slots: number;
  amenities: { icon: string; color: string; label: string }[];
  landlord: { initials: string; name: string; color: string };
}

const searchQuery = ref('');

const rooms: DiscoverRoom[] = [
  {
    id: 1, image: 'https://images.unsplash.com/photo-1560185007-cde436f6a4d0?w=600&h=300&fit=crop',
    type: 'Bedspacer', name: 'Bed 1-A', property: 'Pinzon Student Hub', rent: 1800,
    address: 'Blk 5, Pinzon Subdivision, Echague', floor: 'Floor 1', slots: 1,
    amenities: [
      { icon: 'wifi', color: 'teal-5', label: 'WiFi' },
      { icon: 'water_drop', color: 'blue-5', label: 'Water' },
      { icon: 'bolt', color: 'orange-5', label: 'Electric' },
    ],
    landlord: { initials: 'JD', name: 'Juan Dela Cruz', color: 'teal-8' },
  },
  {
    id: 2, image: 'https://images.unsplash.com/photo-1560448204-e02f11c3d0e2?w=600&h=300&fit=crop',
    type: 'Solo', name: 'Room 301', property: "Dong's Dormitory", rent: 3500,
    address: '456 Rizal St., Barangay 3, Echague', floor: 'Floor 3', slots: 1,
    amenities: [
      { icon: 'wifi', color: 'teal-5', label: 'WiFi' },
      { icon: 'water_drop', color: 'blue-5', label: 'Water' },
      { icon: 'bolt', color: 'orange-5', label: 'Electric' },
      { icon: 'ac_unit', color: 'purple-5', label: 'AC' },
    ],
    landlord: { initials: 'MD', name: 'Maria Domingo', color: 'orange-8' },
  },
];

function formatPeso(amount: number): string {
  return '\u20B1' + amount.toLocaleString('en-PH', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
}
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
