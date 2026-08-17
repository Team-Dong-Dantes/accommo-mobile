<template>
  <q-page class="bg-grey-1 q-pb-md">
    <!-- PROPERTY LIST VIEW -->
    <div v-if="!selectedProperty && !selectedLandlord" class="q-pa-md">
      <div class="row q-col-gutter-sm q-mb-md">
        <div class="col">
          <q-input v-model="searchQuery" outlined dense placeholder="Search properties, barangay, type..." bg-color="white" class="rounded-input" />
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
        <div class="text-h6 text-weight-bold q-mb-md">Available Properties <span class="text-teal-8">({{ filteredProperties.length }})</span></div>

        <div v-if="filteredProperties.length === 0" class="text-center text-grey-6 q-py-xl">
          No properties match your filters.
        </div>

        <q-card v-for="property in filteredProperties" :key="property.id" flat bordered class="q-mb-md custom-card overflow-hidden">
          <q-img :src="property.image" height="180px">
            <div class="absolute-top-left q-pa-sm">
              <q-chip color="orange-2" text-color="orange-9" dense icon="apartment" size="sm" class="text-weight-bold">{{ property.typeLabel }}</q-chip>
            </div>
            <div class="absolute-top-right q-pa-sm">
              <q-btn
                round
                unelevated
                size="sm"
                :icon="property.isFavorited ? 'favorite' : 'favorite_border'"
                :color="property.isFavorited ? 'red-5' : 'grey-8'"
                class="favorite-btn"
                @click.stop="toggleFavorite(property)"
              />
            </div>
            <div class="absolute-bottom bg-transparent q-pa-sm row justify-between items-end" style="background: linear-gradient(180deg, transparent, rgba(0,0,0,0.7));">
              <div class="text-h6 text-weight-bold text-white">{{ property.name }}</div>
              <div class="bg-black text-white q-px-sm q-py-xs text-weight-bold" style="border-radius:8px">{{ property.rent ? formatPeso(property.rent) + '/mo' : 'Price on request' }}</div>
            </div>
          </q-img>
          <q-card-section class="q-py-sm">
            <div class="text-subtitle1 text-weight-bold">{{ property.name }}</div>
            <div class="text-caption text-grey-7 q-mt-xs row items-center">
              <q-icon name="place" class="q-mr-xs" /> {{ property.address }}
            </div>
            <div class="row q-gutter-xs q-mt-sm q-mb-sm">
              <q-chip dense outline color="teal-5" icon="meeting_room" size="sm">{{ property.typeLabel }}</q-chip>
              <q-chip dense outline color="green-5" icon="check_circle" size="sm">{{ property.availableRooms }} rooms available</q-chip>
              <q-chip dense outline color="purple-5" icon="store" size="sm">{{ property.landlordName }}</q-chip>
            </div>
            <div class="row items-center justify-between">
              <q-btn flat no-caps class="q-px-xs" @click="openLandlord(property)">
                <q-avatar size="28px" color="teal-8" text-color="white" class="text-weight-bold">{{ property.landlordInitials }}</q-avatar>
                <span class="text-weight-bold text-caption q-ml-sm">{{ property.landlordName }}</span>
              </q-btn>
              <q-btn unelevated color="dark" label="View Details" class="rounded-borders text-caption text-weight-bold" no-caps @click="openProperty(property)" />
            </div>
          </q-card-section>
        </q-card>
      </template>
    </div>

    <!-- PROPERTY DETAIL VIEW -->
    <div v-else-if="selectedProperty" class="room-detail">
      <div class="q-pa-sm q-pb-none">
        <q-btn flat no-caps color="dark" icon="arrow_back" label="Back to listings" class="text-weight-medium q-px-xs" @click="closeProperty" />
      </div>

      <!-- Hero Image -->
      <q-card flat class="q-ma-sm custom-card overflow-hidden">
        <q-img :src="heroImage" height="220px">
          <div class="absolute-top q-pa-sm row q-gutter-xs">
            <q-chip color="orange-2" text-color="orange-9" dense icon="apartment" size="sm" class="text-weight-bold">{{ selectedProperty.typeLabel }}</q-chip>
            <q-chip v-if="roomDetail?.status === 'accredited'" color="teal-8" text-color="white" dense icon="verified" size="sm" class="text-weight-bold">OSAS Verified</q-chip>
          </div>
          <div class="absolute-top-right q-pa-sm">
            <q-btn
              round unelevated size="sm"
              :icon="selectedProperty.isFavorited ? 'favorite' : 'favorite_border'"
              :color="selectedProperty.isFavorited ? 'red-5' : 'grey-8'"
              class="favorite-btn"
              @click="toggleFavorite(selectedProperty)"
            />
          </div>
          <div class="absolute-bottom bg-transparent q-pa-sm row justify-between items-end" style="background: linear-gradient(180deg, transparent, rgba(0,0,0,0.7));">
            <div>
              <div class="text-h6 text-weight-bold text-white">{{ selectedProperty.name }}</div>
              <div class="text-caption text-white">{{ selectedProperty.address }}</div>
            </div>
            <div class="bg-black text-white q-px-sm q-py-xs text-weight-bold" style="border-radius:16px">{{ selectedProperty.rent ? formatPeso(selectedProperty.rent) + '/mo' : 'Price on request' }}</div>
          </div>
        </q-img>
      </q-card>

      <!-- Type Card -->
      <q-card flat bordered class="q-mx-sm q-my-sm rounded-borders" style="background:#FFF3E0;">
        <q-card-section class="row items-center">
          <q-icon name="apartment" color="orange-8" size="28px" class="q-mr-sm" />
          <div>
            <div class="text-subtitle1 text-weight-bold">{{ roomTypeLabel(selectedProperty.type) }}</div>
            <div class="text-caption text-grey-7">{{ roomTypeDesc(selectedProperty.type) }}</div>
          </div>
        </q-card-section>
      </q-card>

      <!-- Property Details -->
      <div class="q-px-md q-mt-md">
        <div class="text-subtitle1 text-weight-bold q-mb-sm">Property Details</div>
        <div class="row q-col-gutter-sm">
          <div class="col-6">
            <q-card flat class="detail-box">
              <q-card-section class="q-py-sm">
                <div class="text-caption text-grey-6">Available Rooms</div>
                <div class="text-subtitle2 text-weight-bold q-mt-xs">{{ selectedProperty.availableRooms }}</div>
              </q-card-section>
            </q-card>
          </div>
          <div class="col-6">
            <q-card flat class="detail-box">
              <q-card-section class="q-py-sm">
                <div class="text-caption text-grey-6">Type</div>
                <div class="text-subtitle2 text-weight-bold q-mt-xs">{{ selectedProperty.typeLabel }}</div>
              </q-card-section>
            </q-card>
          </div>
          <div class="col-6">
            <q-card flat class="detail-box">
              <q-card-section class="q-py-sm">
                <div class="text-caption text-grey-6">Monthly</div>
                <div class="text-subtitle2 text-weight-bold q-mt-xs">{{ selectedProperty.rent ? formatPeso(selectedProperty.rent) : 'Price on request' }}</div>
              </q-card-section>
            </q-card>
          </div>
          <div class="col-6">
            <q-card flat class="detail-box">
              <q-card-section class="q-py-sm">
                <div class="text-caption text-grey-6">Listed By</div>
                <div class="text-subtitle2 text-weight-bold q-mt-xs">{{ selectedProperty.landlordName }}</div>
              </q-card-section>
            </q-card>
          </div>
        </div>
      </div>

      <!-- Available Rooms list -->
      <div class="q-px-md q-mt-md" v-if="selectedProperty.roomsList.length">
        <div class="text-subtitle1 text-weight-bold q-mb-sm">Available Rooms</div>
        <q-list bordered separator>
          <q-item v-for="rm in selectedProperty.roomsList" :key="rm.id">
            <q-item-section>
              <div class="text-weight-bold">Room {{ rm.roomNumber }}</div>
            </q-item-section>
            <q-item-section side>
              <div class="text-weight-bold">{{ rm.rent ? formatPeso(rm.rent) + '/mo' : 'Price on request' }}</div>
            </q-item-section>
          </q-item>
        </q-list>
      </div>

      <!-- Amenities -->
      <div class="q-px-md q-mt-md">
        <div class="text-caption text-grey-6 text-weight-bold q-mb-sm">AMENITIES INCLUDED</div>
        <div v-if="detailLoading" class="text-caption text-grey-6">Loading…</div>
        <div v-else-if="(roomDetail?.amenities?.length ?? 0) === 0" class="text-caption text-grey-6">No amenities listed.</div>
        <div v-else class="row q-gutter-xs">
          <q-chip
            v-for="a in (roomDetail?.amenities ?? [])"
            :key="a"
            dense outline
            :color="amenityMeta[a]?.color || 'teal'"
            :icon="amenityMeta[a]?.icon || 'check_circle'"
            size="sm"
          >{{ amenityMeta[a]?.label || a }}</q-chip>
        </div>
      </div>

      <!-- About the Property -->
      <div class="q-px-md q-mt-md">
        <div class="text-subtitle1 text-weight-bold q-mb-sm">About the Property</div>
        <div class="text-caption text-grey-7 row items-center q-mb-sm">
          <q-icon name="place" color="grey-6" size="16px" class="q-mr-xs" /> {{ selectedProperty.address }}
        </div>
        <p v-if="roomDetail?.description" class="text-body2 text-grey-8">{{ roomDetail?.description }}</p>
        <p v-else class="text-body2 text-grey-6">No description provided for this property.</p>
      </div>

      <!-- Move-in Cost Breakdown -->
      <div class="q-px-md q-mt-md">
        <div class="text-subtitle1 text-weight-bold q-mb-sm">Move-in Cost Breakdown</div>
        <q-card flat bordered class="custom-card">
          <q-list dense separator>
            <q-item>
              <q-item-section>{{ advanceMonths }} Month{{ advanceMonths === 1 ? '' : 's' }} Advance Payment</q-item-section>
              <q-item-section side class="text-weight-bold">{{ formatPeso(selectedProperty.rent * advanceMonths) }}</q-item-section>
            </q-item>
            <q-item>
              <q-item-section>{{ depositMonths }} Month{{ depositMonths === 1 ? '' : 's' }} Security Deposit</q-item-section>
              <q-item-section side class="text-weight-bold">{{ formatPeso(selectedProperty.rent * depositMonths) }}</q-item-section>
            </q-item>
          </q-list>
          <div class="row items-center justify-between q-px-md q-py-sm" style="background:#1d1d1d;border-radius: 0 0 14px 14px;">
            <span class="text-white text-weight-medium">Total Due at Signing</span>
            <span class="text-white text-weight-bold">{{ formatPeso(selectedProperty.rent * (advanceMonths + depositMonths)) }}</span>
          </div>
        </q-card>
        <q-banner inline-actions rounded class="q-mt-sm" style="background:#E8F5E9;">
          <template #avatar><q-icon name="info" color="green-8" /></template>
          <span class="text-caption text-green-9">Minimum stay of {{ minStay }} semester{{ minStay === 1 ? '' : 's' }}. Refundable deposit upon contract completion with no damages.</span>
        </q-banner>
      </div>

      <!-- House Policies -->
      <div class="q-px-md q-mt-md">
        <div class="text-subtitle1 text-weight-bold q-mb-sm">House Policies</div>
        <div v-if="detailLoading" class="text-caption text-grey-6">Loading…</div>
        <div v-else-if="policyCards.length === 0" class="text-caption text-grey-6">No policies listed.</div>
        <div v-else class="row q-col-gutter-sm">
          <div v-for="p in policyCards" :key="p.label" class="col-6">
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
        <div v-if="houseRulesList.length" class="q-banner inline-actions rounded q-mb-sm" style="background:#FFEBEE;">
          <q-icon name="block" color="red-8" class="q-mr-xs" />
          <span class="text-caption text-red-8 text-weight-medium">{{ houseRulesList.join(' · ') }}</span>
        </div>
        <div class="text-caption text-grey-6 text-weight-bold q-mb-sm">HOUSE RULES</div>
        <div v-if="positiveRules.length === 0" class="text-caption text-grey-6">No specific house rules listed.</div>
        <div v-for="rule in positiveRules" :key="rule" class="row items-center q-mb-xs">
          <q-icon name="check_circle" color="green-7" size="16px" class="q-mr-sm" />
          <span class="text-body2 text-grey-8">{{ rule }}</span>
        </div>
      </div>

      <!-- Listed By & CTA -->
      <div class="q-px-md q-mt-md q-pb-md">
        <div class="text-caption text-grey-6 text-weight-bold q-mb-sm">LISTED BY</div>
        <q-card flat bordered class="custom-card q-mb-md cursor-pointer" @click="openLandlord(selectedProperty)">
          <q-card-section class="row items-center">
            <q-avatar size="44px" color="teal-8" text-color="white" class="text-weight-bold">{{ selectedProperty.landlordInitials }}</q-avatar>
            <div class="q-ml-sm col">
              <div class="text-subtitle2 text-weight-bold">{{ roomDetail?.landlord.name ?? selectedProperty.landlordName }}</div>
              <div class="text-caption text-grey-6">{{ landlordResponseLabel }}</div>
            </div>
            <q-btn flat color="teal-8" label="View All" no-caps dense class="text-weight-bold" />
          </q-card-section>
        </q-card>
        <q-btn unelevated color="dark" icon="chat" label="Message to Inquire" class="full-width rounded-borders text-weight-bold q-py-sm" no-caps @click="inquire(selectedProperty)" />
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
            <div class="text-caption text-grey-6">Business Owner</div>
          </div>
        </div>

        <!-- Stats Row -->
        <div class="row q-col-gutter-sm q-mb-md">
          <div class="col-4">
            <q-card flat class="stat-box">
              <q-card-section class="text-center q-py-sm">
                <div class="text-h6 text-weight-bold">{{ landlordStats.responseRate != null ? Math.round(landlordStats.responseRate * 100) + '%' : '—' }}</div>
                <div class="text-caption text-grey-6">RESPONSE</div>
              </q-card-section>
            </q-card>
          </div>
          <div class="col-4">
            <q-card flat class="stat-box">
              <q-card-section class="text-center q-py-sm">
                <div class="text-h6 text-weight-bold">{{ landlordStats.avgMin != null ? '~' + landlordStats.avgMin + 'm' : '—' }}</div>
                <div class="text-caption text-grey-6">RESP. TIME</div>
              </q-card-section>
            </q-card>
          </div>
          <div class="col-4">
            <q-card flat class="stat-box">
              <q-card-section class="text-center q-py-sm">
                <div class="text-h6 text-weight-bold">{{ landlordStats.propertyCount }}</div>
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
        <q-btn unelevated color="dark" icon="chat" :label="'Message ' + selectedLandlord.firstName" class="full-width rounded-borders text-weight-bold q-py-sm q-mb-md" no-caps @click="inquireLandlord(selectedLandlord)" />

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

    <!-- Filter Properties Dialog (bottom sheet) -->
    <q-dialog v-model="filterDialog" position="bottom">
      <q-card class="filter-card full-width">
        <q-card-section class="q-pt-sm q-pb-none">
          <div class="row justify-center q-mb-sm">
            <div class="drag-handle" />
          </div>
          <div class="row items-center justify-between">
            <div class="text-h6 text-weight-bold">Filter Properties</div>
            <q-btn flat round dense icon="close" @click="filterDialog = false" />
          </div>
        </q-card-section>

        <q-card-section>
          <div class="text-caption text-grey-6 text-weight-bold q-mb-sm">PROPERTY TYPE</div>
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
import { useRouter } from 'vue-router';
import { supabase } from '@/shared/utils/supabase';
import { formatPeso, initialsOf } from '@/shared/utils/format';

interface DiscoverProperty {
  id: string;
  name: string;
  address: string;
  type: string;
  typeLabel: string;
  rent: number;
  image: string;
  isFavorited: boolean;
  landlordName: string;
  landlordInitials: string;
  landlordId: string | null;
  description: string | null;
  availableRooms: number;
  roomsList: Array<{ id: string; roomNumber: string; rent: number | null; type: string }>;
  propertyId: string | null;
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

interface RoomPolicy {
  cooking: boolean | null;
  curfew_time: string | null;
  deposit_months: number | null;
  advance_months: number | null;
  pets: boolean | null;
  visitor_policy: string | null;
  laundry: boolean | null;
  quiet_hours: string | null;
  smoking: boolean | null;
  min_stay: number | null;
}

interface RoomDetail {
  description: string | null;
  status: string | null;
  ratingAvg: number | null;
  reviewsCount: number | null;
  policy: RoomPolicy | null;
  amenities: string[];
  images: string[];
  landlord: { name: string; responseRate: number | null; avgResponseMinutes: number | null; propertyCount: number };
}

const router = useRouter();

const searchQuery = ref('');
const loading = ref(true);
const error = ref<string | null>(null);
const properties = ref<DiscoverProperty[]>([]);
const selectedProperty = ref<DiscoverProperty | null>(null);
const selectedLandlord = ref<LandlordProfile | null>(null);
const detailLoading = ref(false);
const roomDetail = ref<RoomDetail | null>(null);
const landlordStats = ref<{ responseRate: number | null; avgMin: number | null; propertyCount: number }>({
  responseRate: null,
  avgMin: null,
  propertyCount: 0,
});

const filterDialog = ref(false);
const selectedRoomType = ref<string | null>(null);
const selectedPrice = ref<string>('any');
const selectedAmenities = ref<string[]>([]);
const osasVerified = ref(false);

const roomTypes = [
  { value: 'solo', label: 'Solo', icon: 'person', color: '#00897b' },
  { value: 'duo', label: 'Duo', icon: 'group', color: '#8e24aa' },
  { value: 'triple', label: 'Triple', icon: 'groups', color: '#1e88e5' },
  { value: 'bedspace', label: 'Bedspacer', icon: 'single_bed', color: '#f57c00' },
  { value: 'studio', label: 'Studio', icon: 'apartment', color: '#6d4c41' },
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

const ROOM_TYPE_META: Record<string, { label: string; desc: string }> = {
  solo: { label: 'Solo Room', desc: 'Private room for one occupant' },
  duo: { label: 'Duo Room', desc: 'Shared room for two occupants' },
  triple: { label: 'Triple Room', desc: 'Shared room for three occupants' },
  bedspace: { label: 'Bedspacer Room', desc: 'Shared bunk / open bed in a multi-pax room' },
  studio: { label: 'Studio Unit', desc: 'Self-contained private studio' },
};

const AMENITY_META: Record<string, { label: string; icon: string; color: string }> = {
  wifi: { label: 'WiFi', icon: 'wifi', color: 'teal' },
  water: { label: 'Water', icon: 'water_drop', color: 'blue' },
  electric: { label: 'Electric', icon: 'bolt', color: 'orange' },
  aircon: { label: 'Aircon', icon: 'ac_unit', color: 'purple' },
  kitchen: { label: 'Kitchen', icon: 'restaurant', color: 'green' },
  laundry: { label: 'Laundry', icon: 'local_laundry_service', color: 'teal' },
  cctv: { label: 'CCTV', icon: 'videocam', color: 'grey' },
  parking: { label: 'Parking', icon: 'local_parking', color: 'indigo' },
};

const amenityMeta = AMENITY_META;

function roomTypeLabel(t: string): string {
  return ROOM_TYPE_META[t]?.label ?? (t ? t.charAt(0).toUpperCase() + t.slice(1) : 'Room');
}
function roomTypeDesc(t: string): string {
  return ROOM_TYPE_META[t]?.desc ?? '';
}

function deriveRoomType(capacity: number | null, label: string | null): string {
  const l = (label ?? '').toLowerCase();
  if (l.includes('studio')) return 'studio';
  const cap = capacity ?? 1;
  if (cap <= 1) return 'solo';
  if (cap === 2) return 'duo';
  if (cap === 3) return 'triple';
  return 'bedspace';
}

const filteredProperties = computed(() => {
  let result = properties.value;

  const q = searchQuery.value.trim().toLowerCase();
  if (q) {
    result = result.filter((p) =>
      p.name.toLowerCase().includes(q) ||
      p.address.toLowerCase().includes(q) ||
      p.landlordName.toLowerCase().includes(q),
    );
  }

  if (selectedRoomType.value) {
    result = result.filter((p) => p.type === selectedRoomType.value);
  }

  if (selectedPrice.value !== 'any') {
    const max = { '2k': 2000, '3k': 3000, '4k': 4000 }[selectedPrice.value] ?? Infinity;
    result = result.filter((p) => p.rent <= max);
  }

  if (osasVerified.value) {
    result = result.filter((p) => p.propertyId != null);
  }

  return result;
});

const advanceMonths = computed(() => roomDetail.value?.policy?.advance_months ?? 1);
const depositMonths = computed(() => roomDetail.value?.policy?.deposit_months ?? 1);
const minStay = computed(() => roomDetail.value?.policy?.min_stay ?? 1);

const policyCards = computed(() => {
  const p = roomDetail.value?.policy;
  if (!p) return [];
  const cards: Array<{ label: string; icon: string; color: string; bg: string; desc: string }> = [];
  if (p.cooking !== null) cards.push({ label: 'Cooking', icon: 'restaurant', color: 'green-8', bg: '#e8f5e9', desc: p.cooking ? 'Common kitchen' : 'Not allowed' });
  if (p.pets !== null) cards.push({ label: 'Pets', icon: 'pets', color: 'purple-8', bg: '#f3e5f5', desc: p.pets ? 'Allowed' : 'Not allowed' });
  if (p.visitor_policy !== null || p.visitor_policy) cards.push({ label: 'Visitors', icon: 'people', color: 'blue-8', bg: '#e3f2fd', desc: p.visitor_policy || 'Check with the business' });
  if (p.curfew_time !== null) cards.push({ label: 'Curfew', icon: 'schedule', color: 'orange-8', bg: '#fff3e0', desc: p.curfew_time ? `Gate ${p.curfew_time}` : 'No curfew' });
  if (p.laundry !== null) cards.push({ label: 'Laundry', icon: 'local_laundry_service', color: 'teal-8', bg: '#e0f2f1', desc: p.laundry ? 'Available' : 'Not available' });
  if (p.quiet_hours !== null) cards.push({ label: 'Quiet Hours', icon: 'bedtime', color: 'indigo-8', bg: '#e8eaf6', desc: p.quiet_hours || 'Respect neighbors' });
  return cards;
});

const houseRulesList = computed(() => {
  const p = roomDetail.value?.policy;
  if (!p) return [];
  const rules: string[] = [];
  if (p.smoking === false) rules.push('No smoking inside the property');
  if (p.pets === false) rules.push('No pets');
  return rules;
});

const positiveRules = computed(() => {
  const p = roomDetail.value?.policy;
  if (!p) return [];
  const rules: string[] = [];
  if (p.cooking) rules.push('Cooking allowed in common kitchen');
  if (p.laundry) rules.push('Laundry facilities available');
  return rules;
});

const landlordResponseLabel = computed(() => {
  const l = roomDetail.value?.landlord;
  if (!l) return 'Owner';
  if (l.responseRate != null) return `${Math.round(l.responseRate * 100)}% response`;
  if (l.avgResponseMinutes != null) return `Responds in ~${l.avgResponseMinutes} min`;
  return 'Owner';
});

const heroImage = computed(() => {
  const imgs = roomDetail.value?.images;
  if (imgs && imgs.length > 0) return imgs[0];
  return selectedProperty.value?.image ?? 'https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?w=600&h=300&fit=crop';
});

function openProperty(property: DiscoverProperty) {
  selectedLandlord.value = null;
  selectedProperty.value = property;
  void loadPropertyDetail(property);
}

function closeProperty() {
  selectedProperty.value = null;
  roomDetail.value = null;
}

function toggleFavorite(property: DiscoverProperty) {
  property.isFavorited = !property.isFavorited;
}

function inquire(property: DiscoverProperty) {
  if (property.landlordId) {
    void router.push({ path: '/student/messages', query: { landlord: property.landlordId } });
  }
}

function inquireLandlord(landlord: LandlordProfile) {
  void router.push({ path: '/student/messages', query: { landlord: selectedLandlord.value?.rooms ? null : null } });
}

function openLandlord(property: DiscoverProperty) {
  selectedProperty.value = null;
  roomDetail.value = null;
  void loadLandlordData(property.landlordId, {
    name: property.landlordName,
    initials: property.landlordInitials,
    propertyName: property.name,
    propertyImage: property.image,
  });
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

async function loadPropertyDetail(property: DiscoverProperty) {
  detailLoading.value = true;
  try {
    const { data: prop, error: pe } = await supabase
      .from('properties')
      .select('description, status, rating_avg, reviews_count, landlord_id, property_policies(cooking, curfew_time, deposit_months, advance_months, pets, visitor_policy, laundry, quiet_hours, smoking, min_stay), property_amenities(amenity), property_images(url, sort_order), rooms(id, room_number, monthly_rent, status)')
      .eq('id', property.id)
      .eq('rooms.status', 'available')
      .maybeSingle();

    if (pe) throw pe;

    let landlord = { name: property.landlordName, responseRate: null as number | null, avgResponseMinutes: null as number | null, propertyCount: 0 };
    if (prop?.landlord_id) {
      const [lp, pc] = await Promise.all([
        supabase.from('landlord_profiles').select('business_name, response_rate, avg_response_minutes').eq('user_id', prop.landlord_id).maybeSingle(),
        supabase.from('properties').select('*', { count: 'exact', head: true }).eq('landlord_id', prop.landlord_id),
      ]);
      if (lp.data) {
        const lpData = lp.data as { business_name: string | null; response_rate: number | null; avg_response_minutes: number | null };
        landlord = {
          name: lpData.business_name || property.landlordName,
          responseRate: lpData.response_rate ?? null,
          avgResponseMinutes: lpData.avg_response_minutes ?? null,
          propertyCount: pc.count ?? 0,
        };
      } else {
        landlord.propertyCount = pc.count ?? 0;
      }
    }

    const availableRooms = (prop?.rooms ?? []).filter((x) => x.status === 'available');
    const amenitiesRaw = (prop?.property_amenities ?? []) as Array<{ amenity: string }>;
    const imagesRaw = (prop?.property_images ?? []) as Array<{ url: string | null; sort_order: number | null }>;
    const imgs = imagesRaw.filter((i) => i.url).sort((a, b) => (a.sort_order ?? 0) - (b.sort_order ?? 0));

    roomDetail.value = {
      description: prop?.description ?? null,
      status: prop?.status ?? null,
      ratingAvg: prop?.rating_avg ?? null,
      reviewsCount: prop?.reviews_count ?? null,
      policy: (prop?.property_policies as unknown as RoomPolicy | null) ?? null,
      amenities: amenitiesRaw.map((a) => a.amenity),
      images: imgs.map((i) => i.url).filter((u): u is string => !!u),
      landlord,
    };

    const sp = selectedProperty.value;
    if (sp) {
      sp.image = imgs[0]?.url ?? sp.image;
      sp.availableRooms = availableRooms.length;
      sp.roomsList = availableRooms.map((x) => ({
        id: x.id,
        roomNumber: x.room_number ?? 'Room',
        rent: x.monthly_rent ?? null,
        type: sp.type,
      }));
    }
  } catch (e) {
    error.value = e instanceof Error ? e.message : 'Failed to load details';
    roomDetail.value = null;
  } finally {
    detailLoading.value = false;
  }
}

async function loadLandlordData(
  landlordId: string | null,
  ctx: { name: string; initials: string; propertyName: string; propertyImage: string },
) {
  if (!landlordId) return;
  detailLoading.value = true;
  try {
    const [lpRes, propsRes] = await Promise.all([
      supabase.from('landlord_profiles').select('business_name, response_rate, avg_response_minutes').eq('user_id', landlordId).maybeSingle(),
      supabase.from('properties').select('id, name').eq('landlord_id', landlordId),
    ]);

    const lpData = lpRes.data as { business_name: string | null; response_rate: number | null; avg_response_minutes: number | null } | null;
    const businessName = lpData?.business_name ?? ctx.name;
    const propertyRows = (propsRes.data ?? []) as Array<{ id: string; name: string | null }>;

    let roomRows: Array<{ id: string; room_number: string | null; label: string | null; monthly_rent: number | null; capacity: number | null; current_pax: number | null; status: string | null }> = [];
    if (propertyRows.length > 0) {
      const { data: rm } = await supabase
        .from('rooms')
        .select('id, room_number, label, monthly_rent, capacity, current_pax, status')
        .in('property_id', propertyRows.map((p) => p.id));
      roomRows = (rm ?? []) as typeof roomRows;
    }

    const typeColorMap: Record<string, string> = { solo: 'teal', duo: 'purple', triple: 'blue', bedspace: 'orange', studio: 'green' };
    const roomsList = roomRows.map((r) => {
      const type = deriveRoomType(r.capacity, r.label);
      return {
        id: r.id,
        roomNumber: r.room_number ?? 'Room',
        type,
        typeColor: typeColorMap[type] ?? 'teal',
        price: r.monthly_rent ?? 0,
        open: (r.capacity ?? 0) - (r.current_pax ?? 0),
      };
    });

    landlordStats.value = {
      responseRate: lpData?.response_rate ?? null,
      avgMin: lpData?.avg_response_minutes ?? null,
      propertyCount: propertyRows.length,
    };

    const primary = propertyRows[0];
    selectedLandlord.value = {
      name: businessName,
      firstName: businessName.split(' ')[0] ?? businessName,
      initials: ctx.initials,
      availableRooms: roomRows.filter((r) => r.status === 'available').length,
      totalRooms: roomRows.length,
      propertyName: primary?.name ?? ctx.propertyName,
      propertyImage: ctx.propertyImage,
      rooms: roomsList,
    };
  } catch (e) {
    error.value = e instanceof Error ? e.message : 'Failed to load landlord';
  } finally {
    detailLoading.value = false;
  }
}

async function loadProperties() {
  loading.value = true;
  error.value = null;
  try {
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) { void router.push('/login'); return; }

    const { data, error: queryError } = await supabase
      .from('properties')
      .select('id, name, address, room_type, monthly_rent, landlord_id, description, property_images(url, sort_order), rooms(id, room_number, monthly_rent, status)')
      .eq('status', 'accredited')
      .eq('rooms.status', 'available')
      .order('name', { ascending: true });

    if (queryError) throw queryError;

    const rows = (data ?? []) as unknown as Array<{
      id: string;
      name: string | null;
      address: string | null;
      room_type: string | null;
      monthly_rent: number | null;
      landlord_id: string | null;
      description: string | null;
      property_images: Array<{ url: string | null; sort_order: number | null }> | null;
      rooms: Array<{ id: string; room_number: string | null; monthly_rent: number | null; status: string | null }> | null;
    }>;

    const landlordIds = Array.from(
      new Set(rows.map((r) => r.landlord_id).filter((id): id is string => !!id)),
    );

    const landlordNames = new Map<string, string>();
    if (landlordIds.length > 0) {
      const profileResult = await supabase
        .from('landlord_profiles')
        .select('user_id, business_name')
        .in('user_id', landlordIds);

      for (const p of (profileResult.data ?? []) as unknown as Array<{ user_id: string; business_name: string | null }>) {
        if (p.business_name) landlordNames.set(p.user_id, p.business_name);
      }

      if (profileResult.error) error.value = profileResult.error.message;
    }

    properties.value = rows.map((r) => {
      const type = r.room_type ?? 'room';
      const availableRooms = (r.rooms ?? []) as Array<{ id: string; room_number: string | null; monthly_rent: number | null; status: string | null }>;
      const available = availableRooms.filter((x) => x.status === 'available');
      const rent = r.monthly_rent ?? available[0]?.monthly_rent ?? 0;
      const imgs = (r.property_images ?? [])
        .filter((i) => i.url)
        .sort((a, b) => (a.sort_order ?? 0) - (b.sort_order ?? 0));
      const landlordName = r.landlord_id
        ? (landlordNames.get(r.landlord_id) ?? 'Property Owner')
        : 'Property Owner';
      return {
        id: r.id,
        name: r.name ?? 'Boarding House',
        address: r.address ?? '—',
        type,
        typeLabel: roomTypeLabel(type),
        rent,
        image: imgs[0]?.url ?? 'https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?w=600&h=300&fit=crop',
        isFavorited: false,
        landlordName,
        landlordInitials: initialsOf(landlordName),
        landlordId: r.landlord_id ?? null,
        description: r.description ?? null,
        availableRooms: available.length,
        roomsList: available.map((x) => ({
          id: x.id,
          roomNumber: x.room_number ?? 'Room',
          rent: (x.monthly_rent as number | null) ?? null,
          type,
        })),
        propertyId: r.id,
      };
    });
  } catch (e) {
    error.value = e instanceof Error ? e.message : 'Failed to load properties';
  } finally {
    loading.value = false;
  }
}

onMounted(loadProperties);
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
