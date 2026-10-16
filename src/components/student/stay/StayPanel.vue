<template>
<h2 v-if="isTablet" class="split-head">My Stay</h2>
<template v-if="lease">
  <StayHero
    v-if="isDesktop"
    :name="lease.accommodationName"
    :room="lease.roomLabel"
    :address="lease.address"
    :status="lease.status"
    :photo-url="lease.photoUrl"
  />

  <div class="mgr">
    <span class="mgr-avatar">
      <img v-if="lease.managerAvatarUrl" :src="lease.managerAvatarUrl" alt="" class="mgr-avatar-img" @error="lease.managerAvatarUrl = null" />
      <template v-else>{{ lease.managerInitials }}</template>
    </span>
    <span class="mgr-body">
      <span class="mgr-name">{{ lease.managerName }}</span>
      <span class="mgr-sub">
        Your {{ myLandlord }}<template v-if="lease.replyMinutes">{{ ` · replies in ~${lease.replyMinutes} min` }}</template>
      </span>
    </span>
    <button
      type="button"
      class="mgr-msg"
      :aria-label="`Message your ${myLandlord}`"
      @click="router.push(`/student/messages?to=${lease.managerId}`)"
    >
      <IconifyIcon icon="lucide:message-circle" width="17" />
    </button>
  </div>
  <p v-if="lease.status === 'pending'" class="note">Application pending — awaiting your {{ myLandlord }}'s decision.</p>
  <p v-else-if="lease.status === 'leave_requested'" class="note">
    You asked to move out on {{ formatDate(lease.leaveDate) }} — awaiting your {{ myLandlord }}'s decision. Rent stays due until then.
  </p>
  <p v-else-if="lease.leaveDate" class="note">Moving out {{ formatDate(lease.leaveDate) }} — approved by your {{ myLandlord }}.</p>

  <!-- The four things a boarder actually checks, as tiles; the
       rest is reference, one hairline list below. -->
  <div class="facts">
    <div class="fact">
      <span class="fact-label">Monthly rent</span>
      <span class="fact-value">{{ formatPeso(lease.monthlyRent) }}</span>
      <span class="fact-sub">per month</span>
    </div>
    <div class="fact">
      <span class="fact-label">Lease ends</span>
      <span class="fact-value">{{ formatDate(lease.endDate) }}</span>
      <span class="fact-sub">Started {{ formatDate(lease.startDate) }}</span>
    </div>
    <div class="fact">
      <span class="fact-label">Room type</span>
      <span class="fact-value">{{ lease.roomType || '—' }}</span>
    </div>
    <div class="fact">
      <span class="fact-label">Capacity</span>
      <span class="fact-value">{{ lease.capacity ? `${lease.capacity} ${lease.capacity === 1 ? 'person' : 'people'}` : '—' }}</span>
      <span v-if="lease.roommateCount !== null" class="fact-sub">
        {{ lease.roommateCount > 0 ? `${lease.roommateCount} roommate${lease.roommateCount === 1 ? '' : 's'}` : 'Just you so far' }}
      </span>
    </div>
  </div>

  <section class="sec">
    <h2 class="sec-title">Utilities</h2>
    <div v-for="u in UTILITIES" :key="u.key" class="line">
      <span class="line-label">{{ u.label }}</span>
      <span class="line-value">{{ utilityTermsLabel(lease.utilities[u.key]) }}</span>
    </div>
  </section>

  <section v-if="lease.rules.length" class="sec">
    <h2 class="sec-title">House rules</h2>
    <div v-for="rule in lease.rules" :key="rule.label" class="line">
      <span class="line-label">{{ rule.label }}</span>
      <span class="line-value">{{ rule.value }}</span>
    </div>
  </section>

  <section v-if="lease.amenities.length" class="sec">
    <h2 class="sec-title">Amenities</h2>
    <div class="amenities">
      <span v-for="a in lease.amenities" :key="a" class="amenity">
        <IconifyIcon :icon="AMENITY_META[a]?.icon || 'lucide:dot'" width="15" />
        {{ AMENITY_META[a]?.label || a }}
      </span>
    </div>
  </section>

  <section class="sec">
    <button type="button" class="line line-link" @click="router.push('/student/concerns')">
      <IconifyIcon icon="lucide:message-square-warning" width="16" />
      <span>Concerns</span>
      <IconifyIcon icon="lucide:chevron-right" width="16" class="chevron" />
    </button>
    <button type="button" class="line line-link" @click="router.push('/student/profile/history')">
      <IconifyIcon icon="lucide:history" width="16" />
      <span>History</span>
      <IconifyIcon icon="lucide:chevron-right" width="16" class="chevron" />
    </button>
  </section>

  <button v-if="lease.status === 'active' && !lease.leaveDate" type="button" class="leave-link" @click="openLeave">
    Request to leave
  </button>
</template>

<EmptyState
  v-else
  variant="compact"
  icon="lucide:home"
  title="No active stay"
  message="Once a landlord/landlady accepts your application, your tenancy details, rent and landlord/landlady contact will show up here."
>
  <template #actions>
    <q-btn unelevated rounded no-caps color="primary" label="Browse rooms" @click="router.push('/student/discover')" />
  </template>
</EmptyState>
</template>

<script setup lang="ts">
// The My Stay tab: the room, its terms and the four tiles a boarder checks,
// or the empty state before a stay exists.
import { AMENITY_META, UTILITIES, utilityTermsLabel } from '@/utils/listings'
import EmptyState from '@/components/shared/EmptyState.vue'
import { Icon as IconifyIcon } from '@iconify/vue'
import StayHero from '@/components/student/StayHero.vue'
import { formatDate, formatPeso } from '@/utils/format'
import { isDesktop, isTablet } from '@/utils/useTabletMode'
import { useStay } from './stay'

const {
  router,
  myLandlord,
  lease,
  openLeave,
} = useStay()
</script>

<style scoped>
.sec {
  display: flex;
  flex-direction: column;
  gap: 6px;
}
.sec-title {
  margin: 0;
  padding: 6px 2px 0;
  color: var(--m-muted);
  font-size: 11px;
  font-weight: 700;
  letter-spacing: 0.04em;
  /* Quasar gives h2 a 3.75rem line-height, which an 11px label inherits. */
  line-height: 1.3;
  text-transform: uppercase;
}
.sec-head .sec-title {
  padding: 0;
}
.rule {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  padding: 9px 12px;
  border-top: 1px solid var(--m-border);
}
.group > .rule:first-child {
  border-top: 0;
}
.m-tabbed--hero > .stay-hero {
  margin: -8px calc(var(--m-page-gutter) * -1) 0;
}
/* Desktop: the hero heads the stay half instead, as a card of its own. */
.desk-col > .stay-hero {
  height: 180px;
  border-radius: var(--m-radius);
}
.mgr {
  display: flex;
  align-items: center;
  gap: 11px;
}
.mgr-avatar {
  display: grid;
  width: 42px;
  height: 42px;
  flex: 0 0 42px;
  place-items: center;
  overflow: hidden;
  border-radius: 999px;
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
  font-size: 13px;
  font-weight: 800;
}
.mgr-avatar-img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}
.mgr-body {
  display: flex;
  min-width: 0;
  flex: 1;
  flex-direction: column;
  gap: 1px;
}
.mgr-name {
  overflow: hidden;
  color: var(--m-ink);
  font-size: 15px;
  font-weight: 700;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.mgr-sub {
  color: var(--m-muted);
  font-size: 12px;
}
.mgr-msg {
  display: grid;
  width: 42px;
  height: 42px;
  flex: 0 0 42px;
  place-items: center;
  border: 0;
  border-radius: 999px;
  background: var(--m-primary);
  color: #fff;
  cursor: pointer;
  -webkit-tap-highlight-color: transparent;
}
.note {
  margin: -4px 0 0;
  padding: 9px 12px;
  border-radius: var(--m-radius-sm);
  background: var(--m-warning-soft);
  color: var(--m-warning);
  font-size: 12.5px;
  font-weight: 600;
}
/* Key facts: recessed tiles, so they read as their own surface on the panel. */
.facts {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 8px;
}
.fact {
  display: flex;
  min-width: 0;
  flex-direction: column;
  gap: 2px;
  padding: 12px 13px;
  border-radius: var(--m-radius-sm);
  background: var(--m-bg);
}
.fact-label {
  color: var(--m-muted);
  font-size: 11px;
  font-weight: 700;
  letter-spacing: 0.02em;
  text-transform: uppercase;
}
.fact-value {
  overflow: hidden;
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 18px;
  font-weight: 700;
  letter-spacing: -0.01em;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.fact-sub {
  color: var(--m-muted);
  font-size: 12px;
}
/* Reference rows: one hairline column, no boxes. */
.line {
  display: flex;
  align-items: baseline;
  justify-content: space-between;
  gap: 16px;
  padding: 10px 2px;
  border-top: 1px solid var(--m-border);
}
.line-label {
  flex: 0 0 auto;
  color: var(--m-muted);
  font-size: 13px;
}
.line-value {
  color: var(--m-ink);
  font-size: 13px;
  font-weight: 600;
  text-align: right;
  text-wrap: pretty;
}
.line-link {
  width: 100%;
  align-items: center;
  justify-content: flex-start;
  gap: 10px;
  border-right: 0;
  border-bottom: 0;
  border-left: 0;
  background: transparent;
  color: var(--m-text);
  cursor: pointer;
  font: inherit;
  font-size: 13.5px;
  font-weight: 600;
  text-align: left;
  -webkit-tap-highlight-color: transparent;
}
.line-link .chevron {
  margin-left: auto;
  color: var(--m-muted);
}
.amenities {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
  padding-top: 4px;
}
.amenity {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  padding: 6px 11px;
  border-radius: 999px;
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
  font-size: 12.5px;
  font-weight: 600;
}
.leave-link {
  align-self: center;
  padding: 8px;
  border: 0;
  background: transparent;
  color: var(--m-danger);
  cursor: pointer;
  font: inherit;
  font-size: 13px;
  font-weight: 700;
  text-decoration: underline;
  -webkit-tap-highlight-color: transparent;
}
.split-head {
  margin: 0 0 2px;
  line-height: 1.3;
  color: var(--m-ink);
  font-size: 15px;
  font-weight: 700;
  letter-spacing: -0.01em;
}
</style>
