<template>
  <AppModal :model-value="modelValue" title="Boarders payment timeline" icon="lucide:file-chart-column" @update:model-value="emit('update:modelValue', $event)">
    <div class="rs">
      <p class="rs-blurb">Each boarder's rent from January to December: paid or not.</p>

      <button type="button" class="rs-mini" aria-label="Open full preview" @click="previewOpen = true">
        <span class="rs-paper">
          <span class="rs-l rs-l--t" /><span class="rs-l rs-l--s" /><span class="rs-l rs-l--r" /><span class="rs-l rs-l--h" />
          <span class="rs-cells"><i v-for="(m, i) in mini" :key="i" :class="m" /></span>
        </span>
        <span class="rs-zoom"><IconifyIcon icon="lucide:maximize-2" width="12" />Preview</span>
      </button>

      <div class="rs-card">
        <div class="rs-card-h">Include</div>
        <label v-if="properties.length > 1" class="rs-line">
          <span class="rs-lbl">Property</span>
          <AppSelect v-model="propId" class="rs-pill" :options="propertyOptions" label="Property" />
        </label>
        <label class="rs-line">
          <span class="rs-lbl">Year</span>
          <AppSelect v-model="year" class="rs-pill" :options="years" label="Year" />
        </label>
        <label class="rs-line">
          <span class="rs-lbl">Group by</span>
          <AppSelect v-model="groupBy" class="rs-pill" :options="[{ value: 'room', label: 'Room' }, { value: 'none', label: 'None' }]" label="Group by" />
        </label>
        <button v-for="t in toggles" :key="t.label" type="button" role="switch" class="rs-line rs-switch" :aria-checked="t.get()" @click="t.set(!t.get())">
          <span class="rs-lbl">{{ t.label }}</span>
          <span class="rs-track" :class="{ on: t.get() }"><span class="rs-knob" /></span>
        </button>
      </div>

      <div class="rs-card">
        <div class="rs-card-h">Page &amp; signature</div>
        <label class="rs-line">
          <span class="rs-lbl">Paper</span>
          <AppSelect v-model="paper" class="rs-pill" :options="[{ value: 'a4', label: 'A4' }, { value: 'long', label: 'Long (8.5 × 13 in)' }]" label="Paper" />
        </label>
        <label class="rs-line">
          <span class="rs-lbl">Orientation</span>
          <AppSelect v-model="orientation" class="rs-pill" :options="[{ value: 'portrait', label: 'Portrait' }, { value: 'landscape', label: 'Landscape' }]" label="Orientation" />
        </label>
        <div class="rs-line">
          <span class="rs-lbl">Prepared by</span>
          <span class="rs-val">{{ landlord.name || '—' }}</span>
        </div>
      </div>
    </div>

    <template #footer>
      <div class="rs-actions">
        <button type="button" class="rs-btn rs-btn--ghost" :disabled="busy" @click="run('share')">
          <IconifyIcon icon="lucide:share" width="16" />Share
        </button>
        <button type="button" class="rs-btn rs-btn--main" :disabled="busy" @click="run('print')">
          <IconifyIcon icon="lucide:printer" width="16" />Print / Save as PDF
        </button>
      </div>
    </template>
  </AppModal>

  <q-dialog v-model="previewOpen" maximized>
    <div class="pv">
      <header class="pv-bar">
        <span class="pv-title">Preview</span>
        <button type="button" class="pv-close" aria-label="Close preview" @click="previewOpen = false"><IconifyIcon icon="lucide:x" width="20" /></button>
      </header>
      <div class="pv-host">
        <iframe class="pv-frame" title="Report preview" :srcdoc="html" :style="frameStyle" />
      </div>
    </div>
  </q-dialog>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import { Notify } from 'quasar'
import { Icon as IconifyIcon } from '@iconify/vue'
import { supabase, authUser } from '@/utils/supabase'
import type { MoneyLease } from '@/api/landlordMoney'
import type { CollectionLedgerRow } from '@/utils/collections'
import { manilaToday } from '@/utils/payments'
import { buildingTypeLabel } from '@/utils/listings'
import { landlordTitle } from '@/utils/format'
import { printHtml, shareHtml } from '@/utils/print'
import { renderRentReport, reportStays, yearOptions, type Orientation, type Paper, type RentReportOptions } from '@/utils/rentReport'
import AppModal from '@/components/shared/AppModal.vue'
import AppSelect from '@/components/shared/AppSelect.vue'

// Rent report: the preview, the options and Print / Share for the "Boarders
// payment timeline". The document itself is built in utils/rentReport.ts. Needs
// no data of its own beyond the property's address and the landlord/landlady's
// name, which it reads when it opens.
const props = defineProps<{
  modelValue: boolean
  leases: MoneyLease[]
  ledger: CollectionLedgerRow[]
  properties: { id: string; name: string }[]
  /** The property the panel was showing; 'all' opens on the first. */
  propertyId: string
}>()
const emit = defineEmits<{ 'update:modelValue': [open: boolean] }>()

const propId = ref('')
const year = ref('')
const groupBy = ref<'room' | 'none'>('room')
const former = ref(true)
const owing = ref(false)
const amounts = ref(false)
const paper = ref<Paper>('a4')
const orientation = ref<Orientation>('landscape')
const busy = ref(false)
const previewOpen = ref(false)

const today = computed(() => manilaToday())
const propertyOptions = computed(() => props.properties.map((p) => ({ value: p.id, label: p.name })))
const years = computed(() => yearOptions(props.ledger, today.value))
const toggles = [
  { label: 'Include past boarders', get: () => former.value, set: (v: boolean) => (former.value = v) },
  { label: 'Only boarders with an unpaid month', get: () => owing.value, set: (v: boolean) => (owing.value = v) },
  { label: 'Show amounts', get: () => amounts.value, set: (v: boolean) => (amounts.value = v) },
]

const details = ref<Record<string, { type: string; address: string }>>({})
const landlord = ref({ name: '', phone: '', title: landlordTitle(null) })
async function loadDetails() {
  const { data: auth } = await authUser()
  const me = auth?.user?.id
  if (!me) return
  const [{ data: acc }, { data: u }] = await Promise.all([
    supabase.from('accommodations').select('id,address,barangay,city,accommodation_type').eq('landlord_id', me),
    supabase.from('users_full').select('full_name,phone,sex').eq('id', me).maybeSingle(),
  ])
  details.value = Object.fromEntries(
    (Array.isArray(acc) ? acc : []).map((a) => [a.id, { type: buildingTypeLabel(a.accommodation_type), address: [a.address, a.barangay, a.city].filter(Boolean).join(', ') }]),
  )
  if (u) landlord.value = { name: u.full_name ?? '', phone: u.phone ?? '', title: landlordTitle(u.sex) }
}

// Opening starts from the panel's current property and this year; details are read fresh.
watch(
  () => props.modelValue,
  (open) => {
    if (!open) return
    propId.value = props.propertyId !== 'all' ? props.propertyId : (props.properties[0]?.id ?? '')
    year.value = today.value.slice(0, 4)
    void loadDetails().catch(() => undefined)
  },
  { immediate: true },
)

const opts = computed<RentReportOptions>(() => ({
  property: { name: props.properties.find((p) => p.id === propId.value)?.name ?? 'Accommodation', ...(details.value[propId.value] ?? { type: '', address: '' }) },
  landlord: landlord.value,
  leases: props.leases.filter((l) => l.accommodationId === propId.value),
  ledger: props.ledger,
  year: year.value || today.value.slice(0, 4),
  groupBy: groupBy.value === 'room' ? 'room' : '',
  former: former.value,
  owing: owing.value,
  amounts: amounts.value,
  paper: paper.value,
  orientation: orientation.value,
  today: today.value,
  at: new Date(),
}))
const html = computed(() => (props.modelValue || previewOpen.value ? renderRentReport(opts.value) : ''))

// The thumbnail: header fill, group fill, then white rows, as in the finished page.
const mini = computed(() => {
  const n = Math.min(Math.max(reportStays(opts.value).length, 1), 4)
  return [...Array(14).fill('h'), ...Array(14).fill('g'), ...Array(14 * n).fill('w')] as string[]
})

// The A4/Long page is mm wide; scale it down to the phone and let it fill the height.
const frameStyle = computed(() => {
  const mmW = (opts.value.paper === 'a4' ? [210, 297] : [215.9, 330.2])[opts.value.orientation === 'landscape' ? 1 : 0]!
  const w = Math.round(mmW * 3.78) + 32
  const s = Math.min(1, window.innerWidth / w)
  return { width: `${w}px`, height: `${Math.round((window.innerHeight - 56) / s)}px`, transform: `scale(${s})`, transformOrigin: 'top left' }
})

async function run(what: 'print' | 'share') {
  const name = `rent-report-${opts.value.property.name.replace(/\W+/g, '-').toLowerCase()}-${opts.value.year}`
  busy.value = true
  try {
    if (what === 'print') await printHtml(html.value, { name, paper: paper.value, orientation: orientation.value })
    else await shareHtml(html.value, { name, title: 'Boarders payment timeline' })
  } catch (e) {
    // Closing the share sheet rejects with AbortError; that is not a failure.
    if ((e as Error)?.name !== 'AbortError') Notify.create({ message: `Could not ${what} the report.`, color: 'negative', position: 'top', classes: 'custom-notify' })
  } finally {
    busy.value = false
  }
}
</script>

<style scoped>
.rs { display: flex; flex-direction: column; gap: 14px; }
.rs-blurb { margin: 0; color: var(--m-muted); font-size: 13px; }
.rs-mini { position: relative; display: flex; height: 150px; padding: 12px 14px; overflow: hidden; border: 1px solid var(--m-border); border-radius: 12px; background: var(--m-bg); cursor: pointer; font: inherit; text-align: left; }
.rs-paper { display: flex; width: 100%; flex-direction: column; gap: 5px; padding: 10px 12px; background: #fff; box-shadow: 0 1px 4px rgba(0, 0, 0, 0.18); }
.rs-l { display: block; background: #17202a; }
.rs-l--t { align-self: center; width: 110px; height: 6px; }
.rs-l--s { align-self: center; width: 70px; height: 3px; background: #9ca3af; }
.rs-l--r { height: 2px; }
.rs-l--h { align-self: center; width: 130px; height: 5px; margin-top: 3px; }
.rs-cells { display: grid; grid-template-columns: repeat(14, minmax(0, 1fr)); gap: 1px; margin-top: 4px; border: 1px solid #17202a; background: #17202a; }
.rs-cells i { height: 7px; background: #fff; }
.rs-cells i.h { background: #d9e8dc; }
.rs-cells i.g { background: #f2f2f2; }
.rs-zoom { position: absolute; right: 10px; bottom: 10px; display: inline-flex; align-items: center; gap: 4px; padding: 4px 10px; border-radius: 999px; background: rgba(23, 32, 42, 0.8); color: #fff; font-size: 11.5px; font-weight: 700; }
.rs-card { display: flex; flex-direction: column; overflow: hidden; border: 1px solid var(--m-border); border-radius: 16px; }
.rs-card-h { padding: 8px 12px; background: var(--m-bg); color: var(--m-ink); font-size: 12.5px; font-weight: 800; letter-spacing: 0.02em; text-transform: uppercase; }
.rs-line { display: flex; min-height: 48px; align-items: center; gap: 10px; padding: 0 12px; border: 0; border-top: 1px solid var(--m-border); background: transparent; font: inherit; text-align: left; }
.rs-lbl { flex: 1; color: var(--m-ink); font-size: 13.5px; font-weight: 600; }
.rs-val { color: var(--m-ink); font-size: 13px; font-weight: 700; }
.rs-pill { min-height: 34px; width: auto; max-width: 60%; padding: 0 10px 0 12px; border: 1px solid var(--m-border); border-radius: 999px; background: var(--m-bg); font-size: 13px; font-weight: 700; }
.rs-switch { width: 100%; cursor: pointer; }
.rs-track { position: relative; width: 42px; height: 24px; flex: 0 0 42px; border-radius: 999px; background: var(--m-border); transition: background 0.15s; }
.rs-track.on { background: var(--m-primary); }
.rs-knob { position: absolute; top: 3px; left: 3px; width: 18px; height: 18px; border-radius: 50%; background: #fff; box-shadow: 0 1px 2px rgba(0, 0, 0, 0.25); transition: left 0.15s; }
.rs-track.on .rs-knob { left: 21px; }
.rs-actions { display: flex; gap: 8px; width: 100%; }
.rs-btn { display: flex; min-height: 46px; align-items: center; justify-content: center; gap: 6px; border-radius: 999px; font: inherit; font-size: 14px; font-weight: 700; cursor: pointer; }
.rs-btn:disabled { opacity: 0.6; }
.rs-btn--ghost { flex: 1; border: 1px solid var(--m-border); background: var(--m-surface); color: var(--m-ink); }
.rs-btn--main { flex: 2; border: 0; background: var(--m-primary); color: #fff; }
.pv { display: flex; width: 100%; height: 100%; flex-direction: column; background: #d9d9d9; }
.pv-bar { display: flex; height: 56px; flex: 0 0 56px; align-items: center; justify-content: space-between; padding: 0 6px 0 16px; background: var(--m-surface); border-bottom: 1px solid var(--m-border); }
.pv-title { color: var(--m-ink); font-family: var(--m-font-display); font-size: 17px; font-weight: 700; }
.pv-close { display: grid; width: 44px; height: 44px; place-items: center; border: 0; border-radius: 999px; background: transparent; color: var(--m-text); cursor: pointer; }
.pv-host { flex: 1; min-height: 0; overflow: hidden; }
.pv-frame { display: block; border: 0; background: #d9d9d9; }
</style>
