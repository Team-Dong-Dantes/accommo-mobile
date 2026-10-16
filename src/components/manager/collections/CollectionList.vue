<template>
  <!-- Waiting on the landlord/landlady: one card per transfer. -->
  <div v-if="shownTile === 'confirm'" class="cp-inset cp-cards">
    <div class="cp-list-head"><b>To confirm</b><span>Boarder says they paid</span></div>
    <article v-for="c in shown.confirm" :key="c.key" class="cp-card">
      <div class="cp-card-top">
        <CollectionAvatar :lease="c.lease" />
        <span class="lease-body">
          <span class="lease-name">{{ c.lease.studentName }}</span>
          <span class="lease-sub">{{ c.what }} · {{ PAYMENT_METHOD_LABEL[c.method] ?? c.method }} · {{ c.lease.roomLabel }}</span>
        </span>
        <span class="cp-side">
          <span class="cp-amt cp-amt--lg">{{ formatPeso(c.amount) }}</span>
          <span class="lease-chip" :class="c.waitDays >= 3 ? 'lease-chip--orange' : 'lease-chip--blue'">{{ waitLabel(c.waitDays) }}</span>
        </span>
      </div>
      <button type="button" class="cp-view" @click="review(c.paymentId)">
        <IconifyIcon icon="lucide:eye" width="16" />
        View payment
      </button>
    </article>
    <p v-if="!shown.confirm.length" class="cp-none">{{ nothingLine }}</p>
  </div>

  <section v-else-if="shownTile === 'late'" class="cp-block">
    <div class="room-head">
      <span class="room-name">Overdue</span>
      <span class="cp-count cp-count--late">{{ shown.late.length }}</span>
    </div>
    <div v-for="o in shown.late" :key="o.lease.id" class="lease-row">
      <div class="lease-line">
        <button type="button" class="lease-main" @click="router.push(`/manager/tenant/${o.lease.id}`)">
          <CollectionAvatar :lease="o.lease" />
          <span class="lease-body">
            <span class="lease-name">{{ o.lease.studentName }}</span>
            <span class="lease-sub cp-late">{{ o.what }} · {{ o.lease.roomLabel }}</span>
          </span>
          <span v-if="o.tag === 'leaving'" class="lease-chip lease-chip--orange">{{ leavingLabel(o.lease) }}</span>
          <span class="cp-amt cp-late">{{ formatPeso(o.amount) }}</span>
        </button>
      </div>
      <div class="lease-actions">
        <button type="button" class="lease-act lease-act--ghost" @click="router.push(`/manager/messages?to=${o.lease.studentId}`)">Remind</button>
        <button type="button" class="lease-act" @click="logFor(o.lease)">Log payment</button>
      </div>
    </div>
    <p v-if="!shown.late.length" class="cp-none">{{ nothingLine }}</p>
  </section>

  <section v-else-if="shownTile === 'coming'" class="cp-block">
    <div class="room-head">
      <span class="room-name">Still to come</span>
      <span class="cp-count">{{ shown.coming.length }}</span>
    </div>
    <div v-for="o in shown.coming" :key="o.lease.id" class="lease-row">
      <button type="button" class="lease-main" @click="router.push(`/manager/tenant/${o.lease.id}`)">
        <CollectionAvatar :lease="o.lease" />
        <span class="lease-body">
          <span class="lease-name">{{ o.lease.studentName }}</span>
          <span class="lease-sub">{{ o.what }} · {{ o.lease.roomLabel }}</span>
        </span>
        <span v-if="o.tag === 'new'" class="lease-chip lease-chip--green">New</span>
        <span v-else-if="o.tag === 'leaving'" class="lease-chip lease-chip--orange">{{ leavingLabel(o.lease) }}</span>
        <span class="cp-amt">{{ formatPeso(o.amount) }}</span>
      </button>
    </div>
    <p v-if="!shown.coming.length" class="cp-none">{{ nothingLine }}</p>
  </section>

  <section v-else class="cp-block">
    <div class="room-head">
      <span class="room-name">Paid</span>
      <span class="cp-count cp-count--ok">{{ shown.paid.length }}</span>
      <button type="button" class="room-link" @click="router.push('/manager/profile/history?tab=payments')">All records</button>
    </div>
    <div v-for="l in shown.paid" :key="l.id" class="lease-row">
      <button type="button" class="lease-main" @click="router.push(`/manager/tenant/${l.id}`)">
        <CollectionAvatar :lease="l" />
        <span class="lease-body">
          <span class="lease-name">{{ l.studentName }}</span>
          <span class="lease-sub">{{ allIn ? `Paid for ${formatMonth(col!.month).split(' ')[0]}` : 'Paid up' }} · {{ l.roomLabel }}</span>
        </span>
        <IconifyIcon icon="lucide:chevron-right" width="16" class="cp-chev" />
      </button>
    </div>
    <p v-if="!shown.paid.length" class="cp-none">{{ nothingLine }}</p>
  </section>


  <section v-if="shown.past.length" class="cp-block">
    <div class="room-head">
      <span class="room-name">From past stays</span>
      <span class="cp-count">{{ shown.past.length }}</span>
    </div>
    <div v-for="o in shown.past" :key="o.lease.id" class="lease-row">
      <button type="button" class="lease-main" @click="router.push(`/manager/tenant/${o.lease.id}`)">
        <CollectionAvatar :lease="o.lease" />
        <span class="lease-body">
          <span class="lease-name">{{ o.lease.studentName }}</span>
          <span class="lease-sub">Moved out · {{ o.what }}</span>
        </span>
        <span class="cp-amt">{{ formatPeso(o.amount) }}</span>
      </button>
    </div>
  </section>

  <section v-if="payout" class="cp-block">
    <div class="room-head">
      <span class="room-name">Where boarders pay</span>
      <button type="button" class="room-link" @click="payoutOpen = true">Edit</button>
    </div>
    <div class="lease-row">
      <div class="lease-main cp-static">
        <span class="step-icon"><IconifyIcon icon="lucide:smartphone" width="15" /></span>
        <span class="lease-body">
          <span class="lease-name">{{ payoutWays }}</span>
          <span class="lease-sub">{{ payoutLine }}</span>
        </span>
      </div>
    </div>
  </section>
</template>

<script setup lang="ts">
// Under the tiles: the picked tile's boarders (to confirm, late, coming,
// paid), balances from past stays, and where boarders pay.
import CollectionAvatar from '@/components/manager/CollectionAvatar.vue'
import { Icon as IconifyIcon } from '@iconify/vue'
import { PAYMENT_METHOD_LABEL, formatMonth, formatPeso } from '@/utils/format'
import { useCollections } from './collectionsPanel'

const {
  router,
  col,
  allIn,
  shownTile,
  nothingLine,
  shown,
  leavingLabel,
  waitLabel,
  payout,
  payoutOpen,
  payoutWays,
  payoutLine,
  review,
  logFor,
} = useCollections()
</script>

<style scoped>
.cp-inset {
  display: flex;
  flex-direction: column;
  gap: 8px;
  margin: 0 12px;
}
:global(.shell-tablet) .cp-inset {
  margin: 0;
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
.room-name {
  color: var(--m-ink);
  font-size: 12.5px;
  font-weight: 800;
  letter-spacing: 0.02em;
  text-transform: uppercase;
}
.room-link {
  margin-left: auto;
  padding: 0;
  border: 0;
  background: none;
  color: var(--m-primary-dark);
  cursor: pointer;
  font: inherit;
  font-size: 12px;
  font-weight: 700;
}
.cp-count {
  display: inline-grid;
  min-width: 18px;
  height: 18px;
  place-items: center;
  padding: 0 5px;
  border-radius: 999px;
  background: var(--m-border);
  color: var(--m-text);
  font-size: 10.5px;
  font-weight: 800;
}
.cp-count--late { background: var(--m-danger-soft); color: var(--m-danger); }
.cp-count--ok { background: var(--m-success-soft); color: var(--m-success); }
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
.lease-name {
  color: var(--m-ink);
  font-size: 13.5px;
  font-weight: 700;
}
.lease-sub {
  overflow: hidden;
  color: var(--m-muted);
  font-size: 11.5px;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.cp-late {
  color: var(--m-danger);
}
.lease-sub.cp-late {
  font-weight: 600;
}
.cp-side {
  display: flex;
  flex: 0 0 auto;
  flex-direction: column;
  align-items: flex-end;
  gap: 3px;
}
.cp-amt {
  flex: 0 0 auto;
  color: var(--m-ink);
  font-size: 13.5px;
  font-weight: 700;
  font-variant-numeric: tabular-nums;
}
.cp-chev {
  flex: 0 0 auto;
  color: var(--m-muted);
}
.lease-chip {
  flex: 0 0 auto;
  padding: 3px 9px;
  border-radius: 999px;
  font-size: 10.5px;
  font-weight: 700;
}
.lease-chip--orange { background: var(--m-warning-soft); color: var(--m-warning); }
.lease-chip--blue { background: var(--m-info-soft); color: var(--m-info); }
.lease-chip--green { background: var(--m-success-soft); color: var(--m-success); }
.lease-actions {
  display: flex;
  gap: 8px;
  /* Under the name, past the avatar. */
  padding-left: 46px;
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
.lease-act--ghost {
  border: 1px solid var(--m-border);
  background: var(--m-surface);
  color: var(--m-text);
}
/* DashTodoList's round icon. */
.step-icon {
  display: grid;
  width: 36px;
  height: 36px;
  flex: 0 0 36px;
  place-items: center;
  border-radius: 999px;
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
}
.cp-cards {
  gap: 14px;
}
.cp-list-head {
  display: flex;
  align-items: center;
  gap: 8px;
  color: var(--m-muted);
  font-size: 11.5px;
  font-weight: 600;
}
.cp-list-head b {
  color: var(--m-ink);
  font-size: 12.5px;
  font-weight: 800;
  letter-spacing: 0.02em;
  text-transform: uppercase;
}
.cp-card {
  display: flex;
  flex-direction: column;
  gap: 10px;
  padding: 12px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius);
  background: var(--m-surface);
}
.cp-card-top {
  display: flex;
  align-items: center;
  gap: 10px;
}
.cp-card-top :deep(.ca) {
  width: 36px;
  height: 36px;
  font-size: 12px;
  font-weight: 800;
}
.cp-amt--lg {
  font-family: var(--m-font-display);
  font-size: 15px;
}
.cp-view {
  display: flex;
  min-height: 40px;
  align-items: center;
  justify-content: center;
  gap: 6px;
  border: 1px solid var(--m-primary);
  border-radius: 999px;
  background: var(--m-surface);
  color: var(--m-primary-dark);
  cursor: pointer;
  font: inherit;
  font-size: 13px;
  font-weight: 700;
}
.cp-none {
  margin: 0;
  padding: 14px 12px;
  color: var(--m-muted);
  font-size: 13px;
  text-align: center;
}
</style>
