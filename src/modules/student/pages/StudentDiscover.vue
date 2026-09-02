<template>
  <q-page class="discover-page">
    <!-- ==============================================================
         1. MAIN BROWSE VIEW (FACEBOOK MARKETPLACE / FEED STYLE)
         ============================================================== -->
    <main v-if="view === 'browse'" class="browse-content">
      <!-- Minimal Category Header Strip -->
      <div class="fb-top-tabs">
        <button
          v-for="tab in browseTabs"
          :key="tab.id"
          type="button"
          class="fb-category-chip"
          :class="{ active: browseMode === tab.id }"
          @click="browseMode = tab.id"
        >
          <IconifyIcon :icon="tab.icon" width="16" />
          <span>{{ tab.label }}</span>
        </button>
      </div>

      <div class="fb-feed-meta">
        <span>{{ resultCount }} {{ resultNoun }}</span>
        <button v-if="hasFilters" type="button" class="filter-clear-link" @click="clearFilters">Reset filters</button>
      </div>

      <section v-if="loading" class="fb-post-feed">
        <div v-for="n in 3" :key="n" class="fb-skeleton-post" />
      </section>

      <section v-else-if="error" class="browse-state browse-state--error">
        <IconifyIcon icon="lucide:alert-circle" width="32" />
        <strong>Couldn't load listings</strong>
        <span>{{ error }}</span>
        <button type="button" class="retry-pill" @click="loadData">Try again</button>
      </section>

      <!-- ==============================================================
           ROOMS: 2-COLUMN FACEBOOK MARKETPLACE PRODUCT GRID
           ============================================================== -->
      <section v-else-if="browseMode === 'rooms'" class="fb-marketplace-grid">
        <article
          v-for="room in filteredRooms"
          :key="room.id"
          class="fb-marketplace-item"
          @click="openRoom(room)"
        >
          <!-- Square Photo Container -->
          <div class="fb-item-photo-wrap">
            <q-img
              v-if="room.images.length"
              :src="room.images[0]"
              :alt="room.label"
              fit="cover"
              class="fb-item-img"
            />
            <div v-else class="fb-item-photo-placeholder">
              <IconifyIcon icon="lucide:bed-double" width="36" />
            </div>
            <span class="fb-price-pill font-mono">{{ formatPeso(room.rent || 0) }}</span>
          </div>

          <!-- Product Details Body -->
          <div class="fb-item-details">
            <strong class="fb-item-title">{{ room.label }}</strong>
            <p class="fb-item-location">
              <IconifyIcon icon="lucide:map-pin" width="12" />
              <span>{{ room.address || 'Echague' }}</span>
            </p>
            <div class="fb-item-footer">
              <span class="fb-room-type">{{ room.typeLabel }}</span>
              <span class="fb-slots-tag">{{ room.openSlots }} open</span>
            </div>
          </div>
        </article>
      </section>

      <!-- ==============================================================
           PROPERTIES: FACEBOOK FEED POST STYLE
           ============================================================== -->
      <section v-else-if="browseMode === 'properties'" class="fb-post-feed">
        <article
          v-for="prop in filteredProperties"
          :key="prop.id"
          class="fb-post-card"
          @click="openProperty(prop)"
        >
          <!-- Post Author Top Header -->
          <div class="fb-post-header">
            <q-avatar size="40px" class="fb-post-avatar">{{ initialsOf(prop.managerName) }}</q-avatar>
            <div class="fb-author-details">
              <div class="fb-author-row">
                <strong class="fb-author-name">{{ prop.managerName }}</strong>
                <span class="fb-verified-dot"><IconifyIcon icon="lucide:badge-check" width="14" /></span>
              </div>
              <span class="fb-post-time">Accommo Verified Manager · {{ prop.address }}</span>
            </div>
          </div>

          <!-- Property Name & Content -->
          <div class="fb-post-caption">
            <strong>{{ prop.name }}</strong>
            <p v-if="prop.description">{{ prop.description }}</p>
          </div>

          <!-- Large Post Photo -->
          <div class="fb-post-media">
            <q-img v-if="prop.images.length" :src="prop.images[0]" :alt="prop.name" fit="cover" class="fb-media-img" />
            <div v-else class="fb-media-placeholder"><IconifyIcon icon="lucide:building-2" width="48" /></div>
          </div>

          <!-- Post Footer Bar -->
          <div class="fb-post-footer">
            <div class="fb-post-stat">
              <IconifyIcon icon="lucide:door-open" width="16" class="text-teal" />
              <span>{{ prop.availableRooms }} rooms available</span>
            </div>
            <button type="button" class="fb-view-btn">
              <span>View Property</span>
              <IconifyIcon icon="lucide:chevron-right" width="16" />
            </button>
          </div>
        </article>
      </section>

      <!-- ==============================================================
           MANAGERS: FACEBOOK CONTACTS / PROFILE DIRECTORY
           ============================================================== -->
      <section v-else-if="browseMode === 'managers'" class="fb-contacts-feed">
        <article
          v-for="mgr in filteredManagers"
          :key="mgr.id"
          class="fb-contact-row"
          @click="openManager(mgr)"
        >
          <div class="fb-avatar-wrap">
            <q-avatar size="52px" class="fb-mgr-avatar">{{ initialsOf(mgr.name) }}</q-avatar>
            <span class="fb-online-badge" />
          </div>

          <div class="fb-contact-info">
            <div class="fb-contact-name-row">
              <strong class="fb-contact-name">{{ mgr.name }}</strong>
              <span class="fb-badge-seal"><IconifyIcon icon="lucide:shield-check" width="13" /> Verified</span>
            </div>
            <span class="fb-contact-sub">{{ mgr.propertyCount }} managed properties · {{ mgr.availableRooms }} rooms</span>
            <span class="fb-contact-reply font-mono">98% response rate</span>
          </div>

          <IconifyIcon icon="lucide:chevron-right" width="18" class="text-grey-5" />
        </article>
      </section>

      <EmptyState v-if="!loading && activeResults.length === 0" icon="lucide:search-x" :title="searchQuery || hasFilters ? 'No matching results' : `No ${resultNoun} available`" />

      <!-- Fixed bottom search bar -->
      <div class="discover-action-bar">
        <button type="button" class="filter-icon-button" aria-label="Filter results" @click="filterDialog = true"><IconifyIcon icon="mdi:tune" width="21" aria-hidden="true" /></button>
        <label class="search-field" for="discover-search">
          <IconifyIcon icon="lucide:search" width="20" aria-hidden="true" />
          <span class="sr-only">Search</span>
          <input id="discover-search" v-model="searchQuery" type="search" autocomplete="off" placeholder="Search Marketplace" />
          <button v-if="searchQuery" type="button" class="clear-search" aria-label="Clear search" @click="searchQuery = ''"><IconifyIcon icon="lucide:x" width="18" /></button>
        </label>
      </div>
    </main>

    <!-- Property Detail View (full-screen, mirrors the room flow) -->
    <main v-else-if="view === 'property' && selectedProperty" class="property-workspace">
      <!-- Full-bleed hero carousel -->
      <div class="room-hero-gallery property-hero">
        <q-carousel
          v-if="selectedProperty.images.length"
          v-model="selectedProperty.activePhoto"
          animated swipeable navigation infinite control-color="white"
          class="room-carousel"
        >
          <q-carousel-slide v-for="(image, index) in selectedProperty.images" :key="image" :name="index" class="carousel-slide q-pa-none">
            <q-img :src="image" fit="cover" class="carousel-image" />
          </q-carousel-slide>
        </q-carousel>
        <div v-else class="room-hero-placeholder">
          <IconifyIcon icon="lucide:building-2" width="54" />
          <span>No exterior photos uploaded yet</span>
        </div>
        <div class="gallery-overlay-top">
          <button type="button" class="gallery-round-btn" aria-label="Back to listings" @click="backToBrowse"><IconifyIcon icon="lucide:arrow-left" width="20" /></button>
          <button type="button" class="gallery-round-btn" aria-label="View manager profile" @click="openManagerById(selectedProperty.managerId)"><IconifyIcon icon="lucide:user" width="19" /></button>
        </div>
        <div v-if="selectedProperty.images.length > 1" class="photo-counter-badge font-mono">
          {{ selectedProperty.activePhoto + 1 }} / {{ selectedProperty.images.length }}
        </div>
      </div>

      <!-- Continuous divider-separated flow -->
      <div class="room-flow-container">
        <!-- Header -->
        <header class="flow-section room-header-block property-header">
          <div class="header-left">
            <span class="room-type-tag">{{ selectedProperty.typeLabel }}</span>
            <h1 class="room-name property-name">{{ selectedProperty.name }}</h1>
            <span class="property-accredited"><IconifyIcon icon="lucide:badge-check" width="14" /> OSAS Accredited</span>
            <p class="room-prop-link property-addr">
              <IconifyIcon icon="lucide:map-pin" width="15" />
              <span>{{ selectedProperty.address || 'Echague, Isabela' }}</span>
            </p>
          </div>
          <div class="header-right property-occupancy font-mono">
            <strong>{{ selectedProperty.availableRooms }}</strong>
            <small>{{ selectedProperty.availableRooms === 1 ? 'room open' : 'rooms open' }}</small>
          </div>
        </header>

        <!-- Available rooms -->
        <section v-if="selectedProperty.rooms.length" class="flow-section">
          <h2 class="section-title">Available Rooms</h2>
          <div class="property-room-list">
            <button
              v-for="room in selectedProperty.rooms"
              :key="room.id"
              type="button"
              class="property-room-row"
              @click="openRoom(room)"
            >
              <span class="property-room-icon"><IconifyIcon icon="lucide:bed-double" width="19" /></span>
              <span class="property-room-copy">
                <strong>{{ room.label }}</strong>
                <small>{{ room.typeLabel }}{{ room.capacity ? ` · ${room.capacity} ${room.capacity === 1 ? 'person' : 'persons'}` : '' }}</small>
              </span>
              <strong class="font-mono property-room-price">{{ priceLabel(room.rent) }}</strong>
              <IconifyIcon icon="lucide:chevron-right" width="18" class="property-room-chevron" />
            </button>
          </div>
        </section>

        <!-- About -->
        <section v-if="selectedProperty.description" class="flow-section">
          <h2 class="section-title">About this property</h2>
          <p class="property-bio">{{ selectedProperty.description }}</p>
        </section>

        <!-- Amenities -->
        <section v-if="selectedProperty.amenities.length" class="flow-section">
          <h2 class="section-title">Amenities</h2>
          <div class="inclusions-grid">
            <div v-for="amenity in selectedProperty.amenities" :key="amenity" class="inclusion-item">
              <IconifyIcon icon="lucide:check" width="16" class="text-teal" />
              <span>{{ amenity }}</span>
            </div>
          </div>
        </section>

        <!-- Policies & lease terms -->
        <section v-if="selectedProperty.policyItems.length" class="flow-section">
          <h2 class="section-title">House Policies &amp; Lease Terms</h2>
          <div class="property-policy-list">
            <div v-for="policy in selectedProperty.policyItems" :key="policy" class="property-policy-item">
              <IconifyIcon icon="lucide:shield-check" width="16" class="text-teal" />
              <span>{{ policy }}</span>
            </div>
          </div>
          <p class="cost-terms">Minimum stay and contract terms are agreed with the manager when you apply.</p>
        </section>

        <!-- Listed by -->
        <section class="flow-section">
          <h2 class="section-title">Listed by</h2>
          <div class="manager-profile-row">
            <q-avatar size="48px" class="manager-avatar">{{ initialsOf(selectedProperty.managerName) }}</q-avatar>
            <div class="manager-info">
              <strong class="manager-name">{{ selectedProperty.managerName }}</strong>
              <span class="manager-rating">{{ selectedProperty.managerPropertyCount }} managed accommodation{{ selectedProperty.managerPropertyCount === 1 ? '' : 's' }}</span>
            </div>
          </div>
          <button type="button" class="btn-chat-manager" @click="openManagerById(selectedProperty.managerId)">
            <IconifyIcon icon="lucide:user" width="18" />
            <span>View Manager Profile</span>
          </button>
        </section>
      </div>
    </main>

    <!-- ==============================================================
         2. FULL-SCREEN ROOM DETAILS (FULL BLEED 360px & FLOW)
         ============================================================== -->
    <main v-else-if="view === 'room' && selectedRoom" class="room-workspace">
      <!-- Full-Bleed 360px Edge-to-Edge Hero Carousel -->
      <div class="room-hero-gallery">
        <q-carousel
          v-if="selectedRoom.images.length"
          v-model="selectedRoom.activePhoto"
          animated
          swipeable
          navigation
          infinite
          control-color="white"
          class="room-carousel"
        >
          <q-carousel-slide v-for="(image, index) in selectedRoom.images" :key="image" :name="index" class="carousel-slide q-pa-none">
            <q-img :src="image" fit="cover" class="carousel-image" />
          </q-carousel-slide>
        </q-carousel>
        <div v-else class="room-hero-placeholder">
          <IconifyIcon icon="lucide:bed-double" width="54" />
          <span>No interior photos uploaded yet</span>
        </div>

        <!-- Floating Top Overlay Actions -->
        <div class="gallery-overlay-top">
          <button type="button" class="gallery-round-btn" aria-label="Back" @click="backFromRoom">
            <IconifyIcon icon="lucide:arrow-left" width="20" />
          </button>
          <button type="button" class="gallery-round-btn" aria-label="Share" @click="shareRoom(selectedRoom)">
            <IconifyIcon icon="lucide:share-2" width="18" />
          </button>
        </div>

        <!-- Counter Pill -->
        <div v-if="selectedRoom.images.length" class="photo-counter-badge font-mono">
          {{ selectedRoom.activePhoto + 1 }} / {{ selectedRoom.images.length }}
        </div>
      </div>

      <!-- Clean Divider-Separated Continuous Flow (No Cards, No Radius) -->
      <div class="room-flow-container">
        <!-- 1. Headline & Rent Header -->
        <header class="flow-section room-header-block">
          <div class="header-left">
            <span class="room-type-tag">{{ selectedRoom.typeLabel }}</span>
            <h1 class="room-name">{{ selectedRoom.label }}</h1>
            <p class="room-prop-link" @click="openProperty(propertyById(selectedRoom.propertyId))">
              <IconifyIcon icon="lucide:building-2" width="15" />
              <span>{{ selectedRoom.propertyName }}</span>
              <IconifyIcon icon="lucide:chevron-right" width="14" />
            </p>
          </div>
          <div class="header-right font-mono">
            <strong>{{ formatPeso(selectedRoom.rent || 0) }}</strong>
            <small>/ month</small>
          </div>
        </header>

        <!-- 2. Room Specifications Strip -->
        <section class="flow-section">
          <h2 class="section-title">Room Details</h2>
          <div class="spec-table font-mono">
            <div class="spec-row">
              <span class="spec-key">Floor Level</span>
              <strong class="spec-val">{{ selectedRoom.floor || '1st Floor' }}</strong>
            </div>
            <div class="spec-row">
              <span class="spec-key">Capacity</span>
              <strong class="spec-val">{{ selectedRoom.capacity || 1 }} {{ (selectedRoom.capacity || 1) === 1 ? 'person' : 'persons' }}</strong>
            </div>
            <div class="spec-row">
              <span class="spec-key">Open Slots</span>
              <strong class="spec-val text-teal">{{ selectedRoom.openSlots || 1 }} available</strong>
            </div>
            <div class="spec-row">
              <span class="spec-key">Bathroom</span>
              <strong class="spec-val">{{ selectedRoom.bathroomType || 'Common / Shared Bath' }}</strong>
            </div>
          </div>
        </section>

        <!-- 3. Amenities Included -->
        <section class="flow-section">
          <h2 class="section-title">Amenities Included</h2>
          <div class="inclusions-grid">
            <div class="inclusion-item">
              <IconifyIcon icon="lucide:wifi" width="17" class="text-teal" />
              <span>WiFi Included</span>
            </div>
            <div class="inclusion-item">
              <IconifyIcon icon="lucide:droplet" width="17" class="text-teal" />
              <span>Water Included</span>
            </div>
            <div class="inclusion-item">
              <IconifyIcon icon="lucide:zap" width="17" class="text-teal" />
              <span>Electricity Submetered</span>
            </div>
            <div class="inclusion-item">
              <IconifyIcon icon="lucide:wind" width="17" class="text-teal" />
              <span>Air Conditioning / Fan</span>
            </div>
            <div class="inclusion-item">
              <IconifyIcon icon="lucide:utensils" width="17" class="text-teal" />
              <span>Common Kitchen</span>
            </div>
            <div class="inclusion-item">
              <IconifyIcon icon="lucide:shield-check" width="17" class="text-teal" />
              <span>CCTV & Gated Security</span>
            </div>
          </div>
        </section>

        <!-- 4. Move-in Financial Breakdown -->
        <section class="flow-section">
          <h2 class="section-title">Move-in Cost Breakdown</h2>
          <div class="cost-table font-mono">
            <div class="cost-row">
              <div class="cost-desc">
                <strong>1 Month Advance Payment</strong>
                <small>Covers first month(s) of rent</small>
              </div>
              <span class="cost-val">{{ formatPeso(selectedRoom.rent || 0) }}</span>
            </div>
            <div class="cost-row">
              <div class="cost-desc">
                <strong>1 Month Security Deposit</strong>
                <small>Refundable at end of lease term</small>
              </div>
              <span class="cost-val">{{ formatPeso(selectedRoom.rent || 0) }}</span>
            </div>
            <div class="cost-row cost-row--total">
              <div class="cost-desc">
                <strong>Total Due at Signing</strong>
                <small>Required upon lease finalization</small>
              </div>
              <strong class="cost-val text-teal">{{ formatPeso((selectedRoom.rent || 0) * 2) }}</strong>
            </div>
          </div>
          <p class="cost-terms">
            Minimum stay: 1 semester (5 months). Contract: Fixed-term (semestral or annual).
          </p>
        </section>

        <!-- 5. House Policies & Rules -->
        <section class="flow-section">
          <h2 class="section-title">House Policies</h2>
          <div class="policy-list-clean">
            <div class="policy-line">
              <strong class="policy-label">Quiet Hours</strong>
              <span class="policy-desc">10:00 PM – 6:00 AM daily</span>
            </div>
            <div class="policy-line">
              <strong class="policy-label">Curfew</strong>
              <span class="policy-desc">11:00 PM weekdays · 12:00 AM weekends</span>
            </div>
            <div class="policy-line">
              <strong class="policy-label">Visitors</strong>
              <span class="policy-desc">Common area only, no overnight stays</span>
            </div>
            <div class="policy-line">
              <strong class="policy-label">Cooking</strong>
              <span class="policy-desc">Common kitchen only</span>
            </div>
            <div class="policy-line">
              <strong class="policy-label">Laundry</strong>
              <span class="policy-desc">Designated laundry area</span>
            </div>
            <div class="policy-line">
              <strong class="policy-label">Sub-leasing</strong>
              <span class="policy-desc">Not allowed</span>
            </div>
          </div>
          <div class="prohibit-bar">
            <span>No pets · No smoking inside the property</span>
          </div>
        </section>

        <!-- 6. About the Property & Location -->
        <section class="flow-section">
          <h2 class="section-title">About the Property</h2>
          <p class="property-address font-mono">
            <IconifyIcon icon="lucide:map-pin" width="16" class="text-teal" />
            <span>{{ selectedRoom.address || 'Blk 5, Pinzon Subdivision, Echague' }}</span>
          </p>
          <p class="property-bio">
            Open bunk bed in a multi-pax room with good ventilation, study desks, and immediate proximity to the ISU main gate.
          </p>
        </section>

        <!-- 7. Listed by Manager Profile -->
        <section class="flow-section manager-block">
          <h2 class="section-title">Listed by</h2>
          <div class="manager-profile-row">
            <q-avatar size="48px" class="manager-avatar">{{ initialsOf(selectedRoom.managerName) }}</q-avatar>
            <div class="manager-info">
              <strong class="manager-name">{{ selectedRoom.managerName }}</strong>
              <span class="manager-rating font-mono">98% response rate · Typically replies in 15 mins</span>
            </div>
          </div>
          <button type="button" class="btn-chat-manager" @click="openManagerById(selectedRoom.managerId)">
            <IconifyIcon icon="lucide:user" width="18" />
            <span>View Profile</span>
          </button>
        </section>

        <!-- 8. Other rooms in this property -->
        <section v-if="siblingRooms.length" class="flow-section">
          <div class="section-title-row">
            <h2 class="section-title">Other rooms in this property</h2>
            <button type="button" class="view-all-link" @click="openProperty(propertyById(selectedRoom.propertyId))">View all</button>
          </div>
          <div class="property-room-list">
            <button
              v-for="room in siblingRooms"
              :key="room.id"
              type="button"
              class="property-room-row"
              @click="openRoom(room)"
            >
              <span class="property-room-icon"><IconifyIcon icon="lucide:bed-double" width="19" /></span>
              <span class="property-room-copy">
                <strong>{{ room.label }}</strong>
                <small>{{ room.typeLabel }}{{ room.capacity ? ` · ${room.capacity} ${room.capacity === 1 ? 'person' : 'persons'}` : '' }}</small>
              </span>
              <strong class="font-mono property-room-price">{{ priceLabel(room.rent) }}</strong>
              <IconifyIcon icon="lucide:chevron-right" width="18" class="property-room-chevron" />
            </button>
          </div>
        </section>
      </div>

      <!-- Sticky Floating Action Footer -->
      <footer class="room-action-footer">
        <div class="footer-price-col font-mono">
          <span class="footer-label">Monthly Rent</span>
          <strong class="footer-price">{{ formatPeso(selectedRoom.rent || 0) }}</strong>
        </div>
        <button
          type="button"
          class="btn-apply-booking"
          @click="openRoomChat(selectedRoom)"
        >
          <span>Message Manager</span>
          <IconifyIcon icon="lucide:message-circle" width="18" />
        </button>
      </footer>
    </main>

    <!-- ==============================================================
         3. MANAGER PROFILE DETAIL VIEW
         ============================================================== -->
    <main v-else-if="view === 'manager' && selectedManager" class="manager-workspace">
      <nav class="mgr-nav-top">
        <button type="button" class="mgr-back-btn" @click="backToBrowse">
          <IconifyIcon icon="lucide:arrow-left" width="18" />
          <span>Back</span>
        </button>
        <span class="mgr-nav-title">Manager Profile</span>
        <span class="mgr-nav-space" />
      </nav>

      <div class="mgr-hero-section">
        <q-avatar size="68px" class="mgr-large-avatar">{{ initialsOf(selectedManager.name) }}</q-avatar>
        <h1 class="mgr-profile-name">{{ selectedManager.name }}</h1>
        <span class="mgr-accredited-seal">
          <IconifyIcon icon="lucide:badge-check" width="15" /> OSAS Accredited Accommodation Manager
        </span>

        <div class="mgr-stats-strip font-mono">
          <div class="mgr-stat-cell">
            <span class="stat-num">{{ selectedManager.propertyCount }}</span>
            <small>PROPERTIES</small>
          </div>
          <div class="mgr-stat-cell">
            <span class="stat-num">{{ selectedManager.availableRooms }}</span>
            <small>OPEN ROOMS</small>
          </div>
          <div class="mgr-stat-cell">
            <span class="stat-num text-teal">98%</span>
            <small>RESPONSE</small>
          </div>
        </div>

        <button type="button" class="btn-message-manager-primary" @click="messageManager(selectedManager.id)">
          <IconifyIcon icon="lucide:message-circle" width="18" />
          <span>Direct Message</span>
        </button>
      </div>

      <div class="mgr-properties-container">
        <h2 class="mgr-section-heading font-mono">MANAGED ACCOMMODATIONS ({{ selectedManager.properties.length }})</h2>
        
        <div v-if="selectedManager.properties.length" class="fb-marketplace-grid">
          <article
            v-for="property in selectedManager.properties"
            :key="property.id"
            class="fb-marketplace-item"
            @click="openProperty(property)"
          >
            <div class="fb-item-photo-wrap">
              <q-img v-if="property.images.length" :src="property.images[0]" :alt="property.name" fit="cover" class="fb-item-img" />
              <div v-else class="fb-item-photo-placeholder"><IconifyIcon icon="lucide:building-2" width="36" /></div>
              <span class="fb-price-pill font-mono">{{ property.availableRooms }} rooms</span>
            </div>

            <div class="fb-item-details">
              <strong class="fb-item-title">{{ property.name }}</strong>
              <p class="fb-item-location">
                <IconifyIcon icon="lucide:map-pin" width="12" />
                <span>{{ property.address || 'Echague' }}</span>
              </p>
            </div>
          </article>
        </div>

        <EmptyState
          v-else
          icon="lucide:building-2"
          title="No Listed Accommodations"
          message="This manager has no accredited properties listed at this time."
        />
      </div>
    </main>

    <!-- Filter Sheet -->
    <q-dialog v-model="filterDialog" position="bottom"><q-card class="filter-sheet"><q-card-section class="filter-heading"><div><h2>Filter results</h2></div><q-btn flat round aria-label="Close filters" @click="filterDialog = false"><IconifyIcon icon="lucide:x" width="20" /></q-btn></q-card-section><q-card-section><h3>Room type</h3><div class="filter-options"><q-btn v-for="type in roomTypes" :key="type.value" outline no-caps :class="{ active: selectedRoomType === type.value }" @click="selectedRoomType = selectedRoomType === type.value ? null : type.value">{{ type.label }}</q-btn></div></q-card-section><q-card-actions class="filter-actions"><q-btn flat no-caps @click="clearFilters">Clear</q-btn><q-btn unelevated no-caps class="primary-button" @click="filterDialog = false">Show results</q-btn></q-card-actions></q-card></q-dialog>
  </q-page>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useRouter } from 'vue-router';
import { useQuasar } from 'quasar';
import { supabase } from '@/shared/utils/supabase';
import { formatPeso, initialsOf } from '@/shared/utils/format';
import EmptyState from '@/shared/components/EmptyState.vue';

type BrowseMode = 'properties' | 'rooms' | 'managers';
type View = 'browse' | 'property' | 'room' | 'manager';
interface DiscoverRoom {
  id: string;
  propertyId: string;
  propertyName: string;
  address: string;
  managerId: string;
  managerName: string;
  label: string;
  type: string;
  typeLabel: string;
  rent: number | null;
  images: string[];
  activePhoto: number;
  floor?: string;
  capacity?: number;
  openSlots?: number;
  bathroomType?: string;
}
interface DiscoverProperty {
  id: string;
  name: string;
  address: string;
  type: string;
  typeLabel: string;
  managerId: string;
  managerName: string;
  managerPropertyCount: number;
  description: string | null;
  availableRooms: number;
  rooms: DiscoverRoom[];
  images: string[];
  activePhoto: number;
  amenities: string[];
  policyItems: string[];
}
interface DiscoverManager {
  id: string;
  name: string;
  propertyCount: number;
  availableRooms: number;
  propertyNames: string[];
  properties: DiscoverProperty[];
}

const router = useRouter();
const $q = useQuasar();
const view = ref<View>('browse');
const browseMode = ref<BrowseMode>('rooms');
const searchQuery = ref('');
const filterDialog = ref(false);
const selectedRoomType = ref<string | null>(null);
const loading = ref(true);
const error = ref<string | null>(null);
const applying = ref(false);

const properties = ref<DiscoverProperty[]>([]);
const managers = ref<DiscoverManager[]>([]);
const selectedProperty = ref<DiscoverProperty | null>(null);
const selectedRoom = ref<DiscoverRoom | null>(null);
const selectedManager = ref<DiscoverManager | null>(null);

const browseTabs = [
  { id: 'rooms' as const, label: 'Rooms', icon: 'lucide:bed-double' },
  { id: 'properties' as const, label: 'Properties', icon: 'lucide:building-2' },
  { id: 'managers' as const, label: 'Managers', icon: 'lucide:users' },
];
const roomTypes = [
  { value: 'solo', label: 'Solo' },
  { value: 'duo', label: 'Double' },
  { value: 'triple', label: 'Triple' },
  { value: 'bedspace', label: 'Bedspace' },
  { value: 'studio', label: 'Studio' },
];

function deriveRoomType(capacity: number | null, label: string | null): string {
  const value = (label ?? '').toLowerCase();
  if (value.includes('studio')) return 'studio';
  if ((capacity ?? 1) <= 1) return 'solo';
  if (capacity === 2) return 'duo';
  if (capacity === 3) return 'triple';
  return 'bedspace';
}

function roomTypeLabel(type: string): string {
  return ({ solo: 'Solo Room', duo: '2-Person Room', triple: '3-Person Room', bedspace: 'Bedspace Room', studio: 'Studio Unit' } as Record<string, string>)[type] ?? 'Room';
}

function priceLabel(value: number | null): string {
  return value === null ? 'Price on request' : `${formatPeso(value)} / mo`;
}

const allRooms = computed(() => properties.value.flatMap((property) => property.rooms));
const query = computed(() => searchQuery.value.trim().toLowerCase());
const hasFilters = computed(() => !!query.value || !!selectedRoomType.value);

const filteredProperties = computed(() =>
  properties.value.filter(
    (property) =>
      (!query.value || [property.name, property.address, property.managerName].some((v) => v.toLowerCase().includes(query.value))) &&
      (!selectedRoomType.value || property.rooms.some((room) => room.type === selectedRoomType.value)),
  ),
);

const filteredRooms = computed(() =>
  allRooms.value.filter(
    (room) =>
      (!query.value || [room.label, room.propertyName, room.address, room.managerName].some((v) => v.toLowerCase().includes(query.value))) &&
      (!selectedRoomType.value || room.type === selectedRoomType.value),
  ),
);

const filteredManagers = computed(() =>
  managers.value.filter(
    (manager) => !query.value || [manager.name, ...manager.propertyNames].some((v) => v.toLowerCase().includes(query.value)),
  ),
);

const activeResults = computed(() =>
  browseMode.value === 'properties' ? filteredProperties.value : browseMode.value === 'rooms' ? filteredRooms.value : filteredManagers.value,
);
const resultCount = computed(() => activeResults.value.length);
const resultNoun = computed(() =>
  browseMode.value === 'properties'
    ? resultCount.value === 1 ? 'property' : 'properties'
    : browseMode.value === 'rooms'
    ? resultCount.value === 1 ? 'room' : 'rooms'
    : resultCount.value === 1 ? 'manager' : 'managers',
);

function clearFilters() {
  searchQuery.value = '';
  selectedRoomType.value = null;
  filterDialog.value = false;
}

function propertyById(id: string): DiscoverProperty {
  return properties.value.find((p) => p.id === id) ?? selectedProperty.value!;
}

// Rooms in the same property as the currently-viewed room (excluding it), so
// the student can browse and switch to a sibling room without leaving.
const siblingRooms = computed<DiscoverRoom[]>(() => {
  if (!selectedRoom.value) return []
  const prop = propertyById(selectedRoom.value.propertyId)
  if (!prop) return []
  return prop.rooms.filter((r) => r.id !== selectedRoom.value!.id)
})

function openProperty(property: DiscoverProperty) {
  selectedProperty.value = property;
  selectedRoom.value = null;
  selectedManager.value = null;
  view.value = 'property';
}
function openRoom(room: DiscoverRoom) {
  selectedRoom.value = room;
  selectedManager.value = null;
  view.value = 'room';
}
function openManager(manager: DiscoverManager) {
  selectedManager.value = manager;
  selectedProperty.value = null;
  selectedRoom.value = null;
  view.value = 'manager';
}
function openManagerById(managerId: string) {
  const mgr = managers.value.find((m) => m.id === managerId);
  if (mgr) {
    openManager(mgr);
  } else {
    // Fallback construct manager object
    selectedManager.value = {
      id: managerId,
      name: selectedRoom.value?.managerName || 'Accommodation Manager',
      propertyCount: 1,
      availableRooms: 1,
      propertyNames: selectedRoom.value?.propertyName ? [selectedRoom.value.propertyName] : [],
      properties: selectedProperty.value ? [selectedProperty.value] : [],
    };
    selectedProperty.value = null;
    selectedRoom.value = null;
    view.value = 'manager';
  }
}
function backToBrowse() {
  view.value = 'browse';
  selectedProperty.value = null;
  selectedRoom.value = null;
  selectedManager.value = null;
}
function backFromRoom() {
  if (selectedProperty.value) view.value = 'property';
  else backToBrowse();
}

function messageManager(managerId: string) {
  void router.push({ path: '/student/messages', query: { landlord: managerId } });
}

// Open the convo with the manager, carrying the room context so the student can
// apply from inside the conversation (not from the room details page).
function openRoomChat(room: DiscoverRoom) {
  void router.push({ path: '/student/messages', query: { landlord: room.managerId, room: room.id } });
}

function shareRoom(room: DiscoverRoom) {
  if (navigator.share) {
    navigator.share({
      title: `${room.label} at ${room.propertyName}`,
      text: `Check out this room for ${formatPeso(room.rent || 0)}/mo on Accommo!`,
      url: window.location.href,
    }).catch(() => {});
  } else {
    $q.notify({ message: 'Link copied to clipboard', color: 'positive' });
  }
}

async function applyToRoom(room: DiscoverRoom) {
  applying.value = true;
  try {
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) { void router.push('/login'); return; }

    // Policy: a student must be OSAS-verified before they can apply. Browsing is
    // always allowed; the DB/RLS is the backstop, this only trips the friendly UI.
    const { data: spResult } = await (supabase as any)
      .from('student_profiles')
      .select('osas_verified_at')
      .eq('user_id', user.id)
      .maybeSingle();
    const osasVerifiedAt = spResult?.osas_verified_at ?? null;
    if (!osasVerifiedAt) {
      applying.value = false;
      $q.notify({
        type: 'warning',
        message: 'Verify your enrollment with OSAS before you can apply for a room.',
      });
      void router.push('/student/support'); // Support opens on its OSAS/verification tab by default
      return;
    }

    // The application lives in the student <-> manager conversation. We post a
    // room-request "card" (human text + an @@apply@@ JSON payload) and do NOT
    // create a lease yet; only an Approve (manager side, next step) creates an
    // active lease. This avoids a fake status:'pending' lease.
    const nowIso = new Date().toISOString();
    const endIso = new Date(Date.now() + 150 * 24 * 60 * 60 * 1000).toISOString(); // ~5 months / term

    let convoId: string | null = null;
    const { data: existingConvo } = await (supabase as any)
      .from('conversations')
      .select('id')
      .or(`and(user_a_id.eq.${user.id},user_b_id.eq.${room.managerId}),and(user_a_id.eq.${room.managerId},user_b_id.eq.${user.id})`)
      .maybeSingle();
    if (existingConvo) {
      convoId = existingConvo.id;
    } else {
      const { data: createdConvo, error: cvErr } = await (supabase as any)
        .from('conversations')
        .insert({
          user_a_id: user.id,
          user_b_id: room.managerId,
          last_message: room.label ? `Room request: ${room.label}` : 'Room request',
          last_time: nowIso,
          unread_a: 0,
          unread_b: 1,
        })
        .select('id')
        .single();
      if (cvErr) throw cvErr;
      convoId = createdConvo.id;
    }

    const payload = JSON.stringify({
      kind: 'apply',
      studentId: user.id,
      roomId: room.id,
      label: room.label || '',
      propertyName: room.propertyName || '',
      rent: room.rent || 0,
      startDate: nowIso,
      endDate: endIso,
    });
    const labelled = room.label ? (room.propertyName ? `${room.label} at ${room.propertyName}` : room.label) : 'a room';
    const body = `🎯 Room request — ${labelled}\nPlease review my application. I’m available to discuss the move-in and terms.\n\n@@apply@@\n${payload}`;

    const { error: msgErr } = await (supabase as any).from('messages').insert({
      conversation_id: convoId,
      sender_id: user.id,
      body,
      sent_at: nowIso,
      status: 'sent',
    });
    if (msgErr) throw msgErr;

    $q.notify({ type: 'positive', message: 'Room request sent to the manager. They’ll reply in your chat.' });
    void router.push({ path: '/student/messages', query: { landlord: room.managerId } });
  } catch (cause) {
    $q.notify({ type: 'negative', message: cause instanceof Error ? cause.message : 'Could not submit your application.' });
  } finally {
    applying.value = false;
  }
}

async function loadData() {
  loading.value = true;
  error.value = null;
  try {
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) { void router.push('/login'); return; }

    // 1. Fetch accredited accommodations
    const { data: accommodationData, error: accommodationError } = await (supabase as any)
      .from('accommodations')
      .select('id, name, address, barangay, city, room_type, accommodation_manager_id, description, business_name')
      .eq('status', 'accredited')
      .order('name', { ascending: true });

    if (accommodationError) throw accommodationError;
    const accommodationRecords = accommodationData ?? [];
    const propertyIds = accommodationRecords.map((r: any) => r.id);

    // 2. Fetch rooms & photos
    const [roomResult, imageResult] = await Promise.all([
      propertyIds.length
        ? (supabase as any).from('rooms').select('id, accommodation_id, room_number, label, monthly_rent, capacity, current_pax, floor').in('accommodation_id', propertyIds).eq('status', 'available')
        : Promise.resolve({ data: [], error: null }),
      propertyIds.length
        ? (supabase as any).from('accommodation_images').select('accommodation_id, url, sort_order').in('accommodation_id', propertyIds)
        : Promise.resolve({ data: [], error: null }),
    ]);

    const imagesByProperty = new Map<string, string[]>();
    (imageResult.data ?? []).forEach((img: any) => {
      imagesByProperty.set(img.accommodation_id, [...(imagesByProperty.get(img.accommodation_id) ?? []), img.url]);
    });

    // 3. Query all accommodation_managers from users (database enum is accommodation_manager)
    const { data: allManagers } = await (supabase as any)
      .from('users')
      .select('id, full_name, email, role')
      .eq('role', 'accommodation_manager');

    const userMap = new Map<string, string>();
    (allManagers || []).forEach((u: any) => {
      userMap.set(u.id, u.full_name || u.email || 'Accommodation Manager');
    });

    // Map properties
    const propertyItems: DiscoverProperty[] = accommodationRecords.map((record: any) => {
      const propRooms: DiscoverRoom[] = (roomResult.data ?? [])
        .filter((r: any) => r.accommodation_id === record.id)
        .map((r: any) => {
          const type = deriveRoomType(r.capacity, r.label || r.room_number);
          const capacity = Number(r.capacity) || 1;
          const occupied = Number(r.current_pax) || 0;
          return {
            id: r.id,
            propertyId: record.id,
            propertyName: record.business_name || record.name || 'Accommodation',
            address: record.address || '',
            managerId: record.accommodation_manager_id,
            managerName: userMap.get(record.accommodation_manager_id) || 'Accommodation Manager',
            label: r.label || r.room_number || 'Room',
            type,
            typeLabel: roomTypeLabel(type),
            rent: Number(r.monthly_rent) || 0,
            images: imagesByProperty.get(record.id) || [],
            activePhoto: 0,
            floor: r.floor || '1st Floor',
            capacity,
            openSlots: Math.max(capacity - occupied, 1),
            bathroomType: 'Common / Shared Bath',
          };
        });

      return {
        id: record.id,
        name: record.business_name || record.name || 'Accommodation',
        address: record.address || '',
        type: record.room_type || 'boarding_house',
        typeLabel: 'Boarding House',
        managerId: record.accommodation_manager_id,
        managerName: userMap.get(record.accommodation_manager_id) || 'Accommodation Manager',
        managerPropertyCount: 1,
        description: record.description || null,
        availableRooms: propRooms.length,
        rooms: propRooms,
        images: imagesByProperty.get(record.id) || [],
        activePhoto: 0,
        amenities: ['WiFi Included', 'Water Included', '24/7 CCTV', 'Kitchen Access'],
        policyItems: ['1 Month Advance & 1 Month Deposit', 'Quiet hours 10 PM - 6 AM', 'Visitors in lounge only'],
      };
    });

    properties.value = propertyItems;

    // Build manager list
    const managerListMap = new Map<string, { id: string; name: string; properties: DiscoverProperty[] }>();
    propertyItems.forEach((prop) => {
      if (!managerListMap.has(prop.managerId)) {
        managerListMap.set(prop.managerId, { id: prop.managerId, name: prop.managerName, properties: [] });
      }
      managerListMap.get(prop.managerId)!.properties.push(prop);
    });

    (allManagers || []).forEach((u: any) => {
      if (!managerListMap.has(u.id)) {
        managerListMap.set(u.id, { id: u.id, name: u.full_name || u.email || 'Accommodation Manager', properties: [] });
      }
    });

    managers.value = Array.from(managerListMap.values()).map((m) => ({
      id: m.id,
      name: m.name,
      propertyCount: m.properties.length,
      availableRooms: m.properties.reduce((sum, p) => sum + p.availableRooms, 0),
      propertyNames: m.properties.map((p) => p.name),
      properties: m.properties,
    }));
  } catch (err: any) {
    error.value = err?.message || 'Failed to load accommodations';
  } finally {
    loading.value = false;
  }
}

onMounted(loadData);
</script>

<style scoped>
.discover-page {
  min-height: 100vh;
  padding: 8px 12px calc(140px + env(safe-area-inset-bottom));
  background: #f0f2f5;
  color: #050505;
  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
}

/* FB-Style Top Category Chips */
.fb-top-tabs {
  display: flex;
  gap: 6px;
  margin-bottom: 6px;
  overflow-x: auto;
  padding-bottom: 2px;
}
.fb-category-chip {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  height: 34px;
  padding: 0 14px;
  border-radius: 17px;
  border: 0;
  background: #ffffff;
  font-size: 13px;
  font-weight: 600;
  color: #050505;
  cursor: pointer;
  box-shadow: 0 1px 2px rgba(0, 0, 0, 0.05);
}
.fb-category-chip.active {
  background: var(--m-primary-dark, #00695c);
  color: #ffffff;
}
.fb-feed-meta {
  display: flex;
  justify-content: space-between;
  font-size: 11px;
  font-weight: 700;
  color: #65676b;
  margin: 6px 4px 10px;
}
.filter-clear-link {
  border: 0;
  background: transparent;
  color: #00695c;
  font-weight: 700;
  cursor: pointer;
}

/* ==============================================================
   FACEBOOK MARKETPLACE 2-COLUMN PRODUCT GRID (ROOMS)
   ============================================================== */
.fb-marketplace-grid {
  display: grid;
  grid-template-columns: repeat(2, 1fr);
  gap: 8px;
}

.fb-marketplace-item {
  display: flex;
  flex-direction: column;
  background: #ffffff;
  border-radius: 8px;
  overflow: hidden;
  box-shadow: 0 1px 2px rgba(0, 0, 0, 0.08);
  cursor: pointer;
}

.fb-item-photo-wrap {
  position: relative;
  width: 100%;
  aspect-ratio: 1;
  background: #e4e6eb;
}
.fb-item-img {
  width: 100%;
  height: 100%;
}
.fb-item-photo-placeholder {
  height: 100%;
  display: grid;
  place-items: center;
  color: #8a8d91;
}
.fb-price-pill {
  position: absolute;
  left: 6px;
  bottom: 6px;
  background: rgba(0, 0, 0, 0.75);
  backdrop-filter: blur(4px);
  color: #ffffff;
  font-size: 12px;
  font-weight: 850;
  padding: 2px 7px;
  border-radius: 4px;
}

.fb-item-details {
  padding: 8px 10px;
  display: flex;
  flex-direction: column;
  gap: 2px;
}
.fb-item-title {
  font-size: 14px;
  font-weight: 700;
  color: #050505;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.fb-item-location {
  margin: 0;
  font-size: 11px;
  color: #65676b;
  display: flex;
  align-items: center;
  gap: 3px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.fb-item-footer {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-top: 4px;
}
.fb-room-type {
  font-size: 10.5px;
  font-weight: 600;
  color: #65676b;
}
.fb-slots-tag {
  font-size: 10.5px;
  font-weight: 750;
  color: #00695c;
  background: #e6f5f3;
  padding: 1px 5px;
  border-radius: 4px;
}

/* ==============================================================
   FACEBOOK FEED POST STYLE (PROPERTIES)
   ============================================================== */
.fb-post-feed {
  display: flex;
  flex-direction: column;
  gap: 10px;
}
.fb-post-card {
  background: #ffffff;
  border-radius: 8px;
  box-shadow: 0 1px 2px rgba(0, 0, 0, 0.08);
  overflow: hidden;
  cursor: pointer;
}
.fb-post-header {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 10px 12px 6px;
}
.fb-post-avatar {
  background: var(--m-primary-dark, #00695c);
  color: #ffffff;
  font-weight: 800;
}
.fb-author-details {
  display: flex;
  flex-direction: column;
}
.fb-author-row {
  display: flex;
  align-items: center;
  gap: 4px;
}
.fb-author-name {
  font-size: 14px;
  color: #050505;
}
.fb-verified-dot {
  color: #15803d;
  display: grid;
  place-items: center;
}
.fb-post-time {
  font-size: 11px;
  color: #65676b;
}

.fb-post-caption {
  padding: 4px 12px 8px;
}
.fb-post-caption strong {
  font-size: 15px;
  color: #050505;
  display: block;
}
.fb-post-caption p {
  margin: 2px 0 0;
  font-size: 12.5px;
  color: #65676b;
  line-height: 1.35;
}

.fb-post-media {
  width: 100%;
  height: 220px;
  background: #e4e6eb;
}
.fb-media-img {
  width: 100%;
  height: 100%;
}
.fb-media-placeholder {
  height: 100%;
  display: grid;
  place-items: center;
  color: #8a8d91;
}

.fb-post-footer {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 8px 12px;
  border-top: 1px solid #f0f2f5;
}
.fb-post-stat {
  display: flex;
  align-items: center;
  gap: 6px;
  font-size: 12px;
  font-weight: 700;
  color: #050505;
}
.fb-view-btn {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  border: 0;
  background: transparent;
  color: #00695c;
  font-size: 12px;
  font-weight: 750;
  cursor: pointer;
}

/* ==============================================================
   FACEBOOK CONTACTS / PROFILE DIRECTORY (MANAGERS)
   ============================================================== */
.fb-contacts-feed {
  display: flex;
  flex-direction: column;
  background: #ffffff;
  border-radius: 8px;
  overflow: hidden;
  box-shadow: 0 1px 2px rgba(0, 0, 0, 0.08);
}
.fb-contact-row {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 12px 14px;
  border-bottom: 1px solid #f0f2f5;
  background: #ffffff;
  cursor: pointer;
}
.fb-contact-row:last-child { border-bottom: 0; }
.fb-avatar-wrap {
  position: relative;
  flex-shrink: 0;
}
.fb-mgr-avatar {
  background: var(--m-primary-dark, #00695c);
  color: #ffffff;
  font-weight: 800;
}
.fb-online-badge {
  position: absolute;
  right: 1px;
  bottom: 1px;
  width: 13px;
  height: 13px;
  border-radius: 50%;
  background: #31a24c;
  border: 2px solid #ffffff;
}
.fb-contact-info {
  flex: 1;
  display: flex;
  flex-direction: column;
  gap: 1px;
}
.fb-contact-name-row {
  display: flex;
  align-items: center;
  gap: 6px;
}
.fb-contact-name {
  font-size: 14.5px;
  font-weight: 750;
  color: #050505;
}
.fb-badge-seal {
  display: inline-flex;
  align-items: center;
  gap: 2px;
  font-size: 9.5px;
  font-weight: 800;
  color: #15803d;
  background: #ecfdf3;
  padding: 1px 5px;
  border-radius: 4px;
}
.fb-contact-sub {
  font-size: 11.5px;
  color: #65676b;
}
.fb-contact-reply {
  font-size: 10.5px;
  color: #00695c;
  font-weight: 600;
}

/* ==============================================================
   REDESIGNED FULL-SCREEN ROOM DETAILS (FULL BLEED 360px & FLOW)
   ============================================================== */
.room-workspace {
  margin: -8px -12px calc(110px + env(safe-area-inset-bottom));
  padding: 0;
  background: #ffffff;
}

/* Property detail (full-screen, mirrors the room flow) */
.property-workspace {
  margin: -8px -12px calc(140px + env(safe-area-inset-bottom));
  padding: 0;
  background: #ffffff;
}
.property-hero { height: 300px; }
.property-occupancy { justify-content: center; }
.property-header .header-left { flex: 1 1 auto; min-width: 0; }
.property-name { font-size: 23px; }
.property-accredited {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  margin: 2px 0 6px;
  font-size: 10.5px;
  font-weight: 750;
  color: #15803d;
}
.property-addr { margin-top: 0; }

.property-room-list { display: flex; flex-direction: column; border: 1px solid var(--m-border, #e5e7eb); border-radius: 8px; overflow: hidden; }
.property-room-row {
  display: flex;
  align-items: center;
  gap: 10px;
  width: 100%;
  padding: 11px 12px;
  border: 0;
  border-bottom: 1px solid #f0f2f5;
  background: #ffffff;
  text-align: left;
  cursor: pointer;
}
.property-room-row:last-child { border-bottom: 0; }
.property-room-row:active { background: #f8fafc; }
.property-room-icon {
  display: grid;
  width: 34px;
  height: 34px;
  flex: 0 0 auto;
  place-items: center;
  border-radius: 8px;
  background: var(--m-primary-soft, #e6f5f3);
  color: var(--m-primary-dark, #00695c);
}
.property-room-copy { display: flex; min-width: 0; flex: 1; flex-direction: column; }
.property-room-copy strong { font-size: 13.5px; color: var(--m-ink, #17202a); }
.property-room-copy small { font-size: 11px; color: var(--m-muted, #6b7280); }
.property-room-price { font-size: 13px; font-weight: 750; color: var(--m-primary-dark, #00695c); white-space: nowrap; }
.property-room-chevron { flex: 0 0 auto; color: var(--m-muted, #6b7280); }
.property-rooms-empty {
  padding: 12px;
  border: 1px dashed var(--m-border, #e5e7eb);
  border-radius: 8px;
  background: #f8fafc;
  font-size: 12px;
  color: var(--m-muted, #6b7280);
  line-height: 1.45;
}
.property-policy-list { display: flex; flex-direction: column; gap: 8px; }
.property-policy-item {
  display: flex;
  align-items: center;
  gap: 8px;
  font-size: 12.5px;
  font-weight: 600;
  color: var(--m-ink, #17202a);
}

.room-hero-gallery {
  position: relative;
  width: 100%;
  height: 360px;
  background: #0f172a;
}
.room-carousel { height: 100%; }
.carousel-image { width: 100%; height: 100%; }

.gallery-overlay-top {
  position: absolute;
  top: max(14px, env(safe-area-inset-top));
  right: 14px;
  left: 14px;
  display: flex;
  justify-content: space-between;
  align-items: center;
  z-index: 20;
}
.gallery-round-btn {
  width: 40px;
  height: 40px;
  border-radius: 50%;
  border: 0;
  background: rgba(15, 23, 42, 0.65);
  backdrop-filter: blur(8px);
  color: #ffffff;
  display: grid;
  place-items: center;
  cursor: pointer;
}
.photo-counter-badge {
  position: absolute;
  right: 14px;
  bottom: 14px;
  z-index: 10;
  background: rgba(15, 23, 42, 0.75);
  backdrop-filter: blur(6px);
  color: #ffffff;
  font-size: 11px;
  font-weight: 750;
  padding: 4px 10px;
  border-radius: 6px;
}

.room-hero-placeholder {
  height: 100%;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  color: #64748b;
  gap: 8px;
  font-size: 13px;
}

.room-flow-container {
  display: flex;
  flex-direction: column;
  background: #ffffff;
}
.flow-section {
  padding: 16px 16px;
  border-bottom: 1px solid var(--m-border, #e5e7eb);
}
.section-title {
  margin: 0 0 10px;
  font-size: 14px;
  font-weight: 800;
  color: var(--m-ink, #17202a);
}

.section-title-row {
  display: flex;
  align-items: baseline;
  justify-content: space-between;
  gap: 8px;
  margin-bottom: 10px;
}
.section-title-row .section-title { margin: 0; }
.view-all-link {
  border: 0;
  background: transparent;
  padding: 0;
  color: var(--m-primary, #0f766e);
  font: inherit;
  font-size: 12.5px;
  font-weight: 700;
  cursor: pointer;
}

.room-header-block {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 12px;
}
.room-type-tag {
  font-size: 10px;
  font-weight: 800;
  text-transform: uppercase;
  color: var(--m-primary-dark, #00695c);
  letter-spacing: 0.05em;
}
.room-name {
  margin: 2px 0 4px;
  font-size: 22px;
  font-weight: 850;
  letter-spacing: -0.02em;
  color: var(--m-ink, #17202a);
}
.room-prop-link {
  margin: 0;
  font-size: 12.5px;
  color: var(--m-muted, #6b7280);
  display: flex;
  align-items: center;
  gap: 4px;
  cursor: pointer;
}
.header-right {
  text-align: right;
  display: flex;
  flex-direction: column;
}
.header-right strong {
  font-size: 20px;
  font-weight: 850;
  color: var(--m-primary-dark, #00695c);
}
.header-right small {
  font-size: 11px;
  color: var(--m-muted, #6b7280);
}

.spec-table, .cost-table {
  display: flex;
  flex-direction: column;
  border: 1px solid var(--m-border, #e5e7eb);
  border-radius: 8px;
}
.spec-row, .cost-row {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 9px 12px;
  border-bottom: 1px solid #f0f2f5;
  font-size: 12.5px;
}
.spec-row:last-child, .cost-row:last-child { border-bottom: 0; }
.spec-key { color: var(--m-muted, #6b7280); }
.spec-val { color: var(--m-ink, #17202a); }

.inclusions-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 8px;
}
.inclusion-item {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 8px 10px;
  background: #f8fafc;
  border-radius: 6px;
  font-size: 12px;
  font-weight: 650;
  color: var(--m-ink, #17202a);
}

.cost-desc { display: flex; flex-direction: column; }
.cost-desc strong { font-size: 12px; color: var(--m-ink, #17202a); }
.cost-desc small { font-size: 10.5px; color: var(--m-muted, #6b7280); }
.cost-val { font-size: 13px; font-weight: 750; }
.cost-row--total { background: var(--m-primary-soft, #e6f5f3); }
.cost-row--total .cost-val { font-size: 15px; font-weight: 850; }
.cost-terms { margin: 8px 0 0; font-size: 11px; color: var(--m-muted, #6b7280); }

.policy-list-clean { display: flex; flex-direction: column; }
.policy-line { display: flex; justify-content: space-between; padding: 7px 0; border-bottom: 1px solid #f3f4f6; font-size: 12px; }
.policy-line:last-child { border-bottom: 0; }
.policy-label { color: var(--m-ink, #17202a); font-weight: 700; width: 35%; }
.policy-desc { color: var(--m-muted, #6b7280); text-align: right; flex: 1; }
.prohibit-bar { margin-top: 10px; padding: 8px 12px; background: #fef2f2; color: #991b1b; font-size: 11.5px; font-weight: 750; border-radius: 6px; }

.property-address { margin: 0; display: flex; align-items: center; gap: 6px; font-size: 13px; font-weight: 750; color: var(--m-ink, #17202a); }
.property-bio { margin: 6px 0 0; font-size: 12.5px; color: var(--m-muted, #6b7280); line-height: 1.4; }

.manager-profile-row { display: flex; align-items: center; gap: 12px; margin-bottom: 12px; }
.manager-avatar { background: var(--m-primary-dark, #00695c); color: #ffffff; font-weight: 800; }
.manager-info { display: flex; flex-direction: column; }
.manager-name { font-size: 14.5px; color: var(--m-ink, #17202a); }
.manager-rating { font-size: 11px; color: var(--m-muted, #6b7280); }
.btn-chat-manager {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: 6px;
  width: 100%;
  height: 38px;
  border-radius: 6px;
  border: 1px solid var(--m-primary-dark, #00695c);
  background: var(--m-primary-soft, #e6f5f3);
  color: var(--m-primary-dark, #00695c);
  font-size: 12.5px;
  font-weight: 750;
  cursor: pointer;
}

.room-action-footer {
  position: fixed;
  right: 0;
  bottom: 0;
  left: 0;
  z-index: 60;
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 10px 16px calc(10px + env(safe-area-inset-bottom));
  background: #ffffff;
  border-top: 1px solid var(--m-border, #e5e7eb);
  box-shadow: 0 -4px 16px rgba(0, 0, 0, 0.06);
}
.footer-price-col { display: flex; flex-direction: column; }
.footer-label { font-size: 9.5px; font-weight: 750; text-transform: uppercase; color: var(--m-muted, #6b7280); }
.footer-price { font-size: 18px; font-weight: 850; color: var(--m-primary-dark, #00695c); }
.btn-apply-booking {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  vertical-align: middle;
  line-height: 1;
  gap: 8px;
  height: 42px;
  padding: 0 18px;
  border-radius: 6px;
  border: 0;
  background: var(--m-primary-dark, #00695c);
  color: #ffffff;
  font-size: 13px;
  font-weight: 800;
  cursor: pointer;
}
.btn-apply-booking span {
  display: inline-flex;
  align-items: center;
  line-height: 1;
}
.btn-apply-booking :deep(svg) {
  display: block;
}

/* ==============================================================
   3. REDESIGNED MANAGER PROFILE DETAIL VIEW
   ============================================================== */
.manager-workspace {
  margin: -8px -12px calc(90px + env(safe-area-inset-bottom));
  padding: 0 16px;
  background: #ffffff;
  min-height: 100vh;
}
.mgr-nav-top {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 12px 0;
  border-bottom: 1px solid var(--m-border, #e5e7eb);
}
.mgr-back-btn {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  border: 0;
  background: transparent;
  color: var(--m-primary-dark, #00695c);
  font-size: 13px;
  font-weight: 750;
  cursor: pointer;
}
.mgr-nav-title {
  font-size: 14px;
  font-weight: 800;
  color: var(--m-ink, #17202a);
}
.mgr-nav-space { width: 44px; }

.mgr-hero-section {
  display: flex;
  flex-direction: column;
  align-items: center;
  padding: 24px 0 20px;
  border-bottom: 1px solid var(--m-border, #e5e7eb);
  text-align: center;
}
.mgr-large-avatar {
  background: var(--m-primary-dark, #00695c);
  color: #ffffff;
  font-size: 24px;
  font-weight: 850;
  margin-bottom: 10px;
}
.mgr-profile-name {
  margin: 0 0 4px;
  font-size: 20px;
  font-weight: 850;
  color: var(--m-ink, #17202a);
}
.mgr-accredited-seal {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  font-size: 11px;
  font-weight: 800;
  color: #15803d;
  background: #ecfdf3;
  padding: 3px 8px;
  border-radius: 6px;
}

.mgr-stats-strip {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  width: 100%;
  max-width: 380px;
  margin: 16px 0;
  padding: 10px 0;
  border: 1px solid var(--m-border, #e5e7eb);
  border-radius: 8px;
  background: #f8fafc;
}
.mgr-stat-cell {
  display: flex;
  flex-direction: column;
  align-items: center;
  border-right: 1px solid #e2e8f0;
}
.mgr-stat-cell:last-child { border-right: 0; }
.stat-num { font-size: 16px; font-weight: 850; color: var(--m-ink, #17202a); }
.mgr-stat-cell small { font-size: 9.5px; color: var(--m-muted, #6b7280); font-weight: 700; }

.btn-message-manager-primary {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: 6px;
  width: 100%;
  max-width: 380px;
  height: 40px;
  border-radius: 6px;
  border: 0;
  background: var(--m-primary-dark, #00695c);
  color: #ffffff;
  font-size: 13px;
  font-weight: 750;
  cursor: pointer;
}

.mgr-properties-container {
  padding-top: 16px;
}
.mgr-section-heading {
  margin: 0 0 10px;
  font-size: 11.5px;
  font-weight: 800;
  letter-spacing: 0.05em;
  color: var(--m-muted, #6b7280);
}

/* Discover Search Bar */
.discover-action-bar {
  position: fixed;
  z-index: 59;
  right: 72px;
  bottom: 68px;
  left: var(--m-page-gutter, 12px);
  display: flex;
  gap: var(--m-space-2, 8px);
  align-items: center;
}
.search-field {
  display: flex;
  min-width: 0;
  flex: 1;
  align-items: center;
  gap: var(--m-space-2, 8px);
  min-height: 44px;
  padding: 0 var(--m-space-3, 12px);
  color: var(--m-muted, #6b7280);
  background: #ffffff;
  border: 1px solid var(--m-border, #e5e7eb);
  border-radius: 12px;
  box-shadow: 0 4px 12px rgba(15, 23, 42, 0.08);
}
.search-field input { min-width: 0; flex: 1; color: var(--m-ink, #17202a); border: 0; outline: 0; background: transparent; font: inherit; }
.filter-icon-button { display: grid; flex: 0 0 auto; width: 44px; height: 44px; place-items: center; color: var(--m-primary-dark, #00695c); background: #ffffff; border: 1px solid var(--m-border, #e5e7eb); border-radius: 12px; box-shadow: 0 4px 12px rgba(15, 23, 42, 0.08); }
.clear-search { width: 28px; height: 28px; border: 0; background: transparent; color: var(--m-muted, #6b7280); }

.text-teal { color: #00695c !important; }
.font-mono { font-family: var(--m-font-mono, monospace); }
.sr-only { position: absolute; width: 1px; height: 1px; padding: 0; margin: -1px; overflow: hidden; clip: rect(0,0,0,0); border: 0; }
</style>
