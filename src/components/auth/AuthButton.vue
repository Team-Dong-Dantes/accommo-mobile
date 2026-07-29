<template>
  <q-btn unelevated class="primary-action-btn full-width" v-bind="$attrs">
    <slot />
  </q-btn>
</template>

<style scoped>
.primary-action-btn {
  background: #00796b !important;
  color: white !important;
  height: 56px;
  border-radius: 16px;
  font-size: 16px;
  font-weight: 600;
  box-shadow: 0 6px 15px rgba(0, 121, 107, 0.3);
}
</style>
