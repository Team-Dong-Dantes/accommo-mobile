<template>
  <!-- Tenants → Monthly rent: a month stepper and property pill, the month's
       hero bar, four tiles that choose the list below, then the rows. The rest
       (tasks, past-stay debts, payout) is the app's own parts, unchanged. -->
  <div class="cp">
    <!-- The loaded layout's shape: the month hero, then one flat section of rows. -->
    <template v-if="loading && !col">
      <div class="cp-inset"><q-skeleton type="rect" height="120px" class="cp-sk" /></div>
      <section class="cp-block">
        <div class="room-head"><q-skeleton type="text" width="90px" height="14px" /></div>
        <div v-for="n in 3" :key="n" class="lease-row">
          <span class="lease-main cp-static">
            <q-skeleton type="circle" size="36px" />
            <span class="lease-body">
              <q-skeleton type="text" width="55%" height="15px" />
              <q-skeleton type="text" width="35%" height="12px" />
            </span>
          </span>
        </div>
      </section>
    </template>
    <ErrorCard v-else-if="error" title="Couldn't load payments" :detail="error" :retry="load" inset />

    <EmptyState
      v-else-if="col && !leases.length"
      variant="compact"
      icon="lucide:receipt"
      title="No payments to track yet"
      message="Once you accept a boarder, what they owe and what they've paid shows up here."
    />

    <template v-else-if="col">
      <div class="cp-inset">
        <PeriodBar :label="formatMonth(viewMonth)" :can-prev="viewMonth > earliestMonth" :can-next="viewMonth < thisMonth" @prev="step(-1)" @next="step(1)">
          <PropertyPicker v-model="propertyId" :options="propertyOptions" />
        </PeriodBar>

        <div class="cp-hero">
          <span class="cp-big">{{ formatPeso(col.collected) }}</span>
          <span class="cp-of">of {{ formatPeso(expected) }} collected</span>
        </div>
        <StackBar
          :segments="[
            { value: col.collected, tone: 'success' },
            { value: col.toConfirm, tone: 'info' },
            { value: col.overdue, tone: 'danger' },
            { value: col.toCome, tone: 'border' },
          ]"
          :label="`${formatPeso(col.collected)} collected, ${formatPeso(col.toConfirm)} to confirm, ${formatPeso(col.overdue)} overdue, ${formatPeso(col.toCome)} still to come`"
        />

        <div class="cp-tiles" role="radiogroup" aria-label="Show">
          <button
            v-for="t in tiles"
            :key="t.key"
            type="button"
            role="radio"
            class="cp-tile"
            :class="{ 'cp-tile--on': shownTile === t.key }"
            :aria-checked="shownTile === t.key"
            @click="picked = t.key"
          >
            <span class="cp-tile-top">
              <i class="cp-dot" :style="{ background: `var(--m-${t.count ? t.tone : 'border'})` }" />{{ t.label }}
              <span class="cp-tile-n">{{ t.count }}</span>
            </span>
            <span class="cp-tile-amt" :style="{ color: t.count ? `var(--m-${t.tone})` : 'var(--m-muted)' }">{{ formatPeso(t.amount) }}</span>
          </button>
        </div>
      </div>

      <!-- Set-up tasks (e.g. "Add where boarders send money") sit right under the tiles. -->
      <DashTodoList v-if="tasks.length" class="cp-inset cp-todo" title="" :tasks="tasks" :done-count="0" @go="onTask" />

      <CollectionList />
    </template>

    <PaymentReviewSheet v-model="reviewOpen" :payment-id="reviewId" @changed="changed" />
    <LogPaymentSheet
      v-model="logOpen"
      :lease-id="logLease?.id ?? ''"
      :start-date="logLease?.startDate"
      :subtitle="logLease ? `From ${logLease.studentName} · ${logLease.roomLabel}` : ''"
      @submitted="changed"
    />
    <PostBillsSheet v-model="billsOpen" @posted="changed" />
    <PayoutDialog v-model="payoutOpen" @update:model-value="(v) => !v && loadPayout()" />
  </div>
</template>

<script setup lang="ts">
import CollectionList from './collections/CollectionList.vue'
import DashTodoList from '@/components/shared/DashTodoList.vue'
import EmptyState from '@/components/shared/EmptyState.vue'
import ErrorCard from '@/components/shared/ErrorCard.vue'
import LogPaymentSheet from '@/components/manager/LogPaymentSheet.vue'
import PaymentReviewSheet from '@/components/manager/PaymentReviewSheet.vue'
import PayoutDialog from '@/components/manager/PayoutDialog.vue'
import PeriodBar from '@/components/shared/PeriodBar.vue'
import PostBillsSheet from '@/components/manager/PostBillsSheet.vue'
import PropertyPicker from '@/components/shared/PropertyPicker.vue'
import StackBar from '@/components/shared/StackBar.vue'
import { formatMonth, formatPeso } from '@/utils/format'
import { provideCollections } from './collections/collectionsPanel'

// Monthly rent's state lives in ./collections/; this is the month, its hero,
// tiles and to-dos.
// Loads on its own, and again whenever `version` moves (the Tenants page bumps
// it on every refresh), so the page above it doesn't carry any payment state.
// `query` is the page's search box: it narrows the rows, not the totals.
const props = defineProps<{ version: number; query: string }>()
const emit = defineEmits<{ changed: []; count: [n: number] }>()

const {
  loading,
  error,
  leases,
  propertyId,
  thisMonth,
  viewMonth,
  earliestMonth,
  step,
  propertyOptions,
  col,
  expected,
  picked,
  tiles,
  shownTile,
  tasks,
  onTask,
  load,
  payoutOpen,
  loadPayout,
  reviewOpen,
  reviewId,
  logOpen,
  logLease,
  billsOpen,
  changed,
} = provideCollections({ props, emit })
</script>

<style scoped>
/* Sits in the Tenants panel, which has no side padding: loose controls keep
   the panel's 12px inset, list sections run edge to edge (ManagerTenantsPage). */
.cp {
  display: flex;
  flex-direction: column;
  gap: 14px;
}
.cp-sk {
  border-radius: var(--m-radius);
}
.cp-inset {
  display: flex;
  flex-direction: column;
  gap: 8px;
  margin: 0 12px;
}
:global(.shell-tablet) .cp-inset {
  margin: 0;
}
/* The dashboard's todo rows sit on the page background; in this white panel
   they take the background colour so they still read as cards. */
.cp-todo :deep(.step) {
  background: var(--m-bg);
}
/* An <h2>: without a line-height it takes Quasar's 3.75rem one. */
.cp-todo :deep(.sec-title) {
  line-height: 1.3;
}
/* ManagerTenantsPage's flat property section: a page-coloured band between
   sections, a grey header band, rows split by hairlines. */
.cp-block {
  display: flex;
  flex-direction: column;
  border-top: 1px solid var(--m-border);
  border-bottom: 1px solid var(--m-border);
  background: var(--m-surface);
}
.cp-block + .cp-block {
  margin-top: -14px;
  border-top: 8px solid var(--m-bg);
}
.room-head {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 8px 12px;
  background: var(--m-bg);
}
.lease-row {
  display: flex;
  flex-direction: column;
  gap: 6px;
  padding: 6px 8px 6px 12px;
  border-top: 1px solid var(--m-border);
}
.lease-main {
  display: flex;
  width: 100%;
  min-width: 0;
  flex: 1;
  align-items: center;
  gap: 10px;
  padding: 4px 0;
  border: 0;
  border-radius: var(--m-radius-sm);
  background: transparent;
  color: inherit;
  cursor: pointer;
  font: inherit;
  text-align: left;
  -webkit-tap-highlight-color: transparent;
}
.cp-static {
  cursor: default;
}
.lease-main :deep(.ca) {
  width: 36px;
  height: 36px;
  font-size: 12px;
  font-weight: 800;
}
.lease-body {
  display: flex;
  min-width: 0;
  flex: 1;
  flex-direction: column;
  gap: 1px;
}
/* The month hero: the big collected figure over the stacked bar. */
.cp-hero {
  display: flex;
  flex-wrap: wrap;
  align-items: baseline;
  gap: 4px 8px;
  margin-top: 6px;
}
.cp-big {
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 34px;
  font-weight: 700;
  letter-spacing: -0.03em;
}
.cp-of {
  color: var(--m-muted);
  font-size: 14px;
}
.cp-tiles {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 8px;
  margin-top: 6px;
}
.cp-tile {
  display: flex;
  min-height: 64px;
  flex-direction: column;
  gap: 2px;
  padding: 10px 12px;
  border: 1px solid var(--m-border);
  border-radius: 12px;
  background: var(--m-surface);
  cursor: pointer;
  font: inherit;
  text-align: left;
  -webkit-tap-highlight-color: transparent;
}
/* A 2px ring would shift the text, so the padding gives up the extra pixel. */
.cp-tile--on {
  padding: 9px 11px;
  border: 2px solid var(--m-info);
  background: var(--m-info-soft);
}
.cp-tile-top {
  display: flex;
  align-items: center;
  gap: 6px;
  color: var(--m-text);
  font-size: 12px;
  font-weight: 700;
}
.cp-dot {
  width: 8px;
  height: 8px;
  border-radius: 50%;
}
.cp-tile-n {
  margin-left: auto;
  color: var(--m-ink);
  font-weight: 800;
}
.cp-tile-amt {
  font-family: var(--m-font-display);
  font-size: 17px;
  font-weight: 700;
}
</style>
