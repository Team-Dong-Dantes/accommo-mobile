<template>
  <!-- Phone: the detail is a bottom sheet over the list, as it always was. -->
  <q-dialog
    v-if="!isTablet"
    :model-value="open"
    position="bottom"
    @update:model-value="(v: boolean) => emit('update:open', v)"
  >
    <slot />
  </q-dialog>

  <!-- Tablet: the same markup, in the right half. -->
  <div v-else class="split-pane">
    <slot v-if="open" />
    <div v-else class="page-split-empty">
      <IconifyIcon :icon="icon" width="26" />
      <p>{{ hint }}</p>
    </div>
  </div>
</template>

<script setup lang="ts">
import { isTablet } from '@/utils/useTabletMode'

// Where a screen's detail goes, without the screen having to write it twice.
//
// Concerns keeps its detail in a QDialog, and Quasar portals a dialog to <body>
// — outside the shell entirely — so no amount of CSS can pull it into a pane the
// way ChatThread and TicketThread were pulled in. Those two are inline overlays;
// this one genuinely is a dialog.
//
// The obvious fix, a shared ConcernDetail component, turned out to be the wrong
// one: the two roles' cards look alike but are not. The student's carries a
// status timeline and reads the manager's reply; the manager's carries the
// tenant's name and avatar, a reply box, four decision buttons and Escalate to
// OSAS. One component covering both would be two cards behind a v-if with a prop
// list stretched across them.
//
// So nothing is shared except the decision of where to put the thing. Each page
// keeps its own card, written once, and passes it here as a slot: a <slot/> in
// two branches of a v-if renders in whichever branch is live, and slot content
// is compiled in the parent's scope, so each page's scoped styles still reach
// its own card.
defineProps<{
  /** Whether a detail is open. Phone: drives the dialog. Tablet: the pane fills. */
  open: boolean
  /** Empty-pane icon, shown on a tablet while nothing is selected. */
  icon: string
  /** Empty-pane line, naming what the pane is waiting for. */
  hint: string
}>()

const emit = defineEmits<{ 'update:open': [boolean] }>()
</script>

<style scoped>
/* The right half. It scrolls on its own so a long concern does not scroll the
   list beside it. */
.split-pane {
  min-width: 0;
  height: 100%;
  overflow-y: auto;
}

/* The card was drawn as a bottom sheet — capped at 480px, centred, rounded along
   its top edge only because that edge was the one you could see. In a pane it is
   the pane's content, so it gives all three back. :deep because the card belongs
   to the page that passed it in, not to this component. */
.split-pane :deep(.detail-sheet) {
  max-width: none;
  padding-bottom: 16px;
  border-radius: 0;
}
</style>
