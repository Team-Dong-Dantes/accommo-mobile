<template>
  <q-page class="tprof" :class="{ 'page-wide': split }">
    <!-- Desktop placeholder in the card's own shape, so the first open does not
         show the phone layout and then snap into two halves. -->
    <div v-if="loading && split" class="stack">
      <div class="desk-card">
        <div class="desk-col">
          <div class="hero" />
          <div class="body-card">
            <div class="head">
              <q-skeleton type="circle" size="84px" style="margin-top: -42px; margin-bottom: 4px;" />
              <q-skeleton type="text" width="130px" height="17px" />
              <q-skeleton type="text" width="160px" height="12px" />
            </div>
          </div>
          <q-skeleton type="rect" height="90px" class="sk" style="margin-top: 14px;" />
        </div>
        <div class="desk-col">
          <q-skeleton type="rect" height="120px" class="sk" />
          <q-skeleton type="rect" height="70px" class="sk" />
        </div>
      </div>
    </div>

    <div v-else-if="loading" class="stack">
      <div class="hero"><q-skeleton type="rect" height="170px" square /></div>
      <div class="body-card">
        <div class="head">
          <q-skeleton type="circle" size="84px" style="margin-top: -42px; margin-bottom: 4px;" />
          <q-skeleton type="text" width="130px" height="17px" />
          <q-skeleton type="text" width="72px" height="18px" />
          <q-skeleton type="text" width="160px" height="12px" />
        </div>
      </div>
      <div class="tabs">
        <q-skeleton type="rect" width="72px" height="38px" class="m-sk-tab" />
        <q-skeleton type="rect" width="72px" height="38px" class="m-sk-tab" />
        <q-skeleton type="rect" width="72px" height="38px" class="m-sk-tab" />
      </div>
      <q-skeleton type="rect" height="90px" class="sk" />
    </div>

    <div v-else-if="error" class="stack">
      <ErrorCard title="Couldn't load this boarder" :detail="error" :retry="load" />
    </div>

    <div v-else class="stack">
      <!-- Desktop: two columns that scroll on their own — the profile and its
           overview on the left, payments and history on the right. On a phone
           .col-left is display: contents and nothing here changes. -->
      <div :class="split ? 'desk-card' : 'tabbed'">
        <div :class="split ? 'desk-col' : 'col-left'">
        <div class="hero">
          <img v-if="coverUrl" :src="coverUrl" alt="" class="hero-img" />
          <div class="hero-scrim" />
          <!-- Desktop only: the app header stays the plain one here (MainLayout),
               so the way back to the tenants list lives on the card itself. -->
          <button v-if="split" type="button" class="hero-msg hero-back" aria-label="Back to my boarders" @click="router.push('/manager/tenants')">
            <IconifyIcon icon="lucide:arrow-left" width="16" />
          </button>
          <button type="button" class="hero-msg" aria-label="Message boarder" @click="router.push(`/manager/messages?to=${lease.studentId}`)">
            <IconifyIcon icon="lucide:message-circle" width="16" />
          </button>
        </div>

        <div class="body-card">
          <div class="head">
            <span class="head-avatar">
              <img v-if="lease.studentAvatarUrl" :src="lease.studentAvatarUrl" alt="" class="head-avatar-img" @error="lease.studentAvatarUrl = null" />
              <template v-else>{{ lease.studentInitials }}</template>
            </span>
            <span class="head-name">{{ lease.studentName }}</span>
            <span class="head-chip" :class="`head-chip--${statusColor(LEASE_STATUS, lease.status)}`">
              {{ statusText(LEASE_STATUS, lease.status) }}
            </span>
            <span class="head-sub">{{ lease.roomLabel }} · {{ lease.accommodationName }}</span>
          </div>
        </div>

        <div v-if="!split" class="tabs">
          <button
            v-for="t in TABS"
            :key="t.key"
            type="button"
            class="m-tab"
            :class="{ 'm-tab--on': tab === t.key }"
            @click="tab = t.key"
          >
            {{ t.label }}
          </button>
        </div>

        <div class="panel">
          <!-- Plain divs on desktop, swipeable QTabPanels elsewhere; the same
               markup either way. -->
          <component :is="panelsIs" v-bind="panelsProps" class="m-panels">
            <component :is="panelIs" name="overview" class="sec">
            <TenantOverview />
          </component>

          <!-- Payments and history move into the right column on desktop. The
               Teleport sits inside the panel, not around it, so QTabPanels still
               finds a panel named "payments" among its children on a phone. -->
          <component :is="panelIs" name="payments" class="sec" :class="{ 'sec--moved': split }">
            <Teleport :to="rightCol" :disabled="!split || !rightCol">
            <TenantPayments />
            </Teleport>
          </component>

          <component :is="panelIs" name="history" class="sec" :class="{ 'sec--moved': split }">
            <Teleport :to="rightCol" :disabled="!split || !rightCol">
            <div class="sec-body">
            <BoardingTimeline v-if="history.length" :stays="history" />
            <EmptyState
              v-else
              variant="compact"
              icon="lucide:history"
              title="No past stays"
              message="This is their first stay through accommo."
            />
            </div>
            </Teleport>
          </component>
          </component>
        </div>
        </div>

        <div v-if="split" ref="rightCol" class="desk-col col-right" />
      </div>
    </div>

    <TenantSheets />
  </q-page>
</template>

<script setup lang="ts">
import BoardingTimeline from '@/components/shared/BoardingTimeline.vue'
import EmptyState from '@/components/shared/EmptyState.vue'
import ErrorCard from '@/components/shared/ErrorCard.vue'
import { Icon as IconifyIcon } from '@iconify/vue'
import { LEASE_STATUS, statusColor, statusText } from '@/utils/format'
import { TABS } from '@/components/manager/tenant/model'
import TenantOverview from './tenant/TenantOverview.vue'
import TenantPayments from './tenant/TenantPayments.vue'
import TenantSheets from './tenant/TenantSheets.vue'
import { ref } from 'vue'
import { useDeskPanels } from '@/utils/useDeskPanels'
import { provideTenant } from './tenant/tenant'

// The page is the shell — loading states, the hero and name, the tabs (or
// desktop's two halves). The tabs' content and every sheet live in ./tenant/.
const {
  router,
  loading,
  error,
  lease,
  coverUrl,
  history,
  load,
} = provideTenant()

const tab = ref<(typeof TABS)[number]['key']>('overview')

// Desktop lays the tabs out as the two halves of a card instead (useDeskPanels).
const { split, panelsIs, panelIs, panelsProps } = useDeskPanels(tab)
const rightCol = ref<HTMLElement | null>(null)
</script>

<style scoped>
.tprof {
  display: flex;
  flex-direction: column;
  background: var(--m-bg);
}
.stack {
  display: flex;
  flex: 1;
  min-height: 0;
  flex-direction: column;
  gap: 12px;
  padding: 8px var(--m-page-gutter) 0;
}
.sk {
  border-radius: var(--m-radius);
}
.tabbed {
  display: flex;
  flex: 1;
  min-height: 0;
  flex-direction: column;
  margin: -8px calc(var(--m-page-gutter) * -1) 0;
}
/* Cover band — bleeds to the very top of the page (cancels .stack's own
   top padding via .tabbed's negative margin) and to both edges. No text
   sits on it; the avatar straddling its bottom edge is the only thing
   that touches it directly. */
.hero {
  position: relative;
  flex: 0 0 auto;
  height: 170px;
  overflow: hidden;
  background: linear-gradient(160deg, var(--m-border), var(--m-surface) 85%);
}
.hero-img {
  position: absolute;
  inset: 0;
  width: 100%;
  height: 100%;
  object-fit: cover;
}
.hero-scrim {
  position: absolute;
  inset: 0;
  background: linear-gradient(to bottom, rgba(0, 0, 0, 0.18) 0%, rgba(0, 0, 0, 0) 70%);
}
.hero-msg {
  position: absolute;
  top: 10px;
  right: var(--m-page-gutter);
  z-index: 2;
  display: grid;
  width: 34px;
  height: 34px;
  place-items: center;
  border: 0;
  border-radius: 999px;
  background: rgba(23, 32, 42, 0.55);
  color: #fff;
  cursor: pointer;
  -webkit-tap-highlight-color: transparent;
}
.hero-back {
  right: auto;
  left: var(--m-page-gutter);
}
/* Profile info only — the avatar pulls up into the hero via a negative
   margin so it straddles the seam, cover-photo style. Tabs and their
   content live in separate elements below, not nested in this card. */
.body-card {
  position: relative;
  margin: -85px var(--m-page-gutter) 0;
  padding: 0 var(--m-page-gutter) 14px;
  border-radius: var(--m-radius);
  background: var(--m-surface);
  box-shadow: var(--m-shadow);
}
.head {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 4px;
  padding-top: 8px;
  text-align: center;
}
.head-avatar {
  display: grid;
  /* The hero sits in a column flex container, so height is the main axis and
     flex-shrink defaults to 1 -- a tight column squashed this 84px circle into
     an oval. Every other avatar in the app already pins itself this way. */
  flex: none;
  width: 84px;
  height: 84px;
  place-items: center;
  overflow: hidden;
  margin-top: -42px;
  margin-bottom: 4px;
  border: 4px solid var(--m-surface);
  border-radius: 999px;
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
  font-family: var(--m-font-display);
  font-size: 24px;
  font-weight: 800;
  box-shadow: 0 2px 6px rgba(15, 23, 42, 0.12);
}
.head-avatar-img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}
.head-name {
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 17px;
  font-weight: 700;
}
.head-chip {
  margin-top: 4px;
  padding: 3px 10px;
  border-radius: 999px;
  font-size: 11px;
  font-weight: 700;
}
.head-chip--teal {
  background: var(--m-success-soft);
  color: var(--m-success);
}
.head-chip--amber,
.head-chip--orange {
  background: var(--m-warning-soft);
  color: var(--m-warning);
}
.head-chip--grey {
  background: var(--m-bg);
  color: var(--m-muted);
}
.head-chip--red {
  background: var(--m-danger-soft);
  color: var(--m-danger);
}
.head-sub {
  margin-top: 4px;
  color: var(--m-muted);
  font-size: 12.5px;
}
/* Rounded-top pill tabs rising into the bordered panel below — same
   tab-folder shape as accommodation detail, recolored for a plain white
   card instead of a photo backdrop (no gradient sits behind these). */
.tabs {
  position: relative;
  z-index: 2;
  display: flex;
  gap: 4px;
  /* -2px, not -1px: see ManagerTenantsPage.vue's .tabs comment — an exact 1px
     overlap can round the wrong way on real (non-@1x) device pixel ratios
     and leave a hairline gap under the active tab. */
  margin: 14px var(--m-page-gutter) -2px;
}
/* Its own card, distinct from .body-card above — not a shared surface. The
   active tab's background matches this panel's, so the -1px overlap above
   fuses them with no visible seam, while unselected tabs still show the
   border. Bleeds to the page edges and fills to the bottom, same as
   accommodation detail's own .panel. */
.panel {
  display: flex;
  position: relative;
  z-index: 1;
  flex: 1;
  min-height: 0;
  flex-direction: column;
  padding: 0 var(--m-page-gutter) 14px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius) var(--m-radius) 0 0;
  background: var(--m-surface);
}
.sec {
  display: flex;
  flex-direction: column;
  gap: 6px;
}
/* ---- Desktop: two columns ----
   Off the desktop these wrappers are transparent: .col-left and .sec-body are
   display: contents, so the phone layout is exactly the tabbed one it was. */
.col-left,
.sec-body {
  display: contents;
}
/* Desktop: the card (.desk-card / .desk-col, app.scss) — the same card as the
   Tenants page, so opening a tenant reads as that card changing its contents. */
/* The cover runs to the half's edges; the card's own rounding clips its corner. */
.desk-card .hero {
  margin: -14px -18px 0;
}
/* The avatar card's gap below the cover is its own; the column's gap would add
   to it. */
.desk-card .desk-col:first-child {
  gap: 0;
}
/* Inside the half, the overview is just content — not a second card. */
.desk-card .panel {
  flex: none;
  margin-top: 14px;
  padding: 0;
  border: 0;
  border-radius: 0;
  background: transparent;
}
.desk-card .col-right {
  gap: 22px;
}
.col-right .sec-body {
  display: flex;
  flex-direction: column;
  gap: 6px;
}
/* The emptied tab shells left behind in the left column once their content has
   moved right. */
.sec--moved {
  display: none;
}
</style>
