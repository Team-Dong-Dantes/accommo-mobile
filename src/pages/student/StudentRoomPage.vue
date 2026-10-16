<template>
  <q-page class="rp">
    <div v-if="loading" class="stack">
      <q-skeleton type="rect" height="220px" square />
      <div class="sk-body">
        <q-skeleton type="text" width="55%" height="20px" />
        <q-skeleton type="text" width="40%" height="13px" />
        <q-skeleton type="text" width="90px" height="20px" class="sk-pill" />
        <div class="sk-stats">
          <q-skeleton type="text" width="60px" height="30px" />
          <q-skeleton type="text" width="60px" height="30px" />
          <q-skeleton type="text" width="60px" height="30px" />
        </div>
      </div>
    </div>

    <div v-else-if="error" class="stack">
      <ErrorCard title="Couldn't load this room" :detail="error" :retry="load" inset />
    </div>

    <div v-else class="page">
      <ListingHero :images="images" :alt="room.label" />

      <div class="body">
        <h1 class="name">{{ room.label }}</h1>
        <button type="button" class="where" @click="router.push(`/student/listing/${room.propertyId}`)">
          <IconifyIcon icon="lucide:building-2" width="12" />
          {{ room.propertyName }}
        </button>
        <div class="badge-row">
          <span class="badge">
            <IconifyIcon icon="lucide:shield-check" width="11" />OSAS Accredited
          </span>
          <span v-if="typeLabel" class="type-pill">{{ typeLabel }}</span>
        </div>

        <div class="price-row">
          <p v-if="room.rent" class="price">{{ formatPeso(room.rent) }}<span class="price-per">/mo{{ perPersonSuffix }}</span></p>
          <p v-else class="price price--none">Rent on request</p>
          <span class="vacancy" :class="room.free ? 'vacancy--ok' : 'vacancy--none'">
            {{ room.free ? 'Available' : 'Taken' }}
          </span>
        </div>

        <div class="stat-row">
          <span v-if="room.capacity" class="stat">
            <IconifyIcon icon="lucide:bed" width="15" />
            <strong>{{ room.capacity }} bed{{ room.capacity === 1 ? '' : 's' }}</strong>
          </span>
          <span v-if="room.floor" class="stat">
            <IconifyIcon icon="lucide:layers" width="15" />
            <strong>{{ room.floorName || `Floor ${room.floor}` }}</strong>
          </span>
          <span v-if="distance" class="stat">
            <IconifyIcon icon="lucide:map-pin" width="15" />
            <!-- campusDistanceLabel already ends in "from campus" -->
            <small>{{ distance }}</small>
          </span>
        </div>

        <!-- What it costs to move in, and how long you're committing to -->
        <ListingBlock v-if="moveIn || policy.contractType" title="Move-in cost">
          <RuleList :rows="moveInRows" />
          <div v-if="moveIn" class="total-strip">
            <span>Total due at signing</span>
            <strong>{{ formatPeso(moveIn.total) }}</strong>
          </div>
        </ListingBlock>

        <!-- How this room's utilities are paid, on top of the rent. Per room:
             two rooms in one house can be billed differently. -->
        <ListingBlock v-if="utilities.length" title="Utilities">
          <RuleList :rows="utilities" />
        </ListingBlock>

        <!-- What's in this room specifically, if anything was published -->
        <ListingBlock v-if="facilities.length" title="In this room">
          <IconGrid :items="facilityItems(facilities)" />
        </ListingBlock>

        <!-- Amenities are property-level; a room has no set of its own -->
        <ListingBlock v-if="amenities.length" title="What's here">
          <IconGrid :items="amenityItems(amenities)" />
        </ListingBlock>

        <!-- Property context for anyone who lands on a room without ever
             seeing the listing first (a search result, a shared link) -->
        <ListingBlock v-if="listingDescription" :title="`About ${room.propertyName}`">
          <p class="desc">{{ listingDescription }}</p>
          <button type="button" class="see-listing" @click="router.push(`/student/listing/${room.propertyId}`)">
            See full listing
            <IconifyIcon icon="lucide:chevron-right" width="14" />
          </button>
        </ListingBlock>

        <!-- Other rooms in the same property, without backing out to the listing -->
        <ListingBlock v-if="visibleSiblingRooms.length" :title="`More rooms at ${room.propertyName}`">
          <RoomRail :rooms="visibleSiblingRooms" />
        </ListingBlock>

        <!-- The person to ask -->
        <LandlordBlock v-if="manager.id" :manager="manager" />
      </div>
    </div>

    <div v-if="!loading && !error && manager.id" class="cta">
      <span v-if="myLease.onThisRoom" class="cta-note">Applied — awaiting response</span>
      <span v-else-if="myLease.hasAny" class="cta-note">You already have a stay</span>
      <span v-else-if="!room.free" class="cta-note">This room is taken</span>
      <!-- Applying is a handshake in chat (ask → form → apply → decision); say so
           here, since there is no Apply button to find. -->
      <span v-else class="cta-note">Chat first — the {{ manager.title.toLowerCase() }} sends you an application form</span>
      <button type="button" class="cta-btn cta-btn--ask" @click="goAsk">
        <IconifyIcon icon="lucide:message-circle" width="17" />
        {{ askable ? 'Ask to apply' : 'Ask' }}
      </button>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import ErrorCard from '@/components/shared/ErrorCard.vue'
import IconGrid from '@/components/student/listing/IconGrid.vue'
import { Icon as IconifyIcon } from '@iconify/vue'
import LandlordBlock from '@/components/student/listing/LandlordBlock.vue'
import ListingBlock from '@/components/student/listing/ListingBlock.vue'
import ListingHero from '@/components/student/listing/ListingHero.vue'
import RoomRail from '@/components/student/listing/RoomRail.vue'
import RuleList from '@/components/student/listing/RuleList.vue'
import { amenityItems, facilityItems } from '@/utils/listings'
import { computed, onMounted, watch } from 'vue'
import { formatPeso } from '@/utils/format'
import { useRoomDetail } from '@/components/student/listing/roomDetail'

// The room's data lives in components/student/listing/roomDetail.ts; this
// page lays it out with the listing components it shares with StudentListingPage.
const {
  router,
  loading,
  error,
  utilities,
  room,
  images,
  amenities,
  facilities,
  policy,
  manager,
  myLease,
  listingDescription,
  visibleSiblingRooms,
  id,
  typeLabel,
  distance,
  perPersonSuffix,
  moveIn,
  moveInRows,
  load,
} = useRoomDetail()

const askable = computed(() => room.free && !myLease.hasAny)

function goAsk() {
  void router.push(
    askable.value
      ? `/student/messages?to=${manager.id}&room=${id.value}`
      : `/student/messages?to=${manager.id}`,
  )
}

onMounted(load)
// Vue Router reuses this component when navigating from one room straight to
// another (same route, different :id — e.g. the "More rooms" rail below),
// so onMounted alone would leave the page showing the previous room.
watch(id, load)
</script>

<style scoped src="@/components/student/listing/detail.css"></style>

<style scoped>
.rp {
  background: var(--m-bg);
}
.sk-stats {
  display: flex;
  gap: 18px;
  margin-top: 6px;
}
.where {
  display: inline-flex;
  align-self: flex-start;
  align-items: center;
  gap: 4px;
  margin: 5px 0 0;
  padding: 0;
  border: 0;
  background: transparent;
  color: var(--m-primary-dark);
  cursor: pointer;
  font: inherit;
  font-size: 13.5px;
  font-weight: 600;
  -webkit-tap-highlight-color: transparent;
}
.price-row {
  display: flex;
  align-items: baseline;
  justify-content: space-between;
  gap: 12px;
  margin-top: 16px;
  padding-top: 16px;
  border-top: 1px solid var(--m-border);
}
.price {
  margin: 0;
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 27px;
  font-weight: 700;
  letter-spacing: -0.02em;
}
.price--none {
  color: var(--m-muted);
  font-family: var(--m-font-body);
  font-size: 14px;
  font-weight: 600;
}
.price-per {
  font-size: 13px;
  font-weight: 600;
  opacity: 0.7;
}
.stat-row {
  display: flex;
  flex-wrap: wrap;
  gap: 8px 18px;
  margin-top: 12px;
}
.total-strip {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  margin-top: 4px;
  padding: 12px 14px;
  border-radius: var(--m-radius-sm);
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
  font-size: 13.5px;
  font-weight: 700;
}
.total-strip strong {
  font-family: var(--m-font-display);
  font-size: 16px;
}
/* About the property */
.desc {
  margin: 0;
  color: var(--m-text);
  font-size: 13.5px;
  line-height: 1.55;
  text-wrap: pretty;
}
.see-listing {
  display: inline-flex;
  align-self: flex-start;
  align-items: center;
  gap: 2px;
  margin-top: 2px;
  padding: 0;
  border: 0;
  background: transparent;
  color: var(--m-primary-dark);
  cursor: pointer;
  font: inherit;
  font-size: 13px;
  font-weight: 700;
  -webkit-tap-highlight-color: transparent;
}
.cta {
  position: fixed;
  right: 0;
  bottom: 0;
  left: 0;
  z-index: 5;
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 10px var(--m-page-gutter) calc(10px + env(safe-area-inset-bottom));
  border-top: 1px solid var(--m-border);
  background: var(--m-surface);
}
.cta-btn {
  display: inline-flex;
  flex: 1;
  align-items: center;
  justify-content: center;
  gap: 7px;
  min-height: 46px;
  padding: 0 16px;
  border: 0;
  border-radius: 999px;
  background: var(--m-primary);
  color: #fff;
  cursor: pointer;
  font: inherit;
  font-size: 14px;
  font-weight: 700;
  -webkit-tap-highlight-color: transparent;
}
/* Sits on the right whether or not a note shares the bar with it. */
.cta-btn--ask {
  flex: 0 0 auto;
  margin-left: auto;
  padding: 0 24px;
}
.cta-note {
  flex: 1;
  padding: 0 8px;
  color: var(--m-muted);
  font-size: 12.5px;
  font-weight: 600;
  text-align: left;
}
</style>
