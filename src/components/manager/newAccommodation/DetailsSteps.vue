<template>
  <section v-if="step === 1" class="sec">
    <h2 class="sec-title">Details</h2>
    <label class="field">
      <span class="field-label">Name <span class="req">*</span></span>
      <input v-model="form.name" type="text" class="field-input" placeholder="e.g. Torres Student Home" />
    </label>
    <label class="field">
      <span class="field-label">Type <span class="req">*</span></span>
      <AppSelect v-model="form.accommodationType" :options="BUILDING_TYPE_LABEL" placeholder="Select type" class="field-input" />
    </label>
    <label class="field">
      <span class="field-label">Accepts <span class="req">*</span></span>
      <AppSelect v-model="form.genderPolicy" :options="GENDER_POLICY_LABEL" placeholder="Select who you accept" class="field-input" />
    </label>
    <!-- Location leads: picking on the map fills the two fields below it,
         so they're a check-and-correct rather than something to type out. -->
    <span class="field-label">Location <span class="req">*</span></span>
    <div class="location-row">
      <button type="button" class="location-btn" @click="locationPickerOpen = true">
        <IconifyIcon icon="lucide:map-pin" width="15" />
        {{ form.lat != null ? 'Change location on map' : 'Set location on map' }}
      </button>
    </div>

    <label class="field">
      <span class="field-label">Purok</span>
      <input v-model="form.purok" type="text" class="field-input" placeholder="e.g. Purok 3" />
    </label>

    <div class="field-row">
      <label class="field">
        <span class="field-label">Barangay <span class="req">*</span></span>
        <input v-model="form.barangay" type="text" class="field-input" placeholder="e.g. San Fabian" />
      </label>
      <label class="field">
        <span class="field-label">City / Municipality <span class="req">*</span></span>
        <input v-model="form.city" type="text" class="field-input" placeholder="e.g. Echague" />
      </label>
    </div>

    <label class="field">
      <span class="field-label">Description</span>
      <textarea v-model="form.description" class="field-input field-textarea" rows="4" placeholder="What makes this place worth staying at?" />
    </label>
  </section>

  <section v-else-if="step === 2" class="sec">
    <h2 class="sec-title">Amenities</h2>
    <p class="sec-hint">Tick what the place has — students filter by these.</p>
    <div class="m-chips">
      <button
        v-for="key in AMENITY_KEYS"
        :key="key"
        type="button"
        class="m-chip"
        :class="{ 'm-chip--on': form.amenities.includes(key) }"
        @click="toggle(form.amenities, key)"
      >
        <IconifyIcon :icon="AMENITY_META[key]?.icon || 'lucide:dot'" width="14" />
        {{ AMENITY_META[key]?.label || key }}
      </button>
    </div>
  </section>

  <section v-else-if="step === 3" class="sec">
    <h2 class="sec-title">House rules <span class="req">*</span></h2>
    <label class="field">
      <span class="field-label">Curfew <span class="req">*</span></span>
      <DateTimeField v-model="form.curfewTime" mode="time" class="field-input" />
    </label>
    <div class="field-row">
      <label class="field">
        <span class="field-label">Quiet hours from <span class="req">*</span></span>
        <DateTimeField v-model="form.quietFrom" mode="time" class="field-input" />
      </label>
      <label class="field">
        <span class="field-label">until <span class="req">*</span></span>
        <DateTimeField v-model="form.quietTo" mode="time" class="field-input" />
      </label>
    </div>
    <p v-if="quietHoursLabel" class="sec-hint">Students will see “{{ quietHoursLabel }}”.</p>
    <label class="field">
      <span class="field-label">Visitor policy <span class="req">*</span></span>
      <input v-model="form.visitorPolicy" type="text" class="field-input" placeholder="e.g. Visitors allowed until 8 PM" />
    </label>
    <p class="sec-hint">Advance and deposit are set per room, once it’s accredited and you add rooms.</p>
    <div class="toggles">
      <label v-for="t in RULE_TOGGLES" :key="t.key" class="toggle-row">
        <span>{{ t.label }}</span>
        <q-toggle v-model="form[t.key]" color="primary" dense />
      </label>
    </div>
  </section>
</template>

<script setup lang="ts">
// Steps 1–3: the listing's details and location, amenities, house rules.
import { AMENITY_KEYS, AMENITY_META, BUILDING_TYPE_LABEL, GENDER_POLICY_LABEL } from '@/utils/listings'
import AppSelect from '@/components/shared/AppSelect.vue'
import DateTimeField from '@/components/shared/DateTimeField.vue'
import { Icon as IconifyIcon } from '@iconify/vue'
import { RULE_TOGGLES } from './model'
import { useNewAccommodation } from './newAccommodation'

const {
  step,
  form,
  quietHoursLabel,
  locationPickerOpen,
  toggle,
} = useNewAccommodation()
</script>

<style scoped>
.sec {
  display: flex;
  flex-direction: column;
  gap: 10px;
}
.sec-title {
  margin: 4px 0 0;
  padding: 0 2px;
  color: var(--m-ink);
  font-size: 12.5px;
  font-weight: 700;
  letter-spacing: 0.02em;
  text-transform: uppercase;
}
.sec-title:first-child {
  margin-top: 0;
}
.sec-hint {
  margin: -4px 0 0;
  padding: 0 2px;
  color: var(--m-muted);
  font-size: 12px;
  line-height: 1.5;
}
.field {
  display: flex;
  flex: 1;
  min-width: 0;
  flex-direction: column;
  gap: 4px;
}
.field-row {
  display: flex;
  gap: 8px;
}
.field-label {
  color: var(--m-muted);
  font-size: 12px;
  font-weight: 700;
  letter-spacing: 0.02em;
  text-transform: uppercase;
}
.field-input {
  min-height: 44px;
  padding: 0 12px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius-sm);
  background-color: var(--m-surface);
  color: var(--m-ink);
  font: inherit;
  font-size: 14px;
}
.field-textarea {
  min-height: 90px;
  padding: 10px 12px;
  resize: vertical;
}
.location-row {
  display: flex;
  align-items: center;
  gap: 10px;
}
.location-btn {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  min-height: 38px;
  padding: 0 14px;
  border: 1px solid var(--m-border);
  border-radius: 999px;
  background: var(--m-bg);
  color: var(--m-text);
  cursor: pointer;
  font: inherit;
  font-size: 12.5px;
  font-weight: 700;
  -webkit-tap-highlight-color: transparent;
}
.toggles {
  display: flex;
  flex-direction: column;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius);
  background: var(--m-surface);
  overflow: hidden;
}
.toggle-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 10px 12px;
  border-top: 1px solid var(--m-border);
  color: var(--m-text);
  font-size: 13.5px;
  font-weight: 600;
}
.toggles > .toggle-row:first-child {
  border-top: 0;
}
.req {
  color: var(--m-negative, #c62828);
  font-weight: 800;
}
</style>
