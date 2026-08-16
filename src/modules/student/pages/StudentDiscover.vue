<template>
  <q-page class="bg-grey-1 q-pb-md">
    <!-- ROOM LIST VIEW -->
    <div v-if="!selectedRoom && !selectedLandlord" class="q-pa-md">
      <div class="row q-col-gutter-sm q-mb-md">
        <div class="col">
          <q-input v-model="searchQuery" outlined dense placeholder="Search rooms, barangay, type..." bg-color="white" class="rounded-input" />
        </div>
        <div class="col-auto">
          <q-btn outline icon="tune" color="grey-8" class="bg-white rounded-borders" no-caps @click="filterDialog = true" />
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
        <div class="text-h6 text-weight-bold q-mb-md">Available Rooms <span class="text-teal-8">({{ filteredRooms.length }})</span></div>

        <div v-if="filteredRooms.length === 0" class="text-center text-grey-6 q-py-xl">
          No rooms match your filters.
        </div>

        <q-card v-for="room in filteredRooms" :key="room.id" flat bordered class="q-mb-md custom-card overflow-hidden">
          <q-img :src="room.image" height="180px">
            <div class="absolute-top-left q-pa-sm">
              <q-chip color="orange-2" text-color="orange-9" dense icon="bed" size="sm" class="text-weight-bold">{{ room.typeLabel }}</q-chip>
            </div>
            <div class="absolute-top-right q-pa-sm">
              <q-btn
                round
                unelevated
                size="sm"
                :icon="room.isFavorited ? 'favorite' : 'favorite_border'"
                :color="room.isFavorited ? 'red-5' : 'grey-8'"
                class="favorite-btn"
                @click.stop="toggleFavorite(room)"
              />
            </div>
            <div class="absolute-bottom bg-transparent q-pa-sm row justify-between items-end" style="background: linear-gradient(180deg, transparent, rgba(0,0,0,0.7));">
              <div class="text-h6 text-weight-bold text-white">{{ room.roomNumber }}</div>
              <div class="bg-black text-white q-px-sm q-py-xs text-weight-bold" style="border-radius:8px">{{ formatPeso(room.rent) }}/mo</div>
            </div>
          </q-img>
          <q-card-section class="q-py-sm">
            <div class="text-subtitle1 text-weight-bold">{{ room.propertyName }}</div>
            <div class="text-caption text-grey-7 q-mt-xs row items-center">
              <q-icon name="place" class="q-mr-xs" /> {{ room.address }}
            </div>
            <div class="row q-gutter-xs q-mt-sm q-mb-sm">
              <q-chip dense outline color="teal-5" icon="meeting_room" size="sm">{{ room.type }}</q-chip>
              <q-chip v-if="room.floor" dense outline color="blue-5" icon="stairs" size="sm">Floor {{ room.floor }}</q-chip>
              <q-chip dense outline color="green-5" icon="check_circle" size="sm">{{ room.status }}</q-chip>
            </div>
            <div class="row items-center justify-between">
              <q-btn flat no-caps class="q-px-xs" @click="openLandlord(room)">
                <q-avatar size="28px" color="teal-8" text-color="white" class="text-weight-bold">{{ room.landlordInitials }}</q-avatar>
                <span class="text-weight-bold text-caption q-ml-sm">{{ room.landlordName }}</span>
              </q-btn>
              <q-btn unelevated color="dark" label="View Details" class="rounded-borders text-caption text-weight-bold" no-caps @click="openRoom(room)" />
            </div>
          </q-card-section>
        </q-card>
      </template>
    </div>

    <!-- ROOM DETAIL VIEW -->
    <div v-else-if="selectedRoom" class="room-detail">
      <div class="q-pa-sm q-pb-none">
        <q-btn flat no-caps color="dark" icon="arrow_back" label="Back to listings" class="text-weight-medium q-px-xs" @click="selectedRoom = null" />
      </div>

      <!-- Hero Image -->
      <q-card flat class="q-ma-sm custom-card overflow-hidden">
        <q-img :src="selectedRoom.image" height="220px">
          <div class="absolute-top q-pa-sm row q-gutter-xs">
            <q-chip color="orange-2" text-color="orange-9" dense icon="bed" size="sm" class="text-weight-bold">{{ selectedRoom.typeLabel }}</q-chip>
            <q-chip color="teal-8" text-color="white" dense icon="check_circle" size="sm" class="text-weight-bold">OSAS Verified</q-chip>
          </div>
          <div class="absolute-top-right q-pa-sm">
            <q-btn
              round unelevated size="sm"
              :icon="selectedRoom.isFavorited ? 'favorite' : 'favorite_border'"
              :color="selectedRoom.isFavorited ? 'red-5' : 'grey-8'"
              class="favorite-btn"
              @click="toggleFavorite(selectedRoom)"
            />
          </div>
          <div class="absolute-bottom bg-transparent q-pa-sm row justify-between items-end" style="background: linear-gradient(180deg, transparent, rgba(0,0,0,0.7));">
            <div>
              <div class="text-h6 text-weight-bold text-white">{{ selectedRoom.roomNumber }}</div>
              <div class="text-caption text-white">{{ selectedRoom.propertyName }}</div>
            </div>
            <div class="bg-black text-white q-px-sm q-py-xs text-weight-bold" style="border-radius:16px">{{ formatPeso(selectedRoom.rent) }}/mo</div>
          </div>
        </q-img>
      </q-card>

      <!-- Room Type Card -->
      <q-card flat bordered class="q-mx-sm q-my-sm rounded-borders" style="background:#FFF3E0;">
        <q-card-section class="row items-center">
          <q-icon name="single_bed" color="orange-8" size="28px" class="q-mr-sm" />
          <div>
            <div class="text-subtitle1 text-weight-bold">Bedspacer Room</div>
            <div class="text-caption text-grey-7">Shared bunk / open bed in a multi-pax room</div>
          </div>
        </q-card-section>
      </q-card>

      <!-- Room Details -->
      <div class="q-px-md q-mt-md">
        <div class="text-subtitle1 text-weight-bold q-mb-sm">Room Details</div>
        <div class="row q-col-gutter-sm">
          <div class="col-6">
            <q-card flat class="detail-box">
              <q-card-section class="q-py-sm">
                <div class="text-caption text-grey-6">Floor</div>
                <div class="text-subtitle2 text-weight-bold q-mt-xs">{{ selectedRoom.floor ? selectedRoom.floor + ' Floor' : '1st Floor' }}</div>
              </q-card-section>
            </q-card>
          </div>
          <div class="col-6">
            <q-card flat class="detail-box">
              <q-card-section class="q-py-sm">
                <div class="text-caption text-grey-6">Capacity</div>
                <div class="text-subtitle2 text-weight-bold q-mt-xs">6 persons</div>
              </q-card-section>
            </q-card>
          </div>
          <div class="col-6">
            <q-card flat class="detail-box">
              <q-card-section class="q-py-sm">
                <div class="text-caption text-grey-6">Open Slots</div>
                <div class="text-subtitle2 text-weight-bold q-mt-xs">1 available</div>
              </q-card-section>
            </q-card>
          </div>
          <div class="col-6">
            <q-card flat class="detail-box">
              <q-card-section class="q-py-sm">
                <div class="text-caption text-grey-6">Monthly</div>
                <div class="text-subtitle2 text-weight-bold q-mt-xs">{{ formatPeso(selectedRoom.rent) }}</div>
              </q-card-section>
            </q-card>
          </div>
        </div>
      </div>

      <!-- Amenities -->
      <div class="q-px-md q-mt-md">
        <div class="text-caption text-grey-6 text-weight-bold q-mb-sm">AMENITIES INCLUDED</div>
        <div class="row q-gutter-xs">
          <q-chip dense outline color="teal" icon="wifi" size="sm">WiFi</q-chip>
          <q-chip dense outline color="blue" icon="water_drop" size="sm">Water</q-chip>
          <q-chip dense outline color="orange" icon="bolt" size="sm">Electric</q-chip>
        </div>
      </div>

      <!-- About the Property -->
      <div class="q-px-md q-mt-md">
        <div class="text-subtitle1 text-weight-bold q-mb-sm">About the Property</div>
        <div class="text-caption text-grey-7 row items-center q-mb-sm">
          <q-icon name="place" color="grey-6" size="16px" class="q-mr-xs" /> {{ selectedRoom.address }}
        </div>
        <p class="text-body2 text-grey-8">
          A clean and secure boarding house near ISU Echague campus. Walking distance to the university gate, with 24/7 CCTV and roving security.
        </p>
      </div>

      <!-- Move-in Cost Breakdown -->
      <div class="q-px-md q-mt-md">
        <div class="text-subtitle1 text-weight-bold q-mb-sm">Move-in Cost Breakdown</div>
        <q-card flat bordered class="custom-card">
          <q-list dense separator>
            <q-item>
              <q-item-section>1 Month Advance Payment</q-item-section>
              <q-item-section side class="text-weight-bold">{{ formatPeso(selectedRoom.rent) }}</q-item-section>
            </q-item>
            <q-item>
              <q-item-section>1 Month Security Deposit</q-item-section>
              <q-item-section side class="text-weight-bold">{{ formatPeso(selectedRoom.rent) }}</q-item-section>
            </q-item>
          </q-list>
          <div class="row items-center justify-between q-px-md q-py-sm" style="background:#1d1d1d;border-radius: 0 0 14px 14px;">
            <span class="text-white text-weight-medium">Total Due at Signing</span>
            <span class="text-white text-weight-bold">{{ formatPeso(selectedRoom.rent * 2) }}</span>
          </div>
        </q-card>
        <q-banner inline-actions rounded class="q-mt-sm" style="background:#E8F5E9;">
          <template #avatar><q-icon name="info" color="green-8" /></template>
          <span class="text-caption text-green-9">Minimum stay of 1 semester. Refundable deposit upon contract completion with no damages.</span>
        </q-banner>
      </div>

      <!-- House Policies -->
      <div class="q-px-md q-mt-md">
        <div class="text-subtitle1 text-weight-bold q-mb-sm">House Policies</div>
        <div class="row q-col-gutter-sm">
          <div v-for="p in policies" :key="p.label" class="col-6">
            <q-card flat class="policy-box q-pa-sm" :style="{ background: p.bg }">
              <q-icon :name="p.icon" :color="p.color" size="22px" />
              <div class="text-subtitle2 text-weight-bold q-mt-xs">{{ p.label }}</div>
              <div class="text-caption text-grey-7">{{ p.desc }}</div>
            </q-card>
          </div>
        </div>
      </div>

      <!-- House Rules -->
      <div class="q-px-md q-mt-md">
        <q-banner inline-actions rounded class="q-mb-sm" style="background:#FFEBEE;">
          <template #avatar><q-icon name="block" color="red-8" /></template>
          <span class="text-caption text-red-8 text-weight-medium">No pets · No smoking inside the property</span>
        </q-banner>
        <div class="text-caption text-grey-6 text-weight-bold q-mb-sm">HOUSE RULES</div>
        <div v-for="rule in houseRules" :key="rule" class="row items-center q-mb-xs">
          <q-icon name="check_circle" color="green-7" size="16px" class="q-mr-sm" />
          <span class="text-body2 text-grey-8">{{ rule }}</span>
        </div>
      </div>

      <!-- Listed By & CTA -->
      <div class="q-px-md q-mt-md q-pb-md">
        <div class="text-caption text-grey-6 text-weight-bold q-mb-sm">LISTED BY</div>
        <q-card flat bordered class="custom-card q-mb-md cursor-pointer" @click="openLandlord(selectedRoom)">
          <q-card-section class="row items-center">
            <q-avatar size="44px" color="teal-8" text-color="white" class="text-weight-bold">{{ selectedRoom.landlordInitials }}</q-avatar>
            <div class="q-ml-sm col">
              <div class="text-subtitle2 text-weight-bold">{{ selectedRoom.landlordName }}</div>
              <div class="text-caption text-grey-6">98% response</div>
            </div>
            <q-btn flat color="teal-8" label="View All" no-caps dense class="text-weight-bold" />
          </q-card-section>
        </q-card>
        <q-btn unelevated color="dark" icon="chat" label="Message to Inquire" class="full-width rounded-borders text-weight-bold q-py-sm" no-caps />
      </div>
    </div>

    <!-- LANDLORD PROFILE VIEW -->
    <div v-else-if="selectedLandlord" class="landlord-profile">
      <div class="q-pa-sm q-pb-none">
        <q-btn flat no-caps color="dark" icon="arrow_back" label="Back to listings" class="text-weight-medium q-px-xs" @click="selectedLandlord = null" />
      </div>

      <div class="q-pa-md">
        <!-- Landlord Info -->
        <div class="row items-center q-mb-md">
          <q-avatar size="64px" color="teal-8" text-color="white" class="text-weight-bold" style="font-size:24px">{{ selectedLandlord.initials }}</q-avatar>
          <div class="q-ml-md">
            <div class="row items-center">
              <div class="text-h6 text-weight-bold">{{ selectedLandlord.name }}</div>
              <q-icon name="verified" color="green-7" size="20px" class="q-ml-sm" />
            </div>
            <div class="text-caption text-grey-6">Landlord</div>
          </div>
        </div>

        <!-- Stats Row -->
        <div class="row q-col-gutter-sm q-mb-md">
          <div class="col-4">
            <q-card flat class="stat-box">
              <q-card-section class="text-center q-py-sm">
                <div class="text-h6 text-weight-bold">98%</div>
                <div class="text-caption text-grey-6">RESPONSE</div>
              </q-card-section>
            </q-card>
          </div>
          <div class="col-4">
            <q-card flat class="stat-box">
              <q-card-section class="text-center q-py-sm">
                <div class="text-h6 text-weight-bold">Jan 2020</div>
                <div class="text-caption text-grey-6">SINCE</div>
              </q-card-section>
            </q-card>
          </div>
          <div class="col-4">
            <q-card flat class="stat-box">
              <q-card-section class="text-center q-py-sm">
                <div class="text-h6 text-weight-bold">1</div>
                <div class="text-caption text-grey-6">PROPERTIES</div>
              </q-card-section>
            </q-card>
          </div>
        </div>

        <!-- Availability Banner -->
        <q-banner inline-actions rounded class="q-mb-md" style="background:#E8F5E9;border:1px solid #c8e6c9;">
          <template #avatar><q-icon name="check_circle" color="green-8" /></template>
          <span class="text-body2 text-green-9 text-weight-medium">{{ selectedLandlord.availableRooms }} of {{ selectedLandlord.totalRooms }} rooms available</span>
        </q-banner>

        <!-- Action Button -->
        <q-btn unelevated color="dark" icon="chat" :label="'Message ' + selectedLandlord.firstName" class="full-width rounded-borders text-weight-bold q-py-sm q-mb-md" no-caps />

        <!-- Property List -->
        <div class="text-subtitle1 text-weight-bold q-mb-sm">Properties</div>
        <q-card flat bordered class="custom-card overflow-hidden">
          <q-img :src="selectedLandlord.propertyImage" height="140px" />
          <q-card-section class="q-py-sm">
            <div class="text-subtitle1 text-weight-bold">{{ selectedLandlord.propertyName }}</div>
          </q-card-section>
          <q-separator />
          <q-list dense>
            <q-item v-for="room in selectedLandlord.rooms" :key="room.id">
              <q-item-section>
                <div class="row items-center q-gutter-xs">
                  <span class="text-weight-bold">{{ room.roomNumber }}</span>
                  <q-chip dense size="sm" :color="room.typeColor" text-color="white" :label="room.type" />
                </div>
              </q-item-section>
              <q-item-section side>
                <div class="text-weight-bold">{{ formatPeso(room.price) }}</div>
                <div :class="room.open > 0 ? 'text-green-7' : 'text-grey-6'" class="text-caption text-weight-medium">
                  {{ room.open > 0 ? room.open + ' open' : 'Occupied' }}
                </div>
              </q-item-section>
            </q-item>
          </q-list>
        </q-card>
      </div>
    </div>

    <!-- Filter Rooms Dialog (bottom sheet) -->
    <q-dialog v-model="filterDialog" position="bottom">
      <q-card class="filter-card full-width">
        <q-card-section class="q-pt-sm q-pb-none">
          <div class="row justify-center q-mb-sm">
            <div class="drag-handle" />
          </div>
          <div class="row items-center justify-between">
            <div class="text-h6 text-weight-bold">Filter Rooms</div>
            <q-btn flat round dense icon="close" @click="filterDialog = false" />
          </div>
        </q-card-section>

        <q-card-section>
          <div class="text-caption text-grey-6 text-weight-bold q-mb-sm">ROOM TYPE</div>
          <div class="row q-gutter-sm q-mb-md">
            <div v-for="t in roomTypes" :key="t.value" class="col" @click="selectRoomType(t.value)">
              <div
                class="type-box column items-center justify-center q-pa-sm cursor-pointer"
                :class="selectedRoomType === t.value ? 'type-box-active' : ''"
                :style="{ borderColor: t.color }"
              >
                <q-icon :name="t.icon" :color="t.color" size="22px" />
                <div class="text-caption q-mt-xs text-weight-medium">{{ t.label }}</div>
              </div>
            </div>
          </div>

          <div class="text-caption text-grey-6 text-weight-bold q-mb-sm">MAX MONTHLY PRICE</div>
          <div class="row q-gutter-sm q-mb-md">
            <q-btn
              v-for="p in priceOptions"
              :key="p.value"
              :label="p.label"
              no-caps dense size="sm"
              :unelevated="selectedPrice === p.value"
              :color="selectedPrice === p.value ? 'dark' : 'grey-3'"
              :text-color="selectedPrice === p.value ? 'white' : 'grey-8'"
              class="price-pill"
              @click="selectPrice(p.value)"
            />
          </div>

          <div class="text-caption text-grey-6 text-weight-bold q-mb-sm">MUST HAVE</div>
          <div class="row q-gutter-xs q-mb-md">
            <q-chip
              v-for="a in amenities"
              :key="a.value"
              :outline="!selectedAmenities.includes(a.value)"
              :color="a.color" :icon="a.icon" :label="a.label"
              clickable @click="toggleAmenity(a.value)"
            />
          </div>

          <div class="osas-card row items-center q-px-md q-py-sm q-mb-md">
            <q-icon name="verified" color="green-7" size="22px" class="q-mr-sm" />
            <span class="text-body2 text-weight-medium">OSAS Verified only</span>
            <q-space />
            <q-toggle v-model="osasVerified" color="green-7" />
          </div>
        </q-card-section>

        <q-card-section class="row q-col-gutter-sm q-pt-none">
          <div class="col-6">
            <q-btn outline color="grey-8" label="Clear All" no-caps class="full-width rounded-borders" @click="clearAll" />
          </div>
          <div class="col-6">
            <q-btn unelevated color="dark" label="Apply Filters" no-caps class="full-width rounded-borders text-weight-bold" @click="applyFilters" />
          </div>
        </q-card-section>
      </q-card>
    </q-dialog>
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
  typeLabel: string;
  floor: string | null;
  status: string;
  rent: number;
  image: string;
  isFavorited: boolean;
  landlordName: string;
  landlordInitials: string;
}

interface LandlordProfile {
  name: string;
  firstName: string;
  initials: string;
  availableRooms: number;
  totalRooms: number;
  propertyName: string;
  propertyImage: string;
  rooms: Array<{ id: string; roomNumber: string; type: string; typeColor: string; price: number; open: number }>;
}

const searchQuery = ref('');
const loading = ref(true);
const error = ref<string | null>(null);
const rooms = ref<DiscoverRoom[]>([]);
const selectedRoom = ref<DiscoverRoom | null>(null);
const selectedLandlord = ref<LandlordProfile | null>(null);

const filterDialog = ref(false);
const selectedRoomType = ref<string | null>(null);
const selectedPrice = ref<string>('any');
const selectedAmenities = ref<string[]>([]);
const osasVerified = ref(false);

const roomTypes = [
  { value: 'bedspacer', label: 'Bedspacer', icon: 'single_bed', color: '#f57c00' },
  { value: 'solo', label: 'Solo', icon: 'person', color: '#00897b' },
  { value: 'double', label: 'Double', icon: 'group', color: '#8e24aa' },
  { value: 'shared', label: 'Shared', icon: 'groups', color: '#1e88e5' },
];

const priceOptions = [
  { value: '2k', label: '≤₱2k' },
  { value: '3k', label: '≤₱3k' },
  { value: '4k', label: '≤₱4k' },
  { value: 'any', label: 'Any' },
];

const amenities = [
  { value: 'wifi', label: 'WiFi', icon: 'wifi', color: 'teal' },
  { value: 'water', label: 'Water', icon: 'water_drop', color: 'blue' },
  { value: 'electric', label: 'Electric', icon: 'bolt', color: 'orange' },
  { value: 'aircon', label: 'Aircon', icon: 'ac_unit', color: 'purple' },
];

const policies = [
  { label: 'Quiet Hours', icon: 'bedtime', color: 'blue-8', bg: '#e3f2fd', desc: '10 PM – 6 AM' },
  { label: 'Curfew', icon: 'schedule', color: 'orange-8', bg: '#fff3e0', desc: '11 PM gate close' },
  { label: 'Visitors', icon: 'people', color: 'purple-8', bg: '#f3e5f5', desc: 'Until 8 PM only' },
  { label: 'Cooking', icon: 'restaurant', color: 'green-8', bg: '#e8f5e9', desc: 'Common kitchen' },
  { label: 'Laundry', icon: 'local_laundry_service', color: 'teal-8', bg: '#e0f2f1', desc: 'Coin-operated' },
  { label: 'Sub-leasing', icon: 'block', color: 'red-8', bg: '#ffebee', desc: 'Not allowed' },
];

const houseRules = [
  'Register visitors at the front desk',
  'Keep common areas clean',
  'No loud music after quiet hours',
  'Label personal food in the shared fridge',
];

const filteredRooms = computed(() => {
  let result = rooms.value;

  const q = searchQuery.value.trim().toLowerCase();
  if (q) {
    result = result.filter((r) =>
      r.propertyName.toLowerCase().includes(q) ||
      r.address.toLowerCase().includes(q) ||
      r.roomNumber.toLowerCase().includes(q)
    );
  }

  if (selectedRoomType.value) {
    result = result.filter((r) => r.type.toLowerCase() === selectedRoomType.value);
  }

  if (selectedPrice.value !== 'any') {
    const max = { '2k': 2000, '3k': 3000, '4k': 4000 }[selectedPrice.value] ?? Infinity;
    result = result.filter((r) => r.rent <= max);
  }

  return result;
});

function formatPeso(amount: number): string {
  return '\u20B1' + amount.toLocaleString('en-PH', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
}

function openRoom(room: DiscoverRoom) {
  selectedLandlord.value = null;
  selectedRoom.value = room;
}

function toggleFavorite(room: DiscoverRoom) {
  room.isFavorited = !room.isFavorited;
}

function openLandlord(room: DiscoverRoom) {
  selectedRoom.value = null;
  selectedLandlord.value = {
    name: room.landlordName,
    firstName: room.landlordName.split(' ')[0] ?? room.landlordName,
    initials: room.landlordInitials,
    availableRooms: 3,
    totalRooms: 4,
    propertyName: room.propertyName,
    propertyImage: room.image,
    rooms: [
      { id: '1', roomNumber: 'Bed 1-A', type: 'Bedspacer', typeColor: 'orange', price: 1800, open: 1 },
      { id: '2', roomNumber: 'Room 2-B', type: 'Double', typeColor: 'purple', price: 3000, open: 1 },
      { id: '3', roomNumber: 'Room 3-A', type: 'Solo', typeColor: 'teal', price: 2500, open: 1 },
      { id: '4', roomNumber: 'Room 3-B', type: 'Solo', typeColor: 'teal', price: 2500, open: 0 },
    ],
  };
}

function selectRoomType(value: string) {
  selectedRoomType.value = selectedRoomType.value === value ? null : value;
}

function selectPrice(value: string) {
  selectedPrice.value = value;
}

function toggleAmenity(value: string) {
  const idx = selectedAmenities.value.indexOf(value);
  if (idx === -1) selectedAmenities.value.push(value);
  else selectedAmenities.value.splice(idx, 1);
}

function clearAll() {
  selectedRoomType.value = null;
  selectedPrice.value = 'any';
  selectedAmenities.value = [];
  osasVerified.value = false;
  filterDialog.value = false;
}

function applyFilters() {
  filterDialog.value = false;
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
      typeLabel: r.property?.room_type === 'bedspacer' ? 'Bedspacer' : (r.property?.room_type ?? 'Room'),
      floor: r.floor ?? null,
      status: r.status ?? 'available',
      rent: r.monthly_rent ?? r.property?.monthly_rent ?? 0,
      image: 'https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?w=600&h=300&fit=crop',
      isFavorited: false,
      landlordName: 'Juan Dela Cruz',
      landlordInitials: 'JD',
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

.room-detail,
.landlord-profile {
  animation: fadeIn 0.2s ease;
}

.favorite-btn {
  background: rgba(255, 255, 255, 0.9);
  box-shadow: 0 1px 4px rgba(0, 0, 0, 0.2);
}

.stat-box {
  border-radius: 12px;
  background: #f5f5f5;
}

.detail-box {
  border-radius: 12px;
  background: #f5f5f5;
}

.policy-box {
  border-radius: 12px;
}

.filter-card {
  border-radius: 20px 20px 0 0;
  padding-bottom: 12px;
}

.drag-handle {
  width: 40px;
  height: 4px;
  border-radius: 2px;
  background: #e0e0e0;
}

.type-box {
  border: 1.5px solid;
  border-radius: 12px;
  min-height: 64px;
}

.type-box-active {
  background: #f5f5f5;
}

.price-pill {
  border-radius: 20px;
  padding: 0 16px;
  min-height: 32px;
}

.osas-card {
  border: 1px solid #e0e0e0;
  border-radius: 12px;
}

@keyframes fadeIn {
  from { opacity: 0; transform: translateY(6px); }
  to { opacity: 1; transform: translateY(0); }
}
</style>
