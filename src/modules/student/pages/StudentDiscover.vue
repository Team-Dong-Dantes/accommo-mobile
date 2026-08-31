<template>
  <q-page class="bg-grey-1 q-pb-xl">
    <!-- PROPERTY LIST VIEW -->
    <div v-if="!selectedProperty && !selectedLandlord" class="q-pa-md">
      <div class="row q-col-gutter-sm q-mb-md">
        <div class="col">
          <q-input v-model="searchQuery" outlined rounded dense placeholder="Search rooms, barangay, type..." bg-color="white" color="dark" class="search-input">
            <template v-slot:prepend>
              <q-icon name="search" size="20px" class="q-ml-sm text-grey-5" />
            </template>
          </q-input>
        </div>
        <div class="col-auto">
          <q-btn outline rounded color="grey-4" text-color="dark" icon="tune" label="Filter" no-caps class="bg-white q-px-sm" @click="filterDialog = true" />
        </div>
      </div>

      <template v-if="loading">
        <q-skeleton height="280px" square class="q-mb-md border-radius-24" />
        <q-skeleton height="280px" square class="q-mb-md border-radius-24" />
      </template>

      <template v-else-if="error">
        <div class="text-negative text-center q-py-xl">{{ error }}</div>
      </template>

      <template v-else>
        <div class="text-h6 text-weight-bold q-mb-md q-mt-sm" style="font-size: 1.1rem">
          Available Rooms <span class="text-teal-8">({{ filteredProperties.length }})</span>
        </div>

        <div v-if="filteredProperties.length === 0" class="text-center text-grey-6 q-py-xl">
          No properties match your filters.
        </div>

        <q-card v-for="property in filteredProperties" :key="property.id" flat class="q-mb-lg custom-card overflow-hidden border-radius-24">
          <q-img :src="property.image" height="200px">
            <div class="absolute-top-left bg-transparent q-pa-sm">
              <q-chip 
                dense 
                size="12px" 
                class="text-weight-bold bg-white q-px-sm shadow-1" 
                :text-color="getTypeColor(property.type)" 
                :icon="getTypeIcon(property.type)">
                {{ property.typeLabel }}
              </q-chip>
            </div>
            <div class="absolute-top-right bg-transparent q-pa-sm">
              <q-btn
                round
                unelevated
                size="sm"
                :icon="property.isFavorited ? 'favorite' : 'favorite_border'"
                :color="property.isFavorited ? 'red-5' : 'grey-5'"
                class="bg-white shadow-1"
                @click.stop="toggleFavorite(property)"
              />
            </div>
            <div class="absolute-bottom bg-transparent q-pa-md row justify-between items-end" style="background: linear-gradient(180deg, transparent 0%, rgba(0,0,0,0.8) 100%);">
              <div>
                <div class="text-h6 text-weight-bold text-white line-height-tight">{{ property.name }}</div>
              </div>
              <div class="bg-dark text-white q-px-sm q-py-xs text-weight-bold text-caption border-radius-12">
                {{ property.rent ? formatPeso(property.rent) + '/mo' : 'Price on request' }}
              </div>
            </div>
          </q-img>
          <q-card-section class="q-pa-md bg-white">
            <div class="text-caption text-grey-5 row items-center q-mb-sm">
              <q-icon name="location_on" size="14px" class="q-mr-xs" />
              {{ property.address }}
            </div>
            
            <div class="row items-center justify-between q-mb-md">
              <div class="row q-gutter-x-xs">
                <div class="amenity-chip text-teal-8 bg-teal-1"><q-icon name="wifi" size="12px" class="q-mr-xs"/> WiFi</div>
                <div class="amenity-chip text-blue-8 bg-blue-1"><q-icon name="water_drop" size="12px" class="q-mr-xs"/> Water</div>
                <div class="amenity-chip text-orange-8 bg-orange-1"><q-icon name="bolt" size="12px" class="q-mr-xs"/> Electric</div>
                <div v-if="property.type === 'solo'" class="amenity-chip text-purple-8 bg-purple-1"><q-icon name="ac_unit" size="12px" class="q-mr-xs"/> Aircon</div>
              </div>
              <div class="text-xs text-grey-5">Floor 1 · 1 slot left</div>
            </div>
            
            <div class="row items-center justify-between q-pt-sm" style="border-top: 1px solid #f0f0f0">
              <div class="row items-center">
                <q-avatar size="28px" color="teal-8" text-color="white" class="text-weight-bold text-caption">{{ property.landlordInitials }}</q-avatar>
                <span class="text-weight-bold text-caption text-dark q-ml-sm">{{ property.landlordName }}</span>
              </div>
              <q-btn unelevated color="dark" label="View Details" class="border-radius-16 text-caption text-weight-bold q-px-md" no-caps @click="openProperty(property)" />
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
      <q-card flat class="q-ma-sm custom-card overflow-hidden border-radius-24">
        <q-img :src="heroImage" height="220px">
          <div class="absolute-top q-pa-sm row q-gutter-xs bg-transparent">
            <q-chip dense size="12px" class="text-weight-bold bg-white shadow-1" :text-color="getTypeColor(selectedProperty.type)" :icon="getTypeIcon(selectedProperty.type)">
              {{ selectedProperty.typeLabel }}
            </q-chip>
            <q-chip v-if="roomDetail?.status === 'accredited'" color="teal-8" text-color="white" dense icon="verified" size="12px" class="text-weight-bold shadow-1">OSAS Verified</q-chip>
          </div>
          <div class="absolute-top-right q-pa-sm bg-transparent">
            <q-btn
              round unelevated size="sm"
              :icon="selectedProperty.isFavorited ? 'favorite' : 'favorite_border'"
              :color="selectedProperty.isFavorited ? 'red-5' : 'grey-5'"
              class="bg-white shadow-1"
              @click="toggleFavorite(selectedProperty)"
            />
          </div>
          <div class="absolute-bottom bg-transparent q-pa-md row justify-between items-end" style="background: linear-gradient(180deg, transparent, rgba(0,0,0,0.8));">
            <div>
              <div class="text-h6 text-weight-bold text-white line-height-tight">{{ selectedProperty.name }}</div>
              <div class="text-caption text-grey-3">{{ selectedProperty.address }}</div>
            </div>
            <div class="bg-dark text-white q-px-sm q-py-xs text-weight-bold border-radius-12 text-caption">
              {{ selectedProperty.rent ? formatPeso(selectedProperty.rent) + '/mo' : 'Price on request' }}
            </div>
          </div>
        </q-img>
      </q-card>

      <!-- Type Card -->
      <q-card flat bordered class="q-mx-sm q-my-sm rounded-borders" style="background:#FFF3E0; border-color: rgba(0,0,0,0.05)">
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
        <q-list bordered separator class="border-radius-16 overflow-hidden">
          <q-item v-for="rm in selectedProperty.roomsList" :key="rm.id">
            <q-item-section>
              <div class="text-weight-bold">Room {{ rm.roomNumber }}</div>
            </q-item-section>
            <q-item-section side>
              <div class="text-weight-bold text-dark">{{ rm.rent ? formatPeso(rm.rent) + '/mo' : 'Price on request' }}</div>
            </q-item-section>
          </q-item>
        </q-list>
      </div>

      <!-- Amenities -->
      <div class="q-px-md q-mt-lg">
        <div class="text-caption text-grey-6 text-weight-bold q-mb-sm letter-spacing-1">AMENITIES INCLUDED</div>
        <div v-if="detailLoading" class="text-caption text-grey-6">Loading…</div>
        <div v-else-if="(roomDetail?.amenities?.length ?? 0) === 0" class="text-caption text-grey-6">No amenities listed.</div>
        <div v-else class="row q-gutter-sm">
          <q-chip
            v-for="a in (roomDetail?.amenities ?? [])"
            :key="a"
            dense outline
            :color="amenityMeta[a]?.color || 'teal'"
            :icon="amenityMeta[a]?.icon || 'check_circle'"
            size="13px"
            class="bg-white"
          >{{ amenityMeta[a]?.label || a }}</q-chip>
        </div>
      </div>

      <!-- About the Property -->
      <div class="q-px-md q-mt-lg">
        <div class="text-subtitle1 text-weight-bold q-mb-sm">About the Property</div>
        <div class="text-caption text-grey-7 row items-center q-mb-sm">
          <q-icon name="place" color="grey-6" size="16px" class="q-mr-xs" /> {{ selectedProperty.address }}
        </div>
        <p v-if="roomDetail?.description" class="text-body2 text-grey-8">{{ roomDetail?.description }}</p>
        <p v-else class="text-body2 text-grey-6">No description provided for this property.</p>
      </div>

      <!-- Move-in Cost Breakdown -->
      <div class="q-px-md q-mt-lg">
        <div class="text-subtitle1 text-weight-bold q-mb-sm">Move-in Cost Breakdown</div>
        <q-card flat bordered class="border-radius-16 overflow-hidden border-grey-3">
          <q-list dense separator>
            <q-item class="q-py-md">
              <q-item-section>{{ advanceMonths }} Month{{ advanceMonths === 1 ? '' : 's' }} Advance Payment</q-item-section>
              <q-item-section side class="text-weight-bold text-dark">{{ formatPeso(selectedProperty.rent * advanceMonths) }}</q-item-section>
            </q-item>
            <q-item class="q-py-md">
              <q-item-section>{{ depositMonths }} Month{{ depositMonths === 1 ? '' : 's' }} Security Deposit</q-item-section>
              <q-item-section side class="text-weight-bold text-dark">{{ formatPeso(selectedProperty.rent * depositMonths) }}</q-item-section>
            </q-item>
          </q-list>
          <div class="row items-center justify-between q-px-md q-py-md" style="background:#1d1d1d;">
            <span class="text-white text-weight-medium">Total Due at Signing</span>
            <span class="text-white text-weight-bold text-subtitle1">{{ formatPeso(selectedProperty.rent * (advanceMonths + depositMonths)) }}</span>
          </div>
        </q-card>
        <q-banner inline-actions rounded class="q-mt-sm" style="background:#E8F5E9;">
          <template #avatar><q-icon name="info" color="green-8" /></template>
          <span class="text-caption text-green-9">Minimum stay of {{ minStay }} semester{{ minStay === 1 ? '' : 's' }}. Refundable deposit upon contract completion with no damages.</span>
        </q-banner>
      </div>

      <!-- House Policies -->
      <div class="q-px-md q-mt-lg">
        <div class="text-subtitle1 text-weight-bold q-mb-sm">House Policies</div>
        <div v-if="detailLoading" class="text-caption text-grey-6">Loading…</div>
        <div v-else-if="policyCards.length === 0" class="text-caption text-grey-6">No policies listed.</div>
        <div v-else class="row q-col-gutter-sm">
          <div v-for="p in policyCards" :key="p.label" class="col-6">
            <q-card flat class="policy-box q-pa-md" :style="{ background: p.bg }">
              <q-icon :name="p.icon" :color="p.color" size="24px" />
              <div class="text-subtitle2 text-weight-bold q-mt-xs">{{ p.label }}</div>
              <div class="text-caption text-grey-7">{{ p.desc }}</div>
            </q-card>
          </div>
        </div>
      </div>

      <!-- House Rules -->
      <div class="q-px-md q-mt-lg">
        <div v-if="houseRulesList.length" class="q-banner inline-actions rounded q-mb-md" style="background:#FFEBEE;">
          <q-icon name="block" color="red-8" class="q-mr-xs" />
          <span class="text-caption text-red-8 text-weight-medium">{{ houseRulesList.join(' · ') }}</span>
        </div>
        <div class="text-caption text-grey-6 text-weight-bold q-mb-sm letter-spacing-1">HOUSE RULES</div>
        <div v-if="positiveRules.length === 0" class="text-caption text-grey-6">No specific house rules listed.</div>
        <div v-for="rule in positiveRules" :key="rule" class="row items-center q-mb-xs">
          <q-icon name="check_circle" color="green-7" size="18px" class="q-mr-sm" />
          <span class="text-body2 text-grey-8">{{ rule }}</span>
        </div>
      </div>

      <!-- Listed By & CTA -->
      <div class="q-px-md q-mt-lg q-pb-xl">
        <div class="text-caption text-grey-6 text-weight-bold q-mb-sm letter-spacing-1">LISTED BY</div>
        <q-card flat bordered class="border-radius-16 q-mb-md cursor-pointer border-grey-3" @click="openLandlord(selectedProperty)">
          <q-card-section class="row items-center">
            <q-avatar size="48px" color="teal-8" text-color="white" class="text-weight-bold">{{ selectedProperty.landlordInitials }}</q-avatar>
            <div class="q-ml-md col">
              <div class="text-subtitle2 text-weight-bold line-height-tight">{{ roomDetail?.landlord.name ?? selectedProperty.landlordName }}</div>
              <div class="text-caption text-grey-6">{{ landlordResponseLabel }}</div>
            </div>
            <q-btn flat color="teal-8" label="View" no-caps dense class="text-weight-bold" />
          </q-card-section>
        </q-card>
        <q-btn unelevated color="dark" icon="chat_bubble_outline" label="Message to Inquire" class="full-width border-radius-16 text-weight-bold q-py-sm" size="16px" no-caps @click="inquire(selectedProperty)" />
        <q-btn unelevated color="teal-8" icon="assignment_turned_in" label="Apply to Stay" class="full-width border-radius-16 text-weight-bold q-py-sm q-mt-sm" size="16px" no-caps :loading="applying" @click="applyToStay(selectedProperty)" />
      </div>
    </div>

    <!-- LANDLORD PROFILE VIEW -->
    <div v-else-if="selectedLandlord" class="landlord-profile">
      <div class="q-pa-sm q-pb-none">
        <q-btn flat no-caps color="dark" icon="arrow_back" label="Back to listings" class="text-weight-medium q-px-xs" @click="selectedLandlord = null" />
      </div>

      <div class="q-pa-md">
        <!-- Landlord Info -->
        <div class="row items-center q-mb-lg">
          <q-avatar size="72px" color="teal-8" text-color="white" class="text-weight-bold" style="font-size:28px">{{ selectedLandlord.initials }}</q-avatar>
          <div class="q-ml-md">
            <div class="row items-center">
              <div class="text-h5 text-weight-bold line-height-tight">{{ selectedLandlord.name }}</div>
              <q-icon name="verified" color="green-7" size="22px" class="q-ml-sm" />
            </div>
            <div class="text-body2 text-grey-6">Business Owner</div>
          </div>
        </div>

        <!-- Stats Row -->
        <div class="row q-col-gutter-sm q-mb-lg">
          <div class="col-4">
            <q-card flat class="stat-box">
              <q-card-section class="text-center q-py-sm">
                <div class="text-h6 text-weight-bold">{{ landlordStats.responseRate != null ? Math.round(landlordStats.responseRate * 100) + '%' : '—' }}</div>
                <div class="text-caption text-grey-6" style="font-size: 10px">RESPONSE</div>
              </q-card-section>
            </q-card>
          </div>
          <div class="col-4">
            <q-card flat class="stat-box">
              <q-card-section class="text-center q-py-sm">
                <div class="text-h6 text-weight-bold">{{ landlordStats.avgMin != null ? '~' + landlordStats.avgMin + 'm' : '—' }}</div>
                <div class="text-caption text-grey-6" style="font-size: 10px">RESP. TIME</div>
              </q-card-section>
            </q-card>
          </div>
          <div class="col-4">
            <q-card flat class="stat-box">
              <q-card-section class="text-center q-py-sm">
                <div class="text-h6 text-weight-bold">{{ landlordStats.propertyCount }}</div>
                <div class="text-caption text-grey-6" style="font-size: 10px">PROPERTIES</div>
              </q-card-section>
            </q-card>
          </div>
        </div>

        <!-- Availability Banner -->
        <q-banner inline-actions rounded class="q-mb-lg" style="background:#E8F5E9;border:1px solid #c8e6c9;">
          <template #avatar><q-icon name="check_circle" color="green-8" /></template>
          <span class="text-body2 text-green-9 text-weight-medium">{{ selectedLandlord.availableRooms }} of {{ selectedLandlord.totalRooms }} rooms available</span>
        </q-banner>

        <!-- Action Button -->
        <q-btn unelevated color="dark" icon="chat_bubble_outline" :label="'Message ' + selectedLandlord.firstName" class="full-width border-radius-16 text-weight-bold q-py-sm q-mb-xl" size="16px" no-caps @click="inquireLandlord(selectedLandlord)" />

        <!-- Property List -->
        <div class="text-subtitle1 text-weight-bold q-mb-sm">Properties</div>
        <q-card flat bordered class="border-radius-24 overflow-hidden border-grey-3">
          <q-img :src="selectedLandlord.propertyImage" height="160px" />
          <q-card-section class="q-py-md">
            <div class="text-subtitle1 text-weight-bold">{{ selectedLandlord.propertyName }}</div>
          </q-card-section>
          <q-separator />
          <q-list dense>
            <q-item v-for="room in selectedLandlord.rooms" :key="room.id" class="q-py-sm">
              <q-item-section>
                <div class="row items-center q-gutter-x-sm">
                  <span class="text-weight-bold">{{ room.roomNumber }}</span>
                  <q-chip dense size="11px" :color="room.typeColor" text-color="white" :label="room.type" />
                </div>
              </q-item-section>
              <q-item-section side>
                <div class="text-weight-bold text-dark">{{ formatPeso(room.price) }}</div>
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
          <div class="row justify-center q-mb-md">
            <div class="drag-handle" />
          </div>
          <div class="row items-center justify-between">
            <div class="text-h6 text-weight-bold">Filter Properties</div>
            <q-btn flat round dense icon="close" @click="filterDialog = false" />
          </div>
        </q-card-section>

        <q-card-section>
          <div class="text-caption text-grey-6 text-weight-bold q-mb-sm letter-spacing-1">PROPERTY TYPE</div>
          <div class="row q-gutter-sm q-mb-lg">
            <div v-for="t in roomTypes" :key="t.value" class="col" @click="selectRoomType(t.value)">
              <div
                class="type-box column items-center justify-center q-pa-sm cursor-pointer transition-active"
                :class="selectedRoomType === t.value ? 'bg-grey-2 border-dark' : 'border-grey-3'"
              >
                <q-icon :name="t.icon" :color="t.color" size="24px" />
                <div class="text-caption q-mt-xs text-weight-medium" style="font-size: 11px">{{ t.label }}</div>
              </div>
            </div>
          </div>

          <div class="text-caption text-grey-6 text-weight-bold q-mb-sm letter-spacing-1">MAX MONTHLY PRICE</div>
          <div class="row q-gutter-sm q-mb-lg">
            <q-btn
              v-for="p in priceOptions"
              :key="p.value"
              :label="p.label"
              no-caps dense size="13px"
              :unelevated="selectedPrice === p.value"
              :outline="selectedPrice !== p.value"
              :color="selectedPrice === p.value ? 'dark' : 'grey-4'"
              :text-color="selectedPrice === p.value ? 'white' : 'dark'"
              class="price-pill text-weight-medium"
              @click="selectPrice(p.value)"
            />
          </div>

          <div class="text-caption text-grey-6 text-weight-bold q-mb-sm letter-spacing-1">MUST HAVE</div>
          <div class="row q-gutter-sm q-mb-lg">
            <q-chip
              v-for="a in amenities"
              :key="a.value"
              :outline="!selectedAmenities.includes(a.value)"
              :color="a.color" :icon="a.icon" :label="a.label"
              clickable @click="toggleAmenity(a.value)"
              class="text-weight-medium"
            />
          </div>

          <div class="osas-card row items-center q-px-md q-py-sm q-mb-md">
            <q-icon name="verified" color="green-7" size="22px" class="q-mr-sm" />
            <span class="text-body2 text-weight-medium">OSAS Verified only</span>
            <q-space />
            <q-toggle v-model="osasVerified" color="green-7" />
          </div>
        </q-card-section>

        <q-card-section class="row q-col-gutter-sm q-pt-none q-pb-xl">
          <div class="col-6">
            <q-btn outline color="grey-4" text-color="dark" label="Clear All" no-caps class="full-width border-radius-16 text-weight-bold q-py-sm" @click="clearAll" />
          </div>
          <div class="col-6">
            <q-btn unelevated color="dark" label="Apply Filters" no-caps class="full-width border-radius-16 text-weight-bold q-py-sm" @click="applyFilters" />
          </div>
        </q-card-section>
      </q-card>
    </q-dialog>
  </q-page>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue';
import { useRouter } from 'vue-router';
import { useQuasar } from 'quasar';
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
  landlordId: string | null;
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
  houseRules: string[];
  amenities: string[];
  images: string[];
  landlord: { name: string; responseRate: number | null; avgResponseMinutes: number | null; propertyCount: number };
}

const router = useRouter();
const $q = useQuasar();
const applying = ref(false);

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
  solo: { label: 'Solo', desc: 'Private room for one occupant' },
  duo: { label: 'Double', desc: 'Shared room for two occupants' },
  triple: { label: 'Triple', desc: 'Shared room for three occupants' },
  bedspace: { label: 'Bedspacer', desc: 'Shared bunk / open bed in a multi-pax room' },
  studio: { label: 'Studio', desc: 'Self-contained private studio' },
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

function getTypeIcon(t: string): string {
  if (t === 'solo') return 'person_outline';
  if (t === 'duo') return 'people_outline';
  if (t === 'bedspace') return 'single_bed';
  return 'apartment';
}

function getTypeColor(t: string): string {
  if (t === 'bedspace') return 'orange-8';
  if (t === 'solo') return 'teal-7';
  if (t === 'duo') return 'purple-7';
  return 'dark';
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
  const rules: string[] = [];
  if (p?.cooking) rules.push('Cooking allowed in common kitchen');
  if (p?.laundry) rules.push('Laundry facilities available');
  for (const r of roomDetail.value?.houseRules ?? []) {
    if (r && !rules.includes(r)) rules.push(r);
  }
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

async function applyToStay(property: DiscoverProperty) {
  const room = property.roomsList?.[0]
  if (!room?.id) {
    $q.notify({ type: 'negative', message: 'No available rooms to apply for.' })
    return
  }
  applying.value = true
  try {
    const { data: { user } } = await supabase.auth.getUser()
    if (!user) { void router.push('/login'); return }
    const { error } = await supabase.from('leases').insert({
      id: crypto.randomUUID(),
      student_id: user.id,
      room_id: room.id,
      status: 'pending',
    } as any)
    if (error) throw error
    $q.notify({ type: 'positive', message: 'Application submitted! Wait for the landlord to accept.' })
  } catch (e: any) {
    $q.notify({ type: 'negative', message: e?.message || 'Failed to apply' })
  } finally {
    applying.value = false
  }
}

function inquireLandlord(landlord: LandlordProfile) {
  if (landlord.landlordId) {
    void router.push({ path: '/student/messages', query: { landlord: landlord.landlordId } });
  }
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
    const { data, error: pe } = await supabase
      .from('accommodations' as any)
      .select('description, status, rating_avg, reviews_count, accommodation_manager_id, accommodation_policies(house_rules_json), accommodation_amenities(amenity), accommodation_images(url, sort_order), rooms(id, room_number, monthly_rent, status)')
      .eq('id', property.id)
      .eq('rooms.status', 'available')
      .maybeSingle();

    if (pe) throw pe;

    const prop = data as unknown as {
      description: string | null;
      status: string | null;
      rating_avg: number | null;
      reviews_count: number | null;
      accommodation_manager_id: string | null;
      rooms: Array<{ id: string; room_number: string | null; monthly_rent: number | null; status: string | null }> | null;
      accommodation_amenities: Array<{ amenity: string }> | null;
      accommodation_images: Array<{ url: string | null; sort_order: number | null }> | null;
      accommodation_policies: Array<{ house_rules_json: unknown }> | null;
    } | null;

    let landlord = { name: property.landlordName, responseRate: null as number | null, avgResponseMinutes: null as number | null, propertyCount: 0 };
    if (prop?.accommodation_manager_id) {
      const [pc, usr] = await Promise.all([
        supabase.from('accommodations' as any).select('*', { count: 'exact', head: true }).eq('accommodation_manager_id', prop.accommodation_manager_id),
        supabase.from('users').select('full_name').eq('id', prop.accommodation_manager_id).maybeSingle(),
      ]);
      const userName = (usr.data as { full_name: string | null } | null)?.full_name ?? null;
      // Prefer the property's business_name (carried on property.landlordName); fall back to users.full_name.
      const detailName = property.landlordName !== 'Property Owner' ? property.landlordName : (userName ?? 'Property Owner');
      landlord = { name: detailName, responseRate: null, avgResponseMinutes: null, propertyCount: pc.count ?? 0 };
    }

    const availableRooms = (prop?.rooms ?? []).filter((x) => x.status === 'available');
    const amenitiesRaw = (prop?.accommodation_amenities ?? []) as Array<{ amenity: string }>;
    const imagesRaw = (prop?.accommodation_images ?? []) as Array<{ url: string | null; sort_order: number | null }>;
    const imgs = imagesRaw.filter((i) => i.url).sort((a, b) => (a.sort_order ?? 0) - (b.sort_order ?? 0));

    const policyRaw = (prop?.accommodation_policies ?? []) as Array<{ house_rules_json: unknown }> | null;
    const houseRulesJson = policyRaw?.[0]?.house_rules_json as { rules?: string[] } | null;
    const houseRules = houseRulesJson?.rules ?? [];

    roomDetail.value = {
      description: prop?.description ?? null,
      status: prop?.status ?? null,
      ratingAvg: prop?.rating_avg ?? null,
      reviewsCount: prop?.reviews_count ?? null,
      policy: null,
      houseRules,
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
    const [propsRes, usrRes] = await Promise.all([
      supabase.from('accommodations' as any).select('id, name').eq('accommodation_manager_id', landlordId),
      supabase.from('users').select('full_name').eq('id', landlordId).maybeSingle(),
    ]);

    const userName = (usrRes.data as { full_name: string | null } | null)?.full_name ?? null;
    // Prefer the property's business_name (carried on ctx.name); fall back to users.full_name.
    const businessName = ctx.name !== 'Property Owner' ? ctx.name : (userName ?? 'Property Owner');
    const propertyRows = (propsRes.data ?? []) as unknown as Array<{ id: string; name: string | null }>;

    let roomRows: Array<{ id: string; room_number: string | null; label: string | null; monthly_rent: number | null; capacity: number | null; current_pax: number | null; status: string | null }> = [];
    if (propertyRows.length > 0) {
      const { data: rm } = await supabase
        .from('rooms')
        .select('id, room_number, label, monthly_rent, capacity, current_pax, status')
        .in('accommodation_id', propertyRows.map((p) => p.id));
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
      responseRate: null,
      avgMin: null,
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
      landlordId: landlordId,
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
      .from('accommodations' as any)
      .select('id, name, address, room_type, accommodation_manager_id, description, business_name')
      .eq('status', 'accredited')
      .order('name', { ascending: true });

    if (queryError) throw queryError;

    const accs = (data ?? []) as unknown as Array<{
      id: string;
      name: string | null;
      address: string | null;
      room_type: string | null;
      accommodation_manager_id: string | null;
      description: string | null;
      business_name: string | null;
    }>;
    const accIds = accs.map((a) => a.id);

    // Rooms + images via column-based queries (no fragile relation joins).
    const [roomsRes, imgsRes] = await Promise.all([
      accIds.length
        ? supabase.from('rooms').select('id, accommodation_id, room_number, monthly_rent, status').in('accommodation_id', accIds)
        : Promise.resolve({ data: [], error: null }),
      accIds.length
        ? supabase.from('accommodation_images' as any).select('accommodation_id, url, sort_order').in('accommodation_id', accIds)
        : Promise.resolve({ data: [], error: null }),
    ]);
    if (roomsRes.error) throw roomsRes.error;
    if (imgsRes.error) throw imgsRes.error;
    const roomRows = (roomsRes.data ?? []) as Array<{ id: string; accommodation_id: string; room_number: string | null; monthly_rent: number | null; status: string | null }>;
    const imgRows = (imgsRes.data ?? []) as Array<{ accommodation_id: string; url: string | null; sort_order: number | null }>;

    const landlordIds = Array.from(
      new Set(accs.map((r) => r.accommodation_manager_id).filter((id): id is string => !!id)),
    );

    const userNames = new Map<string, string>();
    if (landlordIds.length > 0) {
      // Display name = business_name (on the accommodation row), falling back to
      // the manager's users.full_name, then "Property Owner".
      const { data: userData, error: userErr } = await supabase
        .from('users').select('id, full_name').in('id', landlordIds);
      for (const u of (userData ?? []) as unknown as Array<{ id: string; full_name: string | null }>) {
        if (u.full_name) userNames.set(u.id, u.full_name);
      }
      if (userErr) console.warn('[discover] users fetch failed:', userErr.message);
    }

    properties.value = accs.map((r) => {
      const type = r.room_type ?? 'room';
      const accRooms = roomRows.filter((x) => x.accommodation_id === r.id);
      const available = accRooms.filter((x) => x.status === 'available');
      const rent = available[0]?.monthly_rent ?? 0;
      const imgs = imgRows
        .filter((i) => i.accommodation_id === r.id && i.url)
        .sort((a, b) => (a.sort_order ?? 0) - (b.sort_order ?? 0));
      const landlordName = r.business_name ?? (r.accommodation_manager_id ? userNames.get(r.accommodation_manager_id) : null) ?? 'Property Owner';
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
        landlordId: r.accommodation_manager_id ?? null,
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
  background: white;
  box-shadow: 0 4px 16px rgba(0, 0, 0, 0.05);
}

.search-input :deep(.q-field__control) {
  border: 1px solid #e0e0e0;
}

.search-input :deep(.q-field__control:before) {
  border: none;
}

.room-detail,
.landlord-profile {
  animation: fadeIn 0.2s ease;
}

.border-radius-24 { border-radius: 24px; }
.border-radius-16 { border-radius: 16px; }
.border-radius-12 { border-radius: 12px; }

.line-height-tight { line-height: 1.2; }
.letter-spacing-1 { letter-spacing: 0.5px; }

.amenity-chip {
  padding: 4px 10px;
  border-radius: 20px;
  font-size: 11px;
  font-weight: 600;
  display: flex;
  align-items: center;
}

.stat-box {
  border-radius: 16px;
  background: #f8f9fa;
  border: 1px solid #f0f0f0;
}

.detail-box {
  border-radius: 16px;
  background: #f8f9fa;
}

.policy-box {
  border-radius: 16px;
}

.filter-card {
  border-radius: 24px 24px 0 0;
  padding-bottom: 24px;
}

.drag-handle {
  width: 48px;
  height: 5px;
  border-radius: 3px;
  background: #e0e0e0;
}

.type-box {
  border: 1.5px solid;
  border-radius: 16px;
  min-height: 72px;
}

.border-dark { border-color: #212121 !important; }
.border-grey-3 { border-color: #eeeeee !important; }

.transition-active { transition: all 0.2s ease; }

.price-pill {
  border-radius: 24px;
  padding: 0 20px;
  min-height: 36px;
}

.osas-card {
  border: 1px solid #e0e0e0;
  border-radius: 16px;
}

@keyframes fadeIn {
  from { opacity: 0; transform: translateY(10px); }
  to { opacity: 1; transform: translateY(0); }
}
</style>