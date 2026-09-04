<template>
  <q-page class="bg-grey-1 q-pb-xl">
    <div class="cc-page-body">
      <div class="report-hero">
        <div class="row items-center">
          <div class="col">
            <div class="hero-kicker">STUDENT REPORT</div>
            <div class="hero-title">Something wrong at your boarding house?</div>
            <div class="hero-sub">Tell your manager. They'll acknowledge, respond, and fix it.</div>
          </div>
          <div class="col-auto">
            <q-btn unelevated color="teal-8" icon="add" label="Report an issue" class="rounded-borders text-weight-bold" no-caps @click="newConcern" />
          </div>
        </div>
      </div>
    </div>

    <template v-if="loading">
      <div class="q-mt-md"><q-skeleton type="rect" height="84px" v-for="i in 3" :key="i" class="q-mb-sm" style="border-radius:14px" /></div>
    </template>

    <template v-else-if="error">
      <div class="text-negative text-center q-py-xl q-px-md">{{ error }}</div>
    </template>

    <template v-else>
      <div class="q-mt-md">
        <template v-if="filteredConcerns.length === 0">
          <!-- No reports at all: plain empty state (matches manager design) -->
          <div v-if="!hasFilters" class="empty-card text-center">
            <q-icon name="inbox" size="40px" class="empty-icon" />
            <div class="empty-title">No reports yet</div>
            <div class="empty-sub">Found an issue at your boarding house? Let your manager know so they can fix it.</div>
          </div>
          <!-- Search / filter produced no matches -->
          <EmptyState
            v-else
            icon="lucide:search-x"
            title="No matching reports"
            message="Try a different search term or clear your filters."
          >
            <q-btn flat no-caps class="text-button" label="Clear filters" @click="clearFilters" />
          </EmptyState>
        </template>

        <template v-else>
          <div class="cc-result-count">{{ filteredConcerns.length }} report{{ filteredConcerns.length === 1 ? '' : 's' }}</div>

          <div v-for="concern in filteredConcerns" :key="concern.id" class="cc-card" :class="`cc-card--${concern.key}`" @click="toggleExpanded(concern.id)">
            <div class="cc-head">
              <span class="cc-icon" :style="{ background: concern.iconBg, color: concern.iconColor }"><q-icon :name="concern.icon" size="20px" /></span>
              <div class="cc-main">
                <div class="cc-title">{{ concern.title }}</div>
                <div class="cc-meta">{{ concern.categoryLabel }} · {{ concern.date }}</div>
              </div>
              <span class="cc-status" :style="{ background: concern.statusBg, color: concern.statusInk }">{{ concern.status }}</span>
            </div>

            <template v-if="expandedId === concern.id">
              <div class="cc-body">
                <div class="cc-desc">{{ concern.description || (concern.categoryLabel + ' issue reported.') }}</div>

                <!-- Step tracker -->
                <div class="cc-steps">
                  <template v-for="(step, si) in concern.steps" :key="si">
                    <div class="cc-step" :class="{ done: si < concern.currentStep, active: si === concern.currentStep }">
                      <span class="cc-dot">
                        <q-icon v-if="si < concern.currentStep" name="check" size="12px" />
                        <span v-else-if="si === concern.currentStep" class="cc-pulse" />
                      </span>
                      <span class="cc-step-label">{{ step }}</span>
                    </div>
                    <span v-if="si < concern.steps.length - 1" class="cc-step-line" :class="{ done: si < concern.currentStep }" />
                  </template>
                </div>

                <!-- Manager response -->
                <div v-if="concern.managerResponse" class="cc-reply">
                  <div class="cc-reply-head">
                    <span class="cc-reply-avatar">M</span>
                    <span class="cc-reply-name">Manager</span>
                    <span class="cc-reply-time">{{ concern.responseTime }}</span>
                  </div>
                  <div class="cc-reply-text">{{ concern.managerResponse }}</div>
                </div>

                <!-- Activity -->
                <div v-if="concern.timeline.length" class="cc-activity">
                  <div class="cc-activity-title">Activity</div>
                  <div v-for="(entry, ei) in concern.timeline" :key="ei" class="cc-activity-row">
                    <span class="cc-activity-dot" :class="entry.isSystem ? 'is-system' : 'is-you'"></span>
                    <div class="cc-activity-body">
                      <div class="cc-activity-actor">{{ entry.actor }}</div>
                      <div class="cc-activity-note">{{ entry.note }}</div>
                      <div class="cc-activity-time">{{ entry.time }}</div>
                    </div>
                  </div>
                </div>
              </div>
            </template>
          </div>
        </template>
      </div>
    </template>

    <!-- Fixed bottom search + filter (discover-style) -->
    <div class="cc-action-bar">
      <button type="button" class="cc-filter-button" :class="{ 'has-active': hasFilterChips }" aria-label="Filter reports" @click="filterDialog = true">
        <IconifyIcon icon="mdi:tune" width="21" aria-hidden="true" />
      </button>
      <label class="cc-search-field" for="concerns-search">
        <IconifyIcon icon="lucide:search" width="20" aria-hidden="true" />
        <span class="sr-only">Search reports</span>
        <input id="concerns-search" v-model="searchQuery" type="search" autocomplete="off" placeholder="Search reports" />
        <button v-if="searchQuery" type="button" class="cc-clear-search" aria-label="Clear search" @click="searchQuery = ''"><IconifyIcon icon="lucide:x" width="18" /></button>
      </label>
    </div>

    <!-- Filter bottom sheet -->
    <q-dialog v-model="filterDialog" position="bottom">
      <q-card class="filter-sheet">
        <q-card-section class="filter-heading">
          <div>
            <h2>Filter reports</h2>
            <p>Narrow down your reports.</p>
          </div>
          <q-btn flat round aria-label="Close filters" @click="filterDialog = false"><IconifyIcon icon="lucide:x" width="20" /></q-btn>
        </q-card-section>

        <q-card-section>
          <h3>Status</h3>
          <div class="filter-options">
            <button v-for="opt in statusOptions" :key="opt.value" type="button" class="f-chip"
              :class="{ active: selectedStatus === opt.value }" @click="toggleStatus(opt.value)">
              {{ opt.label }}
            </button>
          </div>

          <h3>Category</h3>
          <div class="filter-options">
            <button v-for="opt in categoryOptions" :key="opt.value" type="button" class="f-chip"
              :class="{ active: selectedCategory === opt.value }" @click="selectedCategory = selectedCategory === opt.value ? null : opt.value">
              {{ opt.label }}
            </button>
          </div>
        </q-card-section>

        <q-card-actions class="filter-actions">
          <q-btn flat no-caps @click="clearFilters">Clear</q-btn>
          <q-btn unelevated no-caps class="primary-button" @click="filterDialog = false">Show reports</q-btn>
        </q-card-actions>
      </q-card>
    </q-dialog>

    <!-- New Concern Dialog -->
    <q-dialog v-model="newConcernDialog" position="bottom">
      <q-card class="dialog-card full-width">
        <q-card-section class="row items-center justify-between">
          <div class="text-subtitle1 text-weight-bold">Report an issue</div>
          <q-btn flat round dense icon="close" @click="newConcernDialog = false" />
        </q-card-section>
        <q-separator />
        <q-card-section>
          <div class="text-caption text-grey-6 q-mb-xs">Category</div>
          <q-select
            v-model="concernCategory"
            :options="concernCategories"
            map-options
            emit-value
            outlined
            dense
            class="q-mb-md"
          />
          <div class="text-caption text-grey-6 q-mb-xs">Description</div>
          <q-input
            v-model="concernDescription"
            type="textarea"
            outlined
            autogrow
            placeholder="Describe the issue... e.g. Leaking faucet in the bathroom"
            class="q-mb-md"
          />
          <div class="text-caption text-grey-6 q-mb-lg" style="font-size:12px;">
            This will be sent to your boarding-house manager. They'll acknowledge and respond within 24 hours.
          </div>
          <q-btn
            unelevated
            color="teal-8"
            label="Submit to Manager"
            class="full-width text-weight-bold"
            :disable="!concernDescription.trim() || submitting"
            :loading="submitting"
            @click="submitConcern"
          />
        </q-card-section>
      </q-card>
    </q-dialog>
  </q-page>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue';
import { useQuasar } from 'quasar';
import { supabase } from '@/shared/utils/supabase';
import EmptyState from '@/components/shared/EmptyState.vue';

interface ConcernItem {
  id: string;
  key: string;
  title: string;
  date: string;
  category: string;
  categoryLabel: string;
  status: string;
  description: string | null;
  managerResponse: string | null;
  responseTime: string;
  icon: string;
  iconColor: string;
  iconBg: string;
  statusBg: string;
  statusInk: string;
  currentStep: number;
  steps: string[];
  timeline: { actor: string; note: string; time: string; isSystem: boolean }[];
}

const $q = useQuasar();
const loading = ref(true);
const error = ref<string | null>(null);
const concerns = ref<ConcernItem[]>([]);
const expandedId = ref<string | null>(null);

// Search + filters (discover-style)
const searchQuery = ref('');
const filterDialog = ref(false);
const selectedStatus = ref<string | null>(null);
const selectedCategory = ref<string | null>(null);

type ConcernCategory = 'maintenance' | 'noise' | 'cleanliness' | 'amenities' | 'security' | 'others'
const concernCategories: { label: string; value: ConcernCategory }[] = [
  { label: 'Maintenance', value: 'maintenance' },
  { label: 'Noise', value: 'noise' },
  { label: 'Cleanliness', value: 'cleanliness' },
  { label: 'Amenities', value: 'amenities' },
  { label: 'Security', value: 'security' },
  { label: 'Others', value: 'others' },
]
const statusOptions = [
  { value: 'open', label: 'Open' },
  { value: 'acknowledged', label: 'Acknowledged' },
  { value: 'in_progress', label: 'In Progress' },
  { value: 'resolved', label: 'Resolved' },
  { value: 'rejected', label: 'Rejected' },
]
const categoryOptions = [
  { value: 'maintenance', label: 'Maintenance' },
  { value: 'noise', label: 'Noise' },
  { value: 'cleanliness', label: 'Cleanliness' },
  { value: 'amenities', label: 'Amenities' },
  { value: 'security', label: 'Security' },
  { value: 'others', label: 'Others' },
]

const newConcernDialog = ref(false)
const submitting = ref(false)
const concernCategory = ref<ConcernCategory>('maintenance')
const concernDescription = ref('')
const activeLeaseId = ref<string | null>(null)

const query = computed(() => searchQuery.value.trim().toLowerCase())
const hasFilterChips = computed(() => !!selectedStatus.value || !!selectedCategory.value)
const hasFilters = computed(() => !!query.value || hasFilterChips.value)

const filteredConcerns = computed(() => {
  return concerns.value.filter((c) => {
    if (query.value) {
      const hay = `${c.title} ${c.categoryLabel} ${c.description ?? ''}`.toLowerCase()
      if (!hay.includes(query.value)) return false
    }
    if (selectedStatus.value && c.key !== selectedStatus.value) return false
    if (selectedCategory.value && c.category !== selectedCategory.value) return false
    return true
  })
})

function toggleStatus(value: string) {
  selectedStatus.value = selectedStatus.value === value ? null : value
}
function clearFilters() {
  searchQuery.value = ''
  selectedStatus.value = null
  selectedCategory.value = null
  filterDialog.value = false
}

const categoryLabels: Record<string, string> = {
  maintenance: 'Maintenance', noise: 'Noise', cleanliness: 'Cleanliness',
  amenities: 'Amenities', security: 'Security', others: 'Others',
};

const STATUS_LABELS: Record<string, { key: string; text: string; bg: string; ink: string; step: number }> = {
  open: { key: 'open', text: 'Open', bg: '#FEF3C7', ink: '#92400E', step: 0 },
  acknowledged: { key: 'acknowledged', text: 'Acknowledged', bg: '#CCFBF1', ink: '#0F766E', step: 1 },
  in_progress: { key: 'in_progress', text: 'In Progress', bg: '#CCFBF1', ink: '#0F766E', step: 2 },
  resolved: { key: 'resolved', text: 'Resolved', bg: '#DCFCE7', ink: '#15803D', step: 3 },
  rejected: { key: 'rejected', text: 'Rejected', bg: '#FEE2E2', ink: '#B91C1C', step: 1 },
};

const CATEGORY_ICONS: Record<string, { icon: string; color: string; bg: string }> = {
  maintenance: { icon: 'home_repair_service', color: '#1d4ed8', bg: '#dbeafe' },
  noise: { icon: 'graphic_eq', color: '#7e22ce', bg: '#f3e8ff' },
  cleanliness: { icon: 'cleaning_services', color: '#0f766e', bg: '#ccfbf1' },
  amenities: { icon: 'weekend', color: '#c2410c', bg: '#ffedd5' },
  security: { icon: 'security', color: '#b91c1c', bg: '#fee2e2' },
  others: { icon: 'help_outline', color: '#374151', bg: '#e5e7eb' },
};

const fmt = (iso: string | null, withTime = false) => {
  if (!iso) return '';
  const d = new Date(iso);
  if (isNaN(d.getTime())) return '';
  return d.toLocaleString('en-PH', withTime
    ? { month: 'short', day: 'numeric', year: 'numeric', hour: 'numeric', minute: '2-digit' }
    : { month: 'short', day: 'numeric', year: 'numeric' });
};

async function loadConcerns() {
  loading.value = true;
  error.value = null;
  try {
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return;

    const { data: leases } = await supabase
      .from('leases')
      .select('id')
      .eq('student_id', user.id);
    const leaseIds = (leases ?? []).map((l) => (l as { id: string }).id);

    const { data: activeLease } = await supabase
      .from('leases')
      .select('id')
      .eq('student_id', user.id)
      .eq('status', 'active')
      .maybeSingle();
    activeLeaseId.value = (activeLease as { id: string } | null)?.id ?? null;

    if (leaseIds.length === 0) {
      concerns.value = [];
      return;
    }

    const { data, error: queryError } = await supabase
      .from('concerns')
      .select('id, category, description, status, reported_at, resolved_at, acknowledged_at, manager_response')
      .in('lease_id', leaseIds)
      .order('reported_at', { ascending: false });

    if (queryError) throw queryError;

    const rows = (data ?? []) as unknown as Array<{
      id: string;
      category: string;
      description: string | null;
      status: string;
      reported_at: string;
      resolved_at: string | null;
      acknowledged_at: string | null;
      manager_response: string | null;
    }>;

    concerns.value = rows.map((c) => {
      const icon = CATEGORY_ICONS[c.category] ?? { icon: 'help_outline', color: '#374151', bg: '#e5e7eb' };
      const label = STATUS_LABELS[c.status] ?? { key: c.status, text: c.status, bg: '#e5e7eb', ink: '#374151', step: 0 };
      const currentStep = label.step;
      const steps = c.status === 'rejected' ? ['Submitted', 'Rejected'] : ['Submitted', 'Acknowledged', 'In Progress', 'Resolved'];

      const timeline = [
        { actor: 'You', note: c.description ?? `Reported a ${categoryLabels[c.category] ?? c.category} issue`, time: fmt(c.reported_at, true), isSystem: false },
      ];
      if (c.acknowledged_at) {
        timeline.push({ actor: 'Manager', note: 'Acknowledged your concern', time: fmt(c.acknowledged_at, true), isSystem: true });
      }
      if (c.manager_response) {
        timeline.push({ actor: 'Manager', note: c.manager_response, time: fmt(c.resolved_at ?? c.acknowledged_at, true), isSystem: true });
      }
      if (c.resolved_at) {
        timeline.push({ actor: 'System', note: 'Concern resolved', time: fmt(c.resolved_at, true), isSystem: true });
      }

      return {
        id: c.id,
        key: label.key,
        title: c.description?.slice(0, 40) ?? `${categoryLabels[c.category] ?? c.category} concern`,
        date: fmt(c.reported_at),
        category: c.category,
        categoryLabel: categoryLabels[c.category] ?? c.category,
        status: label.text,
        description: c.description,
        managerResponse: c.manager_response,
        responseTime: fmt(c.resolved_at ?? c.acknowledged_at),
        icon: icon.icon,
        iconColor: icon.color,
        iconBg: icon.bg,
        statusBg: label.bg,
        statusInk: label.ink,
        currentStep,
        steps,
        timeline,
      } as ConcernItem;
    });
  } catch (e) {
    error.value = e instanceof Error ? e.message : 'Failed to load concerns';
  } finally {
    loading.value = false;
  }
}

function toggleExpanded(id: string) {
  expandedId.value = expandedId.value === id ? null : id;
}

function newConcern() {
  if (!activeLeaseId.value) {
    $q.notify({ message: 'No active lease found. A concern must be linked to your lease.', color: 'warning', position: 'top', classes: 'custom-notify' });
    return;
  }
  concernCategory.value = 'maintenance';
  concernDescription.value = '';
  newConcernDialog.value = true;
}

async function submitConcern() {
  if (!activeLeaseId.value) return;
  const leaseId = activeLeaseId.value;
  const description = concernDescription.value.trim();
  if (!description) {
    $q.notify({ message: 'Please describe the issue.', color: 'warning', position: 'top', classes: 'custom-notify' });
    return;
  }
  submitting.value = true;
  try {
    const { error: insertError } = await supabase.from('concerns').insert({
      lease_id: leaseId,
      category: concernCategory.value,
      description,
      status: 'open',
      reported_at: new Date().toISOString(),
    });
    if (insertError) throw insertError;
    newConcernDialog.value = false;
    $q.notify({ message: 'Concern submitted. Your manager will be notified.', color: 'teal-8', position: 'top', classes: 'custom-notify' });
    await loadConcerns();
  } catch (e) {
    $q.notify({ message: e instanceof Error ? e.message : 'Failed to submit concern', color: 'negative', position: 'top', classes: 'custom-notify' });
  } finally {
    submitting.value = false;
  }
}

onMounted(loadConcerns);
</script>

<style scoped>
.cc-page-body {
  padding: 18px 16px calc(168px + env(safe-area-inset-bottom));
}
.dialog-card {
  border-radius: 20px 20px 0 0;
}
.sr-only {
  position: absolute;
  width: 1px;
  height: 1px;
  padding: 0;
  margin: -1px;
  overflow: hidden;
  clip: rect(0, 0, 0, 0);
  white-space: nowrap;
  border: 0;
}

/* Hero report */
.report-hero {
  background: linear-gradient(135deg, #0f766e, #14b8a6);
  border-radius: 18px;
  padding: 20px 18px;
  color: white;
}
.hero-kicker {
  font-size: 11px;
  font-weight: 800;
  letter-spacing: 0.08em;
  opacity: 0.85;
}
.hero-title {
  font-size: 17px;
  font-weight: 800;
  margin-top: 4px;
  line-height: 1.25;
}
.hero-sub {
  font-size: 12.5px;
  opacity: 0.9;
  margin-top: 4px;
}

/* Search + filter bar (fixed bottom, discover-style) */
.cc-action-bar {
  position: fixed;
  z-index: 59;
  right: 72px;
  bottom: 80px;
  left: 12px;
  display: flex;
  gap: 8px;
  align-items: center;
}
.cc-search-field {
  display: flex;
  min-width: 0;
  flex: 1;
  align-items: center;
  gap: 8px;
  min-height: 44px;
  padding: 0 12px;
  color: #6b7280;
  background: #fff;
  border: 1px solid #e5e7eb;
  border-radius: 12px;
  box-shadow: 0 4px 12px rgba(15, 23, 42, .08);
}
.cc-search-field input {
  min-width: 0;
  flex: 1;
  color: #111827;
  border: 0;
  outline: 0;
  background: transparent;
  font: inherit;
}
.cc-clear-search,
.cc-filter-button {
  display: grid;
  flex: 0 0 auto;
  place-items: center;
  border: 0;
  background: transparent;
  font: inherit;
  cursor: pointer;
}
.cc-clear-search {
  width: 28px;
  height: 28px;
  color: #6b7280;
}
.cc-filter-button {
  width: 44px;
  height: 44px;
  color: var(--m-primary-dark);
  background: #fff;
  border: 1px solid #e5e7eb;
  border-radius: 12px;
  box-shadow: 0 4px 12px rgba(15, 23, 42, .08);
}
.cc-filter-button.has-active {
  border-color: var(--m-primary);
  background: color-mix(in srgb, var(--m-primary-soft) 60%, white);
}

.cc-result-count {
  font-size: 12px;
  font-weight: 700;
  color: #6b7280;
  margin: 14px 2px 10px;
}

/* Empty state (matches manager design) */
.empty-card {
  padding: 40px 20px;
}
.empty-icon {
  color: #9ca3af;
}
.empty-title {
  font-size: 16px;
  font-weight: 800;
  color: #111827;
  margin-top: 10px;
}
.empty-sub {
  font-size: 13px;
  color: #6b7280;
  margin-top: 4px;
  line-height: 1.5;
}

/* Concern cards */
.cc-card {
  background: white;
  border-radius: 16px;
  border: 1px solid #e5e7eb;
  border-left: 4px solid #e5e7eb;
  box-shadow: 0 2px 6px rgba(0,0,0,0.04);
  margin-bottom: 12px;
  overflow: hidden;
  cursor: pointer;
}
.cc-card--open { border-left-color: #f59e0b; }
.cc-card--acknowledged,
.cc-card--in_progress { border-left-color: #14b8a6; }
.cc-card--resolved { border-left-color: #22c55e; }
.cc-card--rejected { border-left-color: #ef4444; }

.cc-head {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 13px 14px;
}
.cc-icon {
  flex: 0 0 auto;
  width: 40px;
  height: 40px;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: 12px;
}
.cc-main { flex: 1 1 auto; min-width: 0; }
.cc-title {
  font-size: 14.5px;
  font-weight: 800;
  color: #111827;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
.cc-meta {
  font-size: 12px;
  color: #6b7280;
  margin-top: 3px;
}
.cc-status {
  flex: 0 0 auto;
  font-size: 11px;
  font-weight: 800;
  padding: 4px 9px;
  border-radius: 999px;
  white-space: nowrap;
}

.cc-body {
  padding: 12px 14px 16px;
  border-top: 1px solid #f3f4f6;
  display: flex;
  flex-direction: column;
}
.cc-desc {
  font-size: 13.5px;
  color: #374151;
  line-height: 1.5;
  margin: 0 0 0 0;
  white-space: pre-wrap;
}

/* Step tracker */
.cc-steps {
  display: flex;
  align-items: flex-start;
  margin-top: 14px;
}
.cc-step { display: flex; flex-direction: column; align-items: center; flex: 1 1 0; }
.cc-dot {
  width: 20px;
  height: 20px;
  border-radius: 50%;
  border: 2px solid #d1d5db;
  background: white;
  display: flex;
  align-items: center;
  justify-content: center;
  color: white;
}
.cc-step.done .cc-dot { background: var(--m-primary); border-color: var(--m-primary); }
.cc-step.active .cc-dot { border-color: var(--m-primary); }
.cc-pulse {
  width: 8px;
  height: 8px;
  border-radius: 50%;
  background: var(--m-primary);
}
.cc-step-label {
  font-size: 10px;
  font-weight: 700;
  color: #9ca3af;
  margin-top: 6px;
  text-align: center;
  line-height: 1.1;
}
.cc-step.done .cc-step-label,
.cc-step.active .cc-step-label { color: #374151; }
.cc-step-line {
  flex: 1 1 auto;
  height: 2px;
  background: #e5e7eb;
  margin-top: 9px;
  min-width: 6px;
}
.cc-step-line.done { background: var(--m-primary); }

/* Manager reply */
.cc-reply {
  margin-top: 16px;
  border: 1px solid #b8dfd9;
  border-radius: 12px;
  background: #f0faf9;
  padding: 12px;
}
.cc-reply-head {
  display: flex;
  align-items: center;
  gap: 8px;
  margin-bottom: 6px;
}
.cc-reply-avatar {
  width: 26px;
  height: 26px;
  border-radius: 50%;
  background: var(--m-primary);
  color: white;
  font-size: 12px;
  font-weight: 800;
  display: flex;
  align-items: center;
  justify-content: center;
}
.cc-reply-name { font-size: 13px; font-weight: 800; color: #111827; }
.cc-reply-time { margin-left: auto; font-size: 11px; color: #6b7280; }
.cc-reply-text { font-size: 13px; color: #374151; line-height: 1.5; white-space: pre-wrap; }

/* Activity */
.cc-activity { margin-top: 16px; }
.cc-activity-title { font-size: 12px; font-weight: 800; color: #111827; letter-spacing: 0.03em; margin-bottom: 10px; }
.cc-activity-row { display: flex; gap: 10px; position: relative; padding-left: 4px; }
.cc-activity-row { padding-bottom: 14px; }
.cc-activity-row:not(:last-child)::before {
  content: '';
  position: absolute;
  left: 9px;
  top: 18px;
  bottom: 0;
  width: 2px;
  background: #e5e7eb;
}
.cc-activity-dot {
  width: 12px;
  height: 12px;
  border-radius: 50%;
  margin-top: 3px;
  flex: 0 0 auto;
  z-index: 1;
}
.cc-activity-dot.is-you { background: var(--m-primary); }
.cc-activity-dot.is-system { background: #9ca3af; }
.cc-activity-actor { font-size: 12px; font-weight: 800; color: #111827; }
.cc-activity-note { font-size: 12.5px; color: #4b5563; margin-top: 1px; }
.cc-activity-time { font-size: 11px; color: #9ca3af; margin-top: 2px; }

/* Filter sheet */
.filter-sheet {
  border-radius: 20px 20px 0 0;
  padding-bottom: env(safe-area-inset-bottom);
}
.filter-heading {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
}
.filter-heading h2 { margin: 0; font-size: 17px; font-weight: 800; }
.filter-heading p { margin: 4px 0 0; color: #6b7280; font-size: 13px; }
.filter-sheet h3 {
  margin: 4px 0 10px;
  color: #6b7280;
  font-size: 12px;
  letter-spacing: 0.04em;
  text-transform: uppercase;
}
.filter-options {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
}
.f-chip {
  min-height: 38px;
  padding: 0 16px;
  border: 1px solid var(--m-border);
  border-radius: 999px;
  background: white;
  color: var(--m-text);
  font-weight: 600;
  font-size: 13px;
  cursor: pointer;
}
.f-chip.active {
  color: #fff;
  background: var(--m-primary);
  border-color: var(--m-primary);
}
.filter-actions {
  display: flex;
  justify-content: space-between;
  padding: 12px 16px;
}
.primary-button {
  color: #fff;
  background: var(--m-primary);
  border-radius: 12px;
  font-weight: 700;
}
</style>
