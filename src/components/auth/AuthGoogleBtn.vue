<template>
  <q-btn unelevated class="google-btn full-width" v-bind="$attrs">
    <img src="https://www.gstatic.com/firebasejs/ui/2.0.0/images/auth/google.svg" width="20" class="q-mr-sm" />
    <slot>Continue with Google</slot>
  </q-btn>
</template>

<style scoped>
.google-btn {
  height: 56px;
  border-radius: 16px;
  background: #f5f5f5;
  color: #222;
  font-weight: 600;
}
</style>
