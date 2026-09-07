<template>
  <div class="divider">
    <div class="divider-line"></div>
    <span>
      <slot>OR</slot>
    </span>
    <div class="divider-line"></div>
  </div>
</template>

<style scoped>
.divider {
  display: flex;
  align-items: center;
  margin: 24px 0;
  gap: 12px;
}

.divider span {
  font-size: 12px;
  color: var(--m-muted);
  font-weight: 600;
}

.divider-line {
  flex: 1;
  height: 1px;
  background: var(--m-border);
}
</style>
