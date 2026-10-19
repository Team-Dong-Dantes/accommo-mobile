<template>
  <div>
  <div v-for="room in acc.rooms" :key="room.id" class="room" :class="{ 'room--off': picking === 'room' && !hasOpenBed(room) }">
    <!-- While adding a student, the room's header is what gets tapped. -->
    <component
      :is="picking === 'room' ? 'button' : 'div'"
      :type="picking === 'room' ? 'button' : undefined"
      class="room-head"
      :class="{ 'room-head--pick': picking === 'room' && hasOpenBed(room) }"
      :disabled="picking === 'room' && !hasOpenBed(room)"
      @click="picking === 'room' && pickRoom(acc, room)"
    >
      <span class="room-name">{{ room.label }}</span>
      <!-- One dot per bed: filled, applied for, or open. -->
      <span v-if="room.capacity" class="room-beds" aria-hidden="true">
        <i v-for="l in room.leases" :key="l.id" class="bed" :class="l.status === 'pending' ? 'bed--pending' : 'bed--on'" />
        <i v-for="n in Math.max(0, room.capacity - room.leases.length)" :key="`open-${n}`" class="bed" />
      </span>
      <span class="room-occ" :class="{ 'room-occ--full': roomOccupancy(room).full }">
        {{ roomOccupancy(room).label }}
      </span>
      <IconifyIcon v-if="picking === 'room' && hasOpenBed(room)" icon="lucide:user-plus" width="16" class="room-pick-icon" />
    </component>
    <div v-if="room.leases.length" class="room-list">
      <div
        v-for="l in room.leases"
        :key="l.id"
        class="lease-row"
        :class="{ 'lease-row--pending': l.status === 'pending', 'lease-row--leave': l.status === 'leave_requested' }"
      >
        <div class="lease-line">
        <button
          type="button"
          class="lease-main"
          :class="{ 'lease-main--pick': picking === 'payment' && isPayable(l) }"
          :disabled="picking === 'room' || (picking === 'payment' && !isPayable(l))"
          @click="picking === 'payment' ? pickLease(l) : router.push(`/manager/tenant/${l.id}`)"
        >
          <span class="lease-avatar" :class="l.avatarColor ? [`bg-${l.avatarColor}`, 'text-white'] : []">
            <img v-if="l.avatarUrl" :src="l.avatarUrl" alt="" class="lease-avatar-img" @error="l.avatarUrl = null" />
            <template v-else>{{ initialsOf(l.studentName) }}</template>
          </span>
          <span class="lease-body">
            <span class="lease-name">{{ l.studentName }}</span>
            <span class="lease-sub">{{ leaseSubline(l) }}</span>
          </span>
          <!-- Active is the norm here; only the states that need a decision get a chip. -->
          <span v-if="l.status !== 'active'" class="lease-chip" :class="`lease-chip--${statusColor(LEASE_STATUS, l.status)}`">
            {{ statusText(LEASE_STATUS, l.status) }}
          </span>
        </button>
        <button
          v-if="!picking && l.status !== 'pending'"
          type="button"
          class="lease-msg"
          aria-label="Message boarder"
          @click="router.push(`/manager/messages?to=${l.studentId}`)"
        >
          <IconifyIcon icon="lucide:message-circle" width="15" />
        </button>
        </div>
        <div v-if="!picking && l.status === 'pending'" class="lease-actions">
          <button
            type="button"
            class="lease-act lease-act--ghost"
            :disabled="decidingId === l.id"
            @click="openDecline(l)"
          >
            Decline
          </button>
          <!-- A student added by hand is accepted by scanning
               their QR, never with a tap (DB-enforced). -->
          <template v-if="l.addedByLandlord">
            <button
              type="button"
              class="lease-act"
              @click="router.push(`/manager/profile/qr-scanner?accept=${l.id}`)"
            >
              Scan to accept
            </button>
          </template>
          <button
            v-else
            type="button"
            class="lease-act"
            :disabled="decidingId === l.id"
            @click="decideApplication(l, 'active')"
          >
            Accept
          </button>
        </div>
      </div>
    </div>
    <p v-else class="room-none">No boarders</p>
  </div>
  </div>
</template>

<script setup lang="ts">
// One accommodation's rooms on the Boarders tab: beds, who is in each room,
// and the accept/decline of a pending application.
import { Icon as IconifyIcon } from '@iconify/vue'
import { initialsOf, LEASE_STATUS, statusText, statusColor } from '@/utils/format'
import type { Accommodation } from './model'
import { useTenants } from './tenants'

defineProps<{ acc: Accommodation }>()

const {
  router,
  roomOccupancy,
  leaseSubline,
  decidingId,
  openDecline,
  decideApplication,
  isPayable,
  picking,
  pickLease,
  hasOpenBed,
  pickRoom,
} = useTenants()
</script>

<style scoped>
/* One connected card — the header and its rooms share this border/radius
   instead of floating as separate boxes with a gap between them. */
.acc {
  display: flex;
  flex-direction: column;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius);
  background: var(--m-surface);
  overflow: hidden;
}
.room {
  display: flex;
  flex-direction: column;
  border-top: 1px solid var(--m-border);
}
.room-head {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 8px 12px;
  background: var(--m-bg);
}
.room-name {
  color: var(--m-ink);
  font-size: 12.5px;
  font-weight: 800;
  letter-spacing: 0.02em;
  text-transform: uppercase;
}
.room-beds {
  display: flex;
  flex-wrap: wrap;
  gap: 3px;
}
.bed {
  width: 8px;
  height: 8px;
  border: 1.5px solid var(--m-muted);
  border-radius: 50%;
  opacity: 0.55;
}
.bed--on {
  border-color: var(--m-primary);
  background: var(--m-primary);
  opacity: 1;
}
.bed--pending {
  border-color: var(--m-warning);
  background: var(--m-warning-soft);
  opacity: 1;
}
.room-occ {
  display: inline-flex;
  flex: 0 0 auto;
  align-items: center;
  gap: 3px;
  margin-left: auto;
  padding: 2px 8px;
  border-radius: 999px;
  background: var(--m-success-soft);
  color: var(--m-success);
  font-size: 11px;
  font-weight: 700;
}
.room-occ--full {
  background: var(--m-bg);
  color: var(--m-muted);
}
.room-none {
  margin: 0;
  padding: 12px;
  color: var(--m-muted);
  font-size: 12.5px;
  text-align: center;
}
.room-list {
  display: flex;
  flex-direction: column;
}
.lease-row {
  display: flex;
  flex-direction: column;
  gap: 6px;
  padding: 6px 8px 6px 12px;
  border-top: 1px solid var(--m-border);
}
.lease-line {
  display: flex;
  align-items: center;
  gap: 6px;
}
/* Rows waiting on a decision carry a warning edge, so they stand out in a
   room of settled tenants without shouting. */
.lease-row--pending,
.lease-row--leave {
  box-shadow: inset 3px 0 var(--m-warning);
}
.lease-row--pending {
  padding-bottom: 10px;
  background: var(--m-warning-soft);
}
.room-list > .lease-row:first-child {
  border-top: 0;
}
.lease-main {
  display: flex;
  min-width: 0;
  flex: 1;
  align-items: center;
  gap: 10px;
  padding: 4px 0;
  border: 0;
  border-radius: var(--m-radius-sm);
  background: transparent;
  cursor: pointer;
  font: inherit;
  text-align: left;
  transition: background-color 0.15s ease, opacity 0.15s ease;
  -webkit-tap-highlight-color: transparent;
}
.lease-main:disabled {
  opacity: 0.4;
  cursor: not-allowed;
}
/* While picking, what can be picked highlights against the disabled rest. */
.lease-main--pick {
  padding: 6px 8px;
  margin: 0 -8px;
  background: var(--m-primary-soft);
}
button.room-head {
  width: 100%;
  border: 0;
  cursor: pointer;
  font: inherit;
  text-align: left;
  -webkit-tap-highlight-color: transparent;
}
.room-head--pick {
  background: var(--m-primary-soft);
  box-shadow: inset 3px 0 var(--m-primary);
}
.room-pick-icon {
  flex: 0 0 auto;
  color: var(--m-primary);
}
.room--off {
  opacity: 0.4;
}
button.room-head:disabled {
  cursor: not-allowed;
}
.lease-actions {
  display: flex;
  gap: 8px;
  /* Lines the buttons up under the name, past the avatar. */
  padding-left: 46px;
}
.lease-actions .lease-act {
  flex: 1;
  min-height: 36px;
  font-size: 12.5px;
}
.lease-act {
  flex: 0 0 auto;
  padding: 6px 11px;
  border: 0;
  border-radius: 999px;
  background: var(--m-primary);
  color: #fff;
  cursor: pointer;
  font: inherit;
  font-size: 11.5px;
  font-weight: 700;
  -webkit-tap-highlight-color: transparent;
}
.lease-act:disabled {
  opacity: 0.6;
}
.lease-act--ghost {
  background: var(--m-surface);
  color: var(--m-text);
  border: 1px solid var(--m-border);
}
.lease-msg {
  display: grid;
  width: 32px;
  height: 32px;
  flex: 0 0 32px;
  place-items: center;
  border: 1px solid var(--m-border);
  border-radius: 50%;
  background: var(--m-surface);
  color: var(--m-text);
  cursor: pointer;
  -webkit-tap-highlight-color: transparent;
}
.lease-avatar {
  display: grid;
  width: 36px;
  height: 36px;
  flex: 0 0 36px;
  place-items: center;
  overflow: hidden;
  border-radius: 999px;
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
  font-size: 12px;
  font-weight: 800;
}
.lease-avatar-img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}
.lease-body {
  display: flex;
  min-width: 0;
  flex: 1;
  flex-direction: column;
  gap: 1px;
}
.lease-name {
  color: var(--m-ink);
  font-size: 13.5px;
  font-weight: 700;
}
.lease-sub {
  color: var(--m-muted);
  font-size: 11.5px;
}
.lease-chip {
  flex: 0 0 auto;
  padding: 3px 9px;
  border-radius: 999px;
  font-size: 10.5px;
  font-weight: 700;
}
.lease-chip--teal {
  background: var(--m-success-soft);
  color: var(--m-success);
}
.lease-chip--amber,
.lease-chip--orange {
  background: var(--m-warning-soft);
  color: var(--m-warning);
}
.lease-chip--grey {
  background: var(--m-bg);
  color: var(--m-muted);
}
.lease-chip--red {
  background: var(--m-danger-soft);
  color: var(--m-danger);
}
/* The panel has no side padding, so the lists run edge to edge as flat
   sections; only the loose controls and headings keep an inset. */
.panel :is(.acc, .group) {
  border-right: 0;
  border-left: 0;
  border-radius: 0;
}
/* Flat properties butt together, split by a page-coloured band instead of
   .tab-panel's 14px gap, which read as an empty white row between borders. */
.panel .acc + .acc {
  margin-top: -14px;
  border-top: 8px solid var(--m-bg);
}
</style>
