<template>
  <q-page class="bg-grey-1 q-pb-xl">
    <div class="row justify-between items-center q-pa-md">
      <div>
        <div class="text-h5 text-weight-bold">My Concerns</div>
        <div class="text-subtitle2 text-grey-6">Track your reported issues</div>
      </div>
      <q-btn unelevated color="teal-8" icon="add" label="New Concern" class="rounded-borders text-weight-bold" no-caps @click="newConcern" />
    </div>

    <q-banner inline-actions rounded class="q-mx-md q-mb-md" style="background:#E8F5E9;">
      <template #avatar><q-icon name="info" color="green-8" size="24px" /></template>
      <span class="text-body2 text-green-9">
        Issues are reviewed by your landlord within 24 hours. For emergencies, call OSAS at (078) 123-4567.
      </span>
    </q-banner>

    <div class="q-px-md q-mb-md">
      <q-btn
        v-for="f in filters" :key="f"
        :unelevated="activeFilter === f"
        :outline="activeFilter !== f"
        :color="activeFilter === f ? 'teal-8' : 'grey-7'"
        :label="f" size="sm" dense no-caps
        class="rounded-borders q-mr-sm q-mb-sm"
        @click="activeFilter = f"
      />
    </div>

    <div class="q-px-md">
      <q-card v-for="concern in filteredConcerns" :key="concern.id" flat bordered class="custom-card q-mb-md">
        <q-item clickable v-ripple @click="toggleExpanded(concern.id)">
          <q-item-section avatar>
            <q-icon :name="concern.icon" :color="concern.iconColor" size="28px" />
          </q-item-section>
          <q-item-section>
            <q-item-label class="text-weight-bold">{{ concern.title }}</q-item-label>
            <q-item-label caption>
              {{ concern.date }} · {{ concern.category }}
            </q-item-label>
          </q-item-section>
          <q-item-section side>
            <q-badge :color="concern.statusColor" :label="concern.status" class="q-px-sm" />
          </q-item-section>
          <q-item-section side>
            <q-icon :name="expandedId === concern.id ? 'expand_less' : 'expand_more'" color="grey-5" />
          </q-item-section>
        </q-item>

        <template v-if="expandedId === concern.id">
          <q-separator />
          <q-card-section class="q-pb-none">
            <div class="row q-mb-md">
              <div v-for="(step, si) in concern.steps" :key="si" class="col-3 text-center">
                <q-icon
                  :name="si < concern.currentStep ? 'check_circle' : si === concern.currentStep ? 'radio_button_checked' : 'radio_button_unchecked'"
                  :color="si < concern.currentStep ? 'teal-8' : si === concern.currentStep ? 'orange-8' : 'grey-4'"
                  size="20px"
                />
                <div class="text-caption q-mt-xs" :class="si <= concern.currentStep ? 'text-weight-bold text-grey-9' : 'text-grey-5'">
                  {{ step }}
                </div>
              </div>
            </div>
            <q-linear-progress :value="concern.currentStep / 3" color="teal-8" track-color="grey-3" rounded size="4px" class="q-mb-md" />
          </q-card-section>

          <q-card-section>
            <div class="text-subtitle2 text-weight-bold q-mb-sm">Activity</div>
            <div v-for="(entry, ei) in concern.timeline" :key="ei" class="row q-mb-sm">
              <div class="column items-center q-mr-sm" style="min-width:24px">
                <q-icon :name="entry.isSystem ? 'settings' : 'person'" :color="entry.isSystem ? 'grey-5' : 'teal-8'" size="16px" />
                <div v-if="ei < concern.timeline.length - 1" style="width:2px;flex:1;background:#e0e0e0;margin:2px 0" />
              </div>
              <div>
                <div class="text-caption text-weight-bold">{{ entry.actor }}</div>
                <div class="text-caption text-grey-6">{{ entry.note }}</div>
                <div class="text-caption text-grey-5" style="font-size:11px">{{ entry.time }}</div>
              </div>
            </div>
          </q-card-section>
        </template>
      </q-card>

      <div v-if="filteredConcerns.length === 0" class="text-center text-grey-6 q-py-xl">No concerns found.</div>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue';
import { useQuasar } from 'quasar';

interface ConcernItem {
  id: number;
  title: string;
  date: string;
  category: string;
  status: string;
  icon: string;
  iconColor: string;
  statusColor: string;
  currentStep: number;
  steps: string[];
  timeline: { actor: string; note: string; time: string; isSystem: boolean }[];
}

const $q = useQuasar();
const activeFilter = ref('All');
const expandedId = ref<number | null>(1);
const filters = ['All', 'Open', 'In Progress', 'Resolved'];

const concerns: ConcernItem[] = [
  {
    id: 1, title: 'Leaking faucet in bathroom', date: 'Aug 9, 2026', category: 'Repair', status: 'In Progress',
    icon: 'build', iconColor: 'orange-8', statusColor: 'teal', currentStep: 2,
    steps: ['Submitted', 'Acknowledged', 'In Progress', 'Resolved'],
    timeline: [
      { actor: 'You', note: 'Submitted repair request with photos', time: 'Aug 9, 2:30 PM', isSystem: false },
      { actor: 'System', note: 'Request routed to landlord', time: 'Aug 9, 2:31 PM', isSystem: true },
      { actor: 'Mario Santos (Landlord)', note: 'Acknowledged — will send technician on Aug 14', time: 'Aug 10, 9:15 AM', isSystem: false },
    ],
  },
  {
    id: 2, title: 'WiFi unstable since Aug 5', date: 'Aug 5, 2026', category: 'Maintenance', status: 'Open',
    icon: 'wifi', iconColor: 'blue-8', statusColor: 'amber', currentStep: 0,
    steps: ['Submitted', 'Acknowledged', 'In Progress', 'Resolved'],
    timeline: [
      { actor: 'You', note: 'Reported WiFi disconnections during evening hours', time: 'Aug 5, 7:00 PM', isSystem: false },
      { actor: 'System', note: 'Request routed to landlord', time: 'Aug 5, 7:01 PM', isSystem: true },
    ],
  },
  {
    id: 3, title: 'Window lock broken — security concern', date: 'Jul 28, 2026', category: 'Repair', status: 'Resolved',
    icon: 'lock', iconColor: 'grey-8', statusColor: 'green', currentStep: 3,
    steps: ['Submitted', 'Acknowledged', 'In Progress', 'Resolved'],
    timeline: [
      { actor: 'You', note: 'Reported broken window lock on 1st floor', time: 'Jul 28, 10:00 AM', isSystem: false },
      { actor: 'System', note: 'Request routed to landlord', time: 'Jul 28, 10:01 AM', isSystem: true },
      { actor: 'Mario Santos (Landlord)', note: 'Technician dispatched same day', time: 'Jul 28, 2:00 PM', isSystem: false },
      { actor: 'System', note: 'Issue marked as resolved', time: 'Jul 29, 8:00 AM', isSystem: true },
    ],
  },
];

const filteredConcerns = computed(() => {
  if (activeFilter.value === 'All') return concerns;
  return concerns.filter(c => c.status === activeFilter.value);
});

function toggleExpanded(id: number) {
  expandedId.value = expandedId.value === id ? null : id;
}

function newConcern() {
  $q.notify({ message: 'New concern form will open here.', color: 'teal-8', position: 'top', classes: 'custom-notify' });
}
</script>

<style scoped>
.custom-card {
  border-radius: 14px;
  background: white;
  box-shadow: 0 2px 6px rgba(0,0,0,0.04);
}
</style>
