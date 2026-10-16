<template>
  <h2 v-if="isDesktop" class="desk-col-title">Support tickets</h2>
  <div class="sec-head">
    <p class="sec-hint"><slot /></p>
    <button v-if="!isDesktop" type="button" class="sec-link" @click="emit('new')">New ticket</button>
  </div>

  <EmptyState
    v-if="!tickets.length"
    variant="compact"
    icon="lucide:life-buoy"
    title="No tickets yet"
    :message="emptyMessage"
  />
  <div v-else class="group">
    <button v-for="t in tickets" :key="t.id" type="button" class="ticket-row" @click="emit('open', t)">
      <span class="ticket-body">
        <span class="ticket-subject">{{ t.subject }}</span>
        <span class="ticket-when">{{ since(t.reportedAt) }}</span>
      </span>
      <span class="ticket-chip" :class="`ticket-chip--${statusColor(TICKET_STATUS, t.status)}`">{{ statusText(TICKET_STATUS, t.status) }}</span>
    </button>
  </div>

  <!-- Desktop: the tickets half's footer. -->
  <div v-if="isDesktop" class="desk-foot">
    <button type="button" class="desk-foot-btn" @click="emit('new')">
      <IconifyIcon icon="lucide:plus" width="17" />
      New ticket
    </button>
  </div>
</template>

<script setup lang="ts">
import { Icon as IconifyIcon } from '@iconify/vue'
import { statusText, statusColor, TICKET_STATUS } from '@/utils/format'
import { since } from '@/utils/notifications'
import { isDesktop } from '@/utils/useTabletMode'
import type { Ticket } from '@/utils/useOsasTickets'
import EmptyState from '@/components/shared/EmptyState.vue'

defineProps<{ tickets: Ticket[]; emptyMessage: string }>()
const emit = defineEmits<{ open: [Ticket]; new: [] }>()
</script>

<style scoped>
.sec-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 8px;
}
.sec-hint {
  margin: 0;
  color: var(--m-muted);
  font-size: 12px;
}
.sec-link {
  flex: 0 0 auto;
  border: 0;
  background: transparent;
  color: var(--m-primary-dark);
  cursor: pointer;
  font: inherit;
  font-size: 12.5px;
  font-weight: 700;
  -webkit-tap-highlight-color: transparent;
}
.group {
  display: flex;
  flex-direction: column;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius);
  background: var(--m-bg);
  overflow: hidden;
}
.ticket-row {
  display: flex;
  width: 100%;
  align-items: center;
  justify-content: space-between;
  gap: 10px;
  padding: 10px 12px;
  border: 0;
  border-top: 1px solid var(--m-border);
  background: transparent;
  cursor: pointer;
  font: inherit;
  text-align: left;
  -webkit-tap-highlight-color: transparent;
}
.group > .ticket-row:first-child {
  border-top: 0;
}
.ticket-body {
  display: flex;
  min-width: 0;
  flex-direction: column;
  gap: 1px;
}
.ticket-subject {
  color: var(--m-ink);
  font-size: 13.5px;
  font-weight: 700;
}
.ticket-when {
  color: var(--m-muted);
  font-size: 11px;
}
.ticket-chip {
  flex: 0 0 auto;
  padding: 3px 9px;
  border-radius: 999px;
  font-size: 10.5px;
  font-weight: 700;
}
.ticket-chip--green {
  background: var(--m-success-soft);
  color: var(--m-success);
}
.ticket-chip--amber,
.ticket-chip--orange {
  background: var(--m-warning-soft);
  color: var(--m-warning);
}
.ticket-chip--grey {
  background: var(--m-bg);
  color: var(--m-muted);
}
</style>
