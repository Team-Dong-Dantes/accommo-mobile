<template>
  <!-- The field surface lives in app.scss as `.auth-field`, shared with
       AuthSelect and AuthDocumentCard.

       `lazy-rules` sits before `v-bind="$attrs"` so a caller can still override
       it. Without it Quasar validates on every keystroke: typing the first
       letter of a password failed five rules in a row, and with
       `hide-bottom-space` the message appeared and vanished under the field, so
       the column twitched while you typed. Rules now run on blur and on
       submit — which is when the user has finished saying what they meant. -->
  <q-input v-model="model" borderless stack-label hide-bottom-space color="teal-9" class="auth-field"
    lazy-rules v-bind="$attrs">
    <template v-for="(_, name) in $slots" #[name]="slotData">
      <slot :name="name" v-bind="slotData || {}" />
    </template>
  </q-input>
</template>

<script setup lang="ts">
const model = defineModel<string | number | null>();
</script>
