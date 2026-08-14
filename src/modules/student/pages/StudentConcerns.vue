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

    <template v-if="loading">
      <div class="q-px-md"><q-skeleton type="rect" height="64px" v-for="i in 3" :key="i" class="q-mb-sm" style="border-radius:14px" /></div>
    </template>

    <template v-else-if="error">
      <div class="text-negative text-center q-py-xl q-px-md">{{ error }}</div>
    </template>

    <template v-else>
      <div class="q-px-md">
        <div v-if="filteredConcerns.length === 0" class="text-center text-grey-6 q-py-xl">
          <q-icon name="report_problem" size="48px" color="grey-4" />
          <div class="text-subtitle2 text-weight-medium q-mt-sm">No concerns yet</div>
          <div class="text-caption q-mt-xs">Report maintenance or issues to your landlord.</div>
        </div>

        <q-card v-for="concern in filteredConcerns" :key="concern.id" flat bordered class="custom-card q-mb-md">
          <q-item clickable v-ripple @click="toggleExpanded(concern.id)">
            <q-item-section avatar>
              <q-icon :name="concern.icon" :color="concern.iconColor" size="28px" />
            </q-item-section>
            <q-item-section>
              <q-item-label class="text-weight-bold">{{ concern.title }}</q-item-label>
              <q-item-label caption>{{ concern.date }} · {{ concern.category }}</q-item-label>
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
              <p v-if="concern.description" class="text-caption text-grey-7 q-mb-none">{{ concern.description }}</p>
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
      </div>
    </template>
  </q-page>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue';
import { useQuasar } from 'quasar';
import { supabase } from '@/shared/utils/supabase';

interface ConcernItem {
  id: string;
  title: string;
  date: string;
  category: string;
  status: string;
  description: string | null;
  icon: string;
  iconColor: string;
  statusColor: string;
  currentStep: number;
  steps: string[];
  timeline: { actor: string; note: string; time: string; isSystem: boolean }[];
}

const $q = useQuasar();
const activeFilter = ref('All');
const expandedId = ref<string | null>(null);
const filters = ['All', 'Open', 'In Progress', 'Resolved'];
const loading = ref(true);
const error = ref<string | null>(null);
const concerns = ref<ConcernItem[]>([]);

const filteredConcerns = computed(() => {
  if (activeFilter.value === 'All') return concerns.value;
  return concerns.value.filter((c) => c.status === activeFilter.value);
});

const statusSteps: Record<string, number> = {
  open: 0,
  acknowledged: 1,
  in_progress: 2,
  resolved: 3,
};

const STATUS_LABELS: Record<string, { text: string; color: string }> = {
  open: { text: 'Open', color: 'amber' },
  acknowledged: { text: 'Acknowledged', color: 'blue' },
  in_progress: { text: 'In Progress', color: 'teal' },
  resolved: { text: 'Resolved', color: 'green' },
};

const CATEGORY_ICONS: Record<string, { icon: string; color: string }> = {
  repair: { icon: 'build', color: 'orange-8' },
  maintenance: { icon: 'home_repair_service', color: 'blue-8' },
  payment: { icon: 'payments', color: 'purple-8' },
  safety: { icon: 'security', color: 'red-8' },
  general: { icon: 'help_outline', color: 'teal-8' },
};

async function loadConcerns() {
  loading.value = true;
  error.value = null;
  try {
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return;

    // Concerns belong to a lease; find the student's leases first
    const { data: leases } = await supabase
      .from('leases')
      .select('id')
      .eq('student_id', user.id);

    const leaseIds = (leases ?? []).map((l) => (l as { id: string }).id);

    if (leaseIds.length === 0) {
      concerns.value = [];
      return;
    }

    const { data, error: queryError } = await supabase
      .from('concerns')
      .select('id, category, description, status, reported_at, resolved_at')
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
    }>;

    concerns.value = rows.map((c) => {
      const icon: { icon: string; color: string } = CATEGORY_ICONS[c.category] ?? { icon: 'help_outline', color: 'teal-8' };
      const label: { text: string; color: string } = STATUS_LABELS[c.status] ?? { text: c.status, color: 'grey' };
      const currentStep = statusSteps[c.status] ?? 0;

      const timeline = [
        { actor: 'You', note: c.description ?? `Reported a ${c.category} issue`, time: new Date(c.reported_at).toLocaleString('en-PH'), isSystem: false },
        { actor: 'System', note: 'Request routed to landlord', time: new Date(c.reported_at).toLocaleString('en-PH'), isSystem: true },
      ];
      if (c.resolved_at) {
        timeline.push({ actor: 'System', note: 'Issue resolved', time: new Date(c.resolved_at).toLocaleString('en-PH'), isSystem: true });
      }

      return {
        id: c.id,
        title: c.description?.slice(0, 40) ?? `${c.category} concern`,
        date: new Date(c.reported_at).toLocaleDateString('en-PH', { month: 'short', day: 'numeric', year: 'numeric' }),
        category: c.category,
        status: label.text,
        description: c.description,
        icon: icon.icon,
        iconColor: icon.color,
        statusColor: label.color,
        currentStep,
        steps: ['Submitted', 'Acknowledged', 'In Progress', 'Resolved'],
        timeline,
      };
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
  $q.notify({ message: 'New concern form will open here.', color: 'teal-8', position: 'top', classes: 'custom-notify' });
}

onMounted(loadConcerns);
</script>

<style scoped>
.custom-card {
  border-radius: 14px;
  background: white;
  box-shadow: 0 2px 6px rgba(0,0,0,0.04);
}
</style>
