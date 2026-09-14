<template>
  <!-- One date/time control for the whole app, in place of a bare
       <input type="date"> / <input type="datetime-local">. The native controls
       render as a cramped row of spinners with a pinhole calendar icon on
       desktop, and differ on every platform; this is a calendar and a clock,
       the same everywhere, at thumb size. -->
  <button type="button" class="dtf" :class="{ 'dtf--set': !!modelValue }" @click="open">
    <IconifyIcon :icon="mode === 'date' ? 'lucide:calendar' : 'lucide:calendar-clock'" width="15" />
    <span class="dtf-text">{{ display || placeholder || 'Pick a date' }}</span>
  </button>

  <q-dialog v-model="showing">
    <q-card class="pick">
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

      <q-date
        v-show="step === 'date'"
        v-model="draftDate"
        mask="YYYY-MM-DD"
        minimal
        flat
        :options="allowed"
        class="pick-body"
      />
      <q-time v-if="mode === 'datetime'" v-show="step === 'time'" v-model="draftTime" mask="HH:mm" flat class="pick-body" />

      <div class="pick-actions">
        <button type="button" class="pick-ghost" @click="clear">Clear</button>
        <span class="pick-spacer" />
        <button type="button" class="pick-ghost" @click="showing = false">Cancel</button>
        <button type="button" class="pick-primary" :disabled="!draftDate" @click="commit">Done</button>
      </div>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { computed, ref } from 'vue'
import { Icon as IconifyIcon } from '@iconify/vue'

const props = withDefaults(
  defineProps<{
    /** 'YYYY-MM-DD' in date mode, 'YYYY-MM-DDTHH:mm' in datetime mode — the
        same strings the native inputs used, so callers keep their own parsing. */
    modelValue: string
    mode?: 'date' | 'datetime'
    /** Earliest selectable day, 'YYYY-MM-DD'. Later days are always allowed. */
    min?: string
    placeholder?: string
  }>(),
  { mode: 'datetime', min: '', placeholder: '' },
)

const emit = defineEmits<{ 'update:modelValue': [string] }>()

const showing = ref(false)
const step = ref<'date' | 'time'>('date')
const draftDate = ref('')
const draftTime = ref('')

function pad(n: number) {
  return String(n).padStart(2, '0')
}

/** The next whole hour: the sensible default for a notice, never "right now". */
function nextHour(): string {
  const d = new Date(Date.now() + 60 * 60 * 1000)
  return `${pad(d.getHours())}:00`
}

function open() {
  const [datePart = '', timePart = ''] = props.modelValue.split('T')
  draftDate.value = datePart
  draftTime.value = timePart.slice(0, 5) || nextHour()
  step.value = 'date'
  showing.value = true
}

function commit() {
  if (!draftDate.value) return
  emit('update:modelValue', props.mode === 'date' ? draftDate.value : `${draftDate.value}T${draftTime.value}`)
  showing.value = false
}

function clear() {
  emit('update:modelValue', '')
  showing.value = false
}

/** QDate calls this per day; comparing the same 'YYYY-MM-DD' shape it hands in. */
function allowed(day: string): boolean {
  return !props.min || day.replace(/\//g, '-') >= props.min
}

function prettyDate(iso: string): string {
  const d = new Date(`${iso}T00:00`)
  return Number.isNaN(d.getTime()) ? iso : d.toLocaleDateString([], { month: 'short', day: 'numeric', year: 'numeric' })
}

function prettyTime(hhmm: string): string {
  const d = new Date(`2000-01-01T${hhmm}`)
  return Number.isNaN(d.getTime()) ? hhmm : d.toLocaleTimeString([], { hour: 'numeric', minute: '2-digit' })
}

const display = computed(() => {
  if (!props.modelValue) return ''
  const [datePart = '', timePart = ''] = props.modelValue.split('T')
  if (props.mode === 'date') return prettyDate(datePart)
  return `${prettyDate(datePart)} · ${prettyTime(timePart.slice(0, 5))}`
})
</script>

<style scoped>
.dtf {
  display: flex;
  min-height: 38px;
  min-width: 0;
  flex: 1 1 auto;
  align-items: center;
  gap: 7px;
  padding: 0 12px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius-sm);
  background: var(--m-bg);
  color: var(--m-muted);
  cursor: pointer;
  font: inherit;
  font-size: 13px;
  text-align: left;
  -webkit-tap-highlight-color: transparent;
}
.dtf--set {
  color: var(--m-text);
  font-weight: 600;
}
.dtf-text {
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.pick {
  display: flex;
  width: 100%;
  max-width: 340px;
  flex-direction: column;
  padding: 12px;
  border-radius: var(--m-radius-lg);
  background: var(--m-surface);
}
.pick-steps {
  display: flex;
  gap: 6px;
  padding-bottom: 10px;
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
.pick-actions {
  display: flex;
  align-items: center;
  gap: 8px;
  padding-top: 10px;
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
