<template>
  <q-btn unelevated no-caps class="primary-action-btn full-width" v-bind="$attrs">
    <slot />
  </q-btn>
</template>

<style scoped>
.primary-action-btn {
  height: 56px;
  border-radius: 14px;
  background: var(--m-primary-dark) !important;
  color: white !important;
  font-size: 16px;
  font-weight: 600;
  transition: transform 0.12s ease;
}
/* The teal glow this used to carry (0 6px 15px rgba(0,121,107,.3)) dated the
   screen more than anything else on it. A press response says "tapped" without
   the button shouting while idle. */
.primary-action-btn:active {
  transform: scale(0.985);
}

@media (prefers-reduced-motion: reduce) {
  .primary-action-btn { transition: none; }
}
</style>
