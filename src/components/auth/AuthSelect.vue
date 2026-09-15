<template>
  <!-- The field surface lives in app.scss as `.auth-field`, shared with
       AuthInput. The popup gets its own class because it is
       teleported out of this component's tree — `.auth-select-menu` in app.scss
       is where it is styled. -->
  <q-select
    v-model="model"
    borderless
    stack-label
    hide-bottom-space
    color="teal-9"
    class="auth-field"
    popup-content-class="auth-select-menu"
    hide-dropdown-icon
    lazy-rules
    v-bind="$attrs"
  >
    <!-- Quasar's own arrow is hidden and replaced here rather than set through
         `dropdown-icon`, because that prop feeds QIcon — which knows nothing
         about Iconify, and renders an unrecognised name as literal text through
         the Material Icons font. "lucide:chevron-down" came out as the string,
         colon and all, inside every select on the register flow. Iconify names
         only ever go to <IconifyIcon>. -->
    <template #append>
      <IconifyIcon icon="lucide:chevron-down" width="18" class="auth-select-arrow" />
    </template>

    <template #selected-item="scope">
      <div class="auth-select-value">{{ collapse(String(scope.opt)) }}</div>
    </template>

    <!-- Quasar's default option row has no mark for the current choice, so
         reopening a list left you rereading it to find where you were. -->
    <template #option="{ itemProps, opt, selected }">
      <q-item v-bind="itemProps" class="auth-select-option" :class="{ 'is-selected': selected }">
        <q-item-section>
          <q-item-label>{{ opt }}</q-item-label>
        </q-item-section>
        <q-item-section v-if="selected" side>
          <IconifyIcon icon="lucide:check" width="16" />
        </q-item-section>
      </q-item>
    </template>

    <template v-for="(_, name) in $slots" #[name]="slotData">
      <slot :name="name" v-bind="slotData || {}" />
    </template>
  </q-select>
</template>

<script setup lang="ts">
const model = defineModel<string | number | null>();

/**
 * What the collapsed field shows.
 *
 * This used to ellipsise at 34 characters, which cut the useful half off the
 * long values: "College of Computing Studies, Information and Communication
 * Technology (CCSICT)" became "College of Computing Studies, Info…", losing the
 * acronym — the one part a student recognises at a glance.
 *
 * Every ISU college and several programmes carry their short form in brackets,
 * so that is what the field shows whenever there is one. Applying it only to the
 * long values read worse, not better: "CCSICT" would have sat next to "College
 * of Nursing (CON)" in the same field on the same screen. Anything without an
 * acronym shows in full, wrapping to a second line if it needs to, and the open
 * list always shows the full name either way.
 */
function collapse(val: string): string {
  return val.match(/\(([^)]+)\)\s*$/)?.[1] ?? val;
}
</script>

<style scoped>
/* Wraps rather than ellipsises — a long name with no acronym is better read
   over two lines than cut in half. */
.auth-select-value {
  width: 100%;
  min-width: 0;
  line-height: 1.3;
}

.auth-select-arrow {
  color: var(--m-muted);
}
</style>
