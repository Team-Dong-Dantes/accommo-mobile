<template>
  <q-page class="bg-grey-1 q-pb-xl">
    <div class="header-banner text-white q-pa-md">
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
          <div class="row q-gutter-sm">
            <q-btn flat dense color="teal-8" icon="add" label="New" no-caps class="text-weight-bold" @click="newTicket" />
            <q-btn flat dense color="teal-8" label="View All" no-caps class="text-weight-bold" @click="goToConcerns" />
          </div>
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
              <q-badge :color="statusColor(COMPLAINT_STATUS, ticket.status)" :label="statusText(COMPLAINT_STATUS, ticket.status)" class="q-px-sm" />
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

    <!-- New Ticket Dialog -->
    <q-dialog v-model="newTicketDialog" position="bottom">
      <q-card class="dialog-card full-width">
        <q-card-section class="row items-center justify-between">
          <div class="text-subtitle1 text-weight-bold">New Support Ticket</div>
          <q-btn flat round dense icon="close" @click="newTicketDialog = false" />
        </q-card-section>
        <q-separator />
        <q-card-section>
          <div class="text-caption text-grey-6 q-mb-xs">Subject</div>
          <q-input v-model="ticketSubject" outlined dense class="q-mb-md" placeholder="Short summary" />
          <div class="text-caption text-grey-6 q-mb-xs">Category</div>
          <q-select v-model="ticketCategory" :options="complaintCategoryOptions" map-options emit-value outlined dense class="q-mb-md" />
          <div class="text-caption text-grey-6 q-mb-xs">Priority</div>
          <q-select v-model="ticketPriority" :options="priorityOptions" map-options emit-value outlined dense class="q-mb-md" />
          <div class="text-caption text-grey-6 q-mb-xs">Details</div>
          <q-input v-model="ticketDescription" type="textarea" outlined autogrow placeholder="Describe your issue..." class="q-mb-md" />
          <q-btn unelevated color="teal-8" label="Submit Ticket" class="full-width text-weight-bold" :disable="!ticketSubject.trim() || submitting" :loading="submitting" @click="submitTicket" />
        </q-card-section>
      </q-card>
    </q-dialog>
  </q-page>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue';
import { useRouter } from 'vue-router';
import { useQuasar } from 'quasar';
import { supabase } from '@/shared/utils/supabase';
import { COMPLAINT_STATUS, statusText, statusColor } from '@/shared/utils/format';

interface TicketRow {
  id: string;
  title: string;
  date: string;
  category: string;
  status: string;
}

const router = useRouter();
const $q = useQuasar();
const search = ref('');
const loading = ref(true);
const tickets = ref<TicketRow[]>([]);

type ComplaintCategory = 'financial' | 'privacy' | 'maintenance' | 'safety' | 'harassment' | 'contract'
type ComplaintPriority = 'urgent' | 'high' | 'medium' | 'low'
const complaintCategoryOptions: { label: string; value: ComplaintCategory }[] = [
  { label: 'Financial', value: 'financial' },
  { label: 'Privacy', value: 'privacy' },
  { label: 'Maintenance', value: 'maintenance' },
  { label: 'Safety', value: 'safety' },
  { label: 'Harassment', value: 'harassment' },
  { label: 'Contract', value: 'contract' },
]
const priorityOptions: { label: string; value: ComplaintPriority }[] = [
  { label: 'Urgent', value: 'urgent' },
  { label: 'High', value: 'high' },
  { label: 'Medium', value: 'medium' },
  { label: 'Low', value: 'low' },
]
const newTicketDialog = ref(false)
const submitting = ref(false)
const ticketSubject = ref('')
const ticketCategory = ref<ComplaintCategory>('maintenance')
const ticketPriority = ref<ComplaintPriority>('medium')
const ticketDescription = ref('')
const ticketPropertyId = ref<string | null>(null)
const ticketLandlordId = ref<string | null>(null)

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

async function loadTickets() {
  loading.value = true;
  try {
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return;

    // Capture the active lease so a new ticket can be linked to it. The
    // property is reached through the lease's room (leases has no property_id).
    const { data: activeLease } = await supabase
      .from('leases')
      .select('landlord_id, room:rooms(property_id)')
      .eq('student_id', user.id)
      .eq('status', 'active')
      .maybeSingle();
    if (activeLease) {
      const al = activeLease as unknown as { landlord_id: string | null; room: { property_id: string | null } | null };
      ticketLandlordId.value = al.landlord_id;
      ticketPropertyId.value = al.room?.property_id ?? null;
    }

    const { data, error } = await supabase
      .from('tickets')
      .select('id, subject, category, status, reported_at')
      .eq('student_id', user.id)
      .order('reported_at', { ascending: false });

    if (error) throw error;

    const rows = (data ?? []) as unknown as Array<{
      id: string; subject: string; category: string; status: string; reported_at: string;
    }>;

    tickets.value = rows.map((c) => ({
      id: c.id,
      title: c.subject,
      date: new Date(c.reported_at).toLocaleDateString('en-PH', { month: 'short', day: 'numeric' }),
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

function newTicket() {
  if (!ticketPropertyId.value || !ticketLandlordId.value) {
    $q.notify({ message: 'A support ticket needs your active lease. None found.', color: 'warning', position: 'top' });
    return;
  }
  ticketSubject.value = '';
  ticketCategory.value = 'maintenance';
  ticketPriority.value = 'medium';
  ticketDescription.value = '';
  newTicketDialog.value = true;
}

async function submitTicket() {
  const subject = ticketSubject.value.trim();
  if (!subject) {
    $q.notify({ message: 'Please enter a subject.', color: 'warning', position: 'top' });
    return;
  }
  if (!ticketPropertyId.value || !ticketLandlordId.value) return;
  const propertyId = ticketPropertyId.value;
  const landlordId = ticketLandlordId.value;
  submitting.value = true;
  try {
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) return;
    const reporterName =
      ((user.user_metadata as Record<string, any>)?.full_name as string) ||
      user.email ||
      'Unknown';
    const { error: insertError } = await supabase.from('tickets').insert({
      id: crypto.randomUUID(),
      student_id: user.id,
      landlord_id: landlordId,
      property_id: propertyId,
      category: ticketCategory.value,
      subject,
      description: ticketDescription.value.trim() || null,
      priority: ticketPriority.value,
      status: 'pending',
      reported_at: new Date().toISOString(),
      reporter_name: reporterName,
    });
    if (insertError) throw insertError;
    newTicketDialog.value = false;
    $q.notify({ message: 'Ticket submitted to OSAS.', color: 'teal-8', position: 'top' });
    await loadTickets();
  } catch (e) {
    $q.notify({ message: e instanceof Error ? e.message : 'Failed to submit ticket', color: 'negative', position: 'top' });
  } finally {
    submitting.value = false;
  }
}

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
.dialog-card {
  border-radius: 20px 20px 0 0;
}
</style>
