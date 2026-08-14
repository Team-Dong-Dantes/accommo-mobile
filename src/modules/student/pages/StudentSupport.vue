<template>
  <q-page class="bg-grey-1 q-pb-xl">
    <div class="header-banner text-white q-pa-md">
      <div class="text-h5 text-weight-bold">OSAS Support</div>
      <div class="text-subtitle2 q-mt-xs opacity-8">How can we help you today?</div>
      <q-input
        v-model="search"
        outlined dense
        placeholder="Search help articles..."
        bg-color="white"
        class="q-mt-md search-input"
      >
        <template #prepend><q-icon name="search" color="grey-7" /></template>
      </q-input>
    </div>

    <div class="q-pa-md">
      <div class="text-subtitle1 text-weight-bold q-mb-sm">Help Categories</div>
      <div class="row q-col-gutter-sm">
        <div v-for="cat in categories" :key="cat.label" class="col-6">
          <q-card flat bordered class="custom-card cursor-pointer" @click="goToCategory(cat.label)">
            <q-card-section class="q-py-md text-center">
              <q-icon :name="cat.icon" :color="cat.color" size="28px" />
              <div class="text-subtitle2 text-weight-bold q-mt-sm">{{ cat.label }}</div>
              <div class="text-caption text-grey-6">{{ cat.count }}</div>
            </q-card-section>
          </q-card>
        </div>
      </div>
    </div>

    <div class="q-px-md q-mb-md">
      <div class="row justify-between items-center q-mb-sm">
        <div class="text-subtitle1 text-weight-bold">My Tickets</div>
        <q-btn flat dense color="teal-8" label="View All" no-caps class="text-weight-bold" @click="goToConcerns" />
      </div>
      <template v-if="loading">
        <q-skeleton type="rect" height="64px" v-for="i in 2" :key="i" class="q-mb-sm" style="border-radius:14px" />
      </template>
      <template v-else-if="tickets.length === 0">
        <q-card flat bordered class="custom-card q-mb-sm">
          <q-card-section class="text-center text-grey-6 q-py-md">
            No tickets yet. Reach out to OSAS for support.
          </q-card-section>
        </q-card>
      </template>
      <template v-else>
        <q-card v-for="ticket in tickets" :key="ticket.id" flat bordered class="custom-card q-mb-sm">
          <q-item>
            <q-item-section>
              <q-item-label class="text-weight-bold">{{ ticket.title }}</q-item-label>
              <q-item-label caption>{{ ticket.date }} · {{ ticket.category }}</q-item-label>
            </q-item-section>
            <q-item-section side>
              <q-badge :color="ticketStatusColor(ticket.status)" :label="ticket.status" class="q-px-sm" />
            </q-item-section>
          </q-item>
        </q-card>
      </template>
    </div>

    <div class="q-px-md q-pb-xl">
      <div class="text-subtitle1 text-weight-bold q-mb-sm">Common Questions</div>
      <q-list bordered separator class="custom-card bg-white">
        <q-expansion-item
          v-for="(faq, idx) in faqs" :key="idx"
          :label="faq.q"
          expand-icon="add" expanded-icon="remove"
          header-class="text-weight-medium"
        >
          <q-card-section class="text-grey-7 q-pt-none">{{ faq.a }}</q-card-section>
        </q-expansion-item>
      </q-list>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue';
import { useRouter } from 'vue-router';
import { supabase } from '@/shared/utils/supabase';

interface TicketRow {
  id: string;
  title: string;
  date: string;
  category: string;
  status: string;
}

const router = useRouter();
const search = ref('');
const loading = ref(true);
const tickets = ref<TicketRow[]>([]);

const categories = [
  { label: 'Housing', icon: 'home_work', color: 'green-8', count: '12 articles' },
  { label: 'Document', icon: 'description', color: 'blue-8', count: '8 articles' },
  { label: 'Repair', icon: 'build', color: 'orange-8', count: '15 articles' },
  { label: 'Payment', icon: 'payments', color: 'purple-8', count: '10 articles' },
  { label: 'General', icon: 'help_outline', color: 'teal-8', count: '20 articles' },
];

const faqs = [
  { q: 'How do I file a maintenance request?', a: 'Go to the Concerns tab, tap "New Concern", select the Repair category, describe the issue, and submit. Your landlord will be notified immediately.' },
  { q: 'What happens if I miss a rent payment?', a: 'A late fee may apply. The payment will be marked as overdue. We recommend paying as soon as possible to avoid penalties. Contact OSAS if you need assistance.' },
  { q: 'How do I get a copy of my lease?', a: 'You can request it through the Document category in OSAS Support, or ask your landlord directly through Messages.' },
  { q: 'Can I transfer to a different room?', a: 'Yes — file a Housing request through OSAS Support. Room transfers are subject to availability and landlord approval.' },
];

function ticketStatusColor(status: string): string {
  switch (status.toLowerCase()) {
    case 'resolved': return 'green';
    case 'in_progress':
    case 'in review':
    case 'reviewing': return 'teal';
    case 'pending':
    case 'open': return 'amber';
    default: return 'grey';
  }
}

async function loadTickets() {
  loading.value = true;
  try {
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return;

    const { data, error } = await supabase
      .from('complaints')
      .select('id, subject, category, status, filed_at')
      .eq('student_id', user.id)
      .order('filed_at', { ascending: false });

    if (error) throw error;

    const rows = (data ?? []) as unknown as Array<{
      id: string; subject: string; category: string; status: string; filed_at: string;
    }>;

    tickets.value = rows.map((c) => ({
      id: c.id,
      title: c.subject,
      date: new Date(c.filed_at).toLocaleDateString('en-PH', { month: 'short', day: 'numeric' }),
      category: c.category,
      status: c.status,
    }));
  } catch {
    tickets.value = [];
  } finally {
    loading.value = false;
  }
}

function goToCategory(label: string) { void router.push('/student/concerns'); }
function goToConcerns() { void router.push('/student/concerns'); }

onMounted(loadTickets);
</script>

<style scoped>
.header-banner {
  background: linear-gradient(135deg, #2e7d32, #43a047);
  border-radius: 0 0 24px 24px;
}
.search-input :deep(.q-field__control) {
  border-radius: 12px;
  color: #333;
}
.opacity-8 { opacity: 0.85; }
.custom-card {
  border-radius: 14px;
  background: white;
  box-shadow: 0 2px 6px rgba(0,0,0,0.04);
}
</style>
