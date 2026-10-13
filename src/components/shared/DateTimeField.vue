<template>
  <!-- One date/time control for the whole app, in place of a bare
       <input type="date|time|month|datetime-local">. The native controls render
       as a cramped row of spinners with a pinhole calendar icon on desktop, and
       differ on every platform; this is a calendar and a clock, the same
       everywhere, at thumb size. Like AppSelect, the box is whatever class the
       screen gives it (`.picker-field` in app.scss is only the default), and the
       default slot replaces the contents when a screen wants its own trigger.
       The sheet is teleported, so it is not really inside the button. -->
  <button
    type="button"
    class="picker-field"
    :class="{ 'picker-field--set': !!modelValue, 'picker-field--error': !!error }"
    :disabled="disable"
    :aria-label="label || placeholder || undefined"
    @click="open"
  >
    <slot>
      <span class="picker-field__body">
        <span v-if="label" class="picker-field__label">{{ label }}</span>
        <span class="picker-field__text">{{ display || placeholder || (label ? '' : EMPTY[mode]) }}</span>
        <span v-if="error" class="picker-field__error">{{ error }}</span>
      </span>
      <IconifyIcon :icon="ICON[mode]" width="16" class="picker-field__icon" />
    </slot>

    <AppModal v-model="showing" :title="label || placeholder || EMPTY[mode]" size="sm">
      <!-- Date and time are two steps rather than two stacked panels: both at
           once is taller than a phone screen, and the pills double as a summary
           of what has been chosen so far. -->
      <div v-if="mode === 'datetime'" class="pick-steps">
        <button type="button" class="step" :class="{ 'step--on': step === 'date' }" @click="step = 'date'">
          {{ draftDate ? prettyDate(draftDate) : 'Date' }}
        </button>
        <button type="button" class="step" :class="{ 'step--on': step === 'time' }" @click="step = 'time'">
          {{ draftTime ? prettyTime(draftTime) : 'Time' }}
        </button>
      </div>

      <!-- A month is twelve buttons under a year stepper; QDate has no month-only mode. -->
      <template v-if="mode === 'month'">
        <div class="pick-year">
          <button type="button" class="pick-nav" aria-label="Previous year" @click="draftYear--">
            <IconifyIcon icon="lucide:chevron-left" width="18" />
          </button>
          <span class="pick-year-text">{{ draftYear }}</span>
          <button type="button" class="pick-nav" aria-label="Next year" @click="draftYear++">
            <IconifyIcon icon="lucide:chevron-right" width="18" />
          </button>
        </div>
        <div class="pick-months">
          <button
            v-for="(name, i) in MONTHS"
            :key="name"
            type="button"
            class="pick-month"
            :class="{ 'pick-month--on': modelValue === monthValue(i) }"
            :disabled="!monthAllowed(i)"
            @click="commitMonth(i)"
          >
            {{ name }}
          </button>
        </div>
      </template>

      <q-date
        v-else-if="mode !== 'time'"
        v-show="step === 'date'"
        v-model="draftDate"
        mask="YYYY-MM-DD"
        minimal
        flat
        :options="allowed"
        class="pick-body"
      />
      <q-time
        v-if="mode === 'time' || mode === 'datetime'"
        v-show="mode === 'time' || step === 'time'"
        v-model="draftTime"
        mask="HH:mm"
        flat
        class="pick-body"
      />

      <template v-if="mode !== 'month'" #footer>
        <button type="button" class="pick-ghost" @click="clear">Clear</button>
        <span class="pick-spacer" />
        <button type="button" class="pick-ghost" @click="showing = false">Cancel</button>
        <button type="button" class="pick-primary" :disabled="!ready" @click="commit">Done</button>
      </template>
    </AppModal>
  </button>
</template>

<script setup lang="ts">
import { computed, ref } from 'vue'
import { useFormChild } from 'quasar'
import { Icon as IconifyIcon } from '@iconify/vue'
import AppModal from '@/components/shared/AppModal.vue'

type Mode = 'date' | 'datetime' | 'time' | 'month'

const props = withDefaults(
  defineProps<{
    /** The same strings the native inputs used, so callers keep their own parsing:
        date 'YYYY-MM-DD', datetime 'YYYY-MM-DDTHH:mm', time 'HH:mm', month 'YYYY-MM'. */
    modelValue: string
    mode?: Mode
    /** Earliest selectable day, 'YYYY-MM-DD'. */
    min?: string
    /** Latest selectable day, 'YYYY-MM-DD'. */
    max?: string
    label?: string
    placeholder?: string
    disable?: boolean
    /** Same contract as a Quasar field's rules; checked by a parent QForm. */
    rules?: Array<(val: string) => true | string>
  }>(),
  { mode: 'datetime', min: '', max: '', label: '', placeholder: '', disable: false, rules: () => [] },
)

const emit = defineEmits<{ 'update:modelValue': [string] }>()

const EMPTY: Record<Mode, string> = {
  date: 'Pick a date',
  datetime: 'Pick a date and time',
  time: 'Pick a time',
  month: 'Pick a month',
}
const ICON: Record<Mode, string> = {
  date: 'lucide:calendar',
  datetime: 'lucide:calendar-clock',
  time: 'lucide:clock',
  month: 'lucide:calendar',
}
const MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']

const showing = ref(false)
const step = ref<'date' | 'time'>('date')
const draftDate = ref('')
const draftTime = ref('')
const draftYear = ref(new Date().getFullYear())
const error = ref('')

function pad(n: number) {
  return String(n).padStart(2, '0')
}

/** The next whole hour: the sensible default for a notice, never "right now". */
function nextHour(): string {
  const d = new Date(Date.now() + 60 * 60 * 1000)
  return `${pad(d.getHours())}:00`
}

function open() {
  const value = props.modelValue
  if (props.mode === 'time') {
    draftTime.value = value.slice(0, 5)
  } else if (props.mode === 'month') {
    draftYear.value = Number(value.slice(0, 4)) || new Date().getFullYear()
  } else {
    const [datePart = '', timePart = ''] = value.split('T')
    draftDate.value = datePart
    draftTime.value = timePart.slice(0, 5) || nextHour()
  }
  step.value = 'date'
  showing.value = true
}

const ready = computed(() => (props.mode === 'time' ? !!draftTime.value : !!draftDate.value))

function set(value: string) {
  emit('update:modelValue', value)
  showing.value = false
  if (error.value) validate(value)
}

function commit() {
  if (!ready.value) return
  if (props.mode === 'time') set(draftTime.value)
  else if (props.mode === 'date') set(draftDate.value)
  else set(`${draftDate.value}T${draftTime.value}`)
}

function clear() {
  set('')
}

function monthValue(i: number): string {
  return `${draftYear.value}-${pad(i + 1)}`
}

/** A month is allowed when any of its days is: compare on 'YYYY-MM' prefixes. */
function monthAllowed(i: number): boolean {
  const m = monthValue(i)
  return (!props.min || m >= props.min.slice(0, 7)) && (!props.max || m <= props.max.slice(0, 7))
}

function commitMonth(i: number) {
  set(monthValue(i))
}

/** QDate calls this per day; comparing the same 'YYYY-MM-DD' shape it hands in. */
function allowed(day: string): boolean {
  const d = day.replace(/\//g, '-')
  return (!props.min || d >= props.min) && (!props.max || d <= props.max)
}

function validate(value = props.modelValue): boolean {
  for (const rule of props.rules) {
    const result = rule(value)
    if (result !== true) {
      error.value = result
      return false
    }
  }
  error.value = ''
  return true
}

useFormChild({ validate: () => validate(), resetValidation: () => (error.value = ''), requiresQForm: false })

function prettyDate(iso: string): string {
  const d = new Date(`${iso}T00:00`)
  return Number.isNaN(d.getTime()) ? iso : d.toLocaleDateString([], { month: 'short', day: 'numeric', year: 'numeric' })
}

function prettyTime(hhmm: string): string {
  const d = new Date(`2000-01-01T${hhmm}`)
  return Number.isNaN(d.getTime()) ? hhmm : d.toLocaleTimeString([], { hour: 'numeric', minute: '2-digit' })
}

function prettyMonth(ym: string): string {
  const d = new Date(`${ym}-01T00:00`)
  return Number.isNaN(d.getTime()) ? ym : d.toLocaleDateString([], { month: 'long', year: 'numeric' })
}

const display = computed(() => {
  const value = props.modelValue
  if (!value) return ''
  if (props.mode === 'time') return prettyTime(value.slice(0, 5))
  if (props.mode === 'month') return prettyMonth(value.slice(0, 7))
  const [datePart = '', timePart = ''] = value.split('T')
  if (props.mode === 'date') return prettyDate(datePart)
  return `${prettyDate(datePart)} · ${prettyTime(timePart.slice(0, 5))}`
})
</script>

<style scoped>
.pick-steps {
  display: flex;
  gap: 6px;
}
.step {
  min-height: 34px;
  flex: 1 1 0;
  padding: 0 10px;
  border: 1px solid var(--m-border);
  border-radius: 999px;
  background: var(--m-bg);
  color: var(--m-muted);
  cursor: pointer;
  font: inherit;
  font-size: 12px;
  font-weight: 700;
}
.step--on {
  border-color: var(--m-primary);
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
}
/* QDate and QTime bring their own surface; let the card's own background show
   through so the picker does not sit on a second, slightly different white. */
.pick-body {
  width: 100%;
  box-shadow: none;
}
.pick-year {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 10px;
}
.pick-year-text {
  color: var(--m-ink);
  font-size: 16px;
  font-weight: 700;
}
.pick-nav {
  display: grid;
  width: 38px;
  height: 38px;
  place-items: center;
  border: 1px solid var(--m-border);
  border-radius: 999px;
  background: var(--m-bg);
  color: var(--m-text);
  cursor: pointer;
}
.pick-months {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 8px;
}
.pick-month {
  min-height: 44px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius-sm);
  background: var(--m-bg);
  color: var(--m-text);
  cursor: pointer;
  font: inherit;
  font-size: 13.5px;
  font-weight: 600;
}
.pick-month--on {
  border-color: var(--m-primary);
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
  font-weight: 700;
}
.pick-month:disabled {
  opacity: 0.4;
  cursor: default;
}
.pick-spacer {
  flex: 1 1 auto;
}
.pick-ghost,
.pick-primary {
  min-height: 38px;
  padding: 0 14px;
  border-radius: 999px;
  cursor: pointer;
  font: inherit;
  font-size: 12.5px;
  font-weight: 700;
  -webkit-tap-highlight-color: transparent;
}
.pick-ghost {
  border: 1px solid var(--m-border);
  background: var(--m-bg);
  color: var(--m-text);
}
.pick-primary {
  border: 0;
  background: var(--m-primary);
  color: #fff;
}
.pick-primary:disabled {
  opacity: 0.5;
}
</style>
