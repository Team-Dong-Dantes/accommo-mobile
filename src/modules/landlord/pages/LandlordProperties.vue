<template>
  <q-page class="dashboard-page bg-grey-1">
    <div class="header-section text-white">
      <div class="row justify-between items-center q-pa-md">
      </div>
    </div>

    <div class="content-section q-pa-md">
      <q-list
        v-if="properties.length > 0"
        bordered
        separator
        class="rounded-borders bg-white"
      >
        <q-item v-for="property in properties" :key="property.id">
          <q-item-section>
            <q-item-label class="text-weight-bold">
              {{ property.name }}
            </q-item-label>
            <q-item-label caption>
              {{ property.address || 'No address set' }}
            </q-item-label>
          </q-item-section>
          <q-item-section side>
            <q-badge :color="statusColor(property.status)" :label="property.status" />
          </q-item-section>
        </q-item>
      </q-list>

      <q-card v-else flat bordered class="custom-card q-mt-sm">
        <q-card-section class="text-center">
          <div class="text-subtitle2 text-grey-7 q-py-md">
            No properties yet — add your first property from the dashboard.
          </div>
        </q-card-section>
      </q-card>

      <div v-if="error" class="text-negative q-mt-md">{{ error }}</div>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue';
import { supabase } from '@/shared/utils/supabase';

interface PropertyRow {
  id: string;
  name: string;
  address: string | null;
  status: string;
}

const businessName = ref('Property Manager');
const properties = ref<PropertyRow[]>([]);
const error = ref<string | null>(null);

function statusColor(status: string): string {
  switch (status) {
    case 'accredited':
      return 'teal';
    case 'reviewing':
      return 'blue';
    case 'pending':
      return 'amber';
    case 'rejected':
      return 'negative';
    case 'delisted':
      return 'grey';
    default:
      return 'grey';
  }
}

async function loadProperties() {
  error.value = null;
  try {
    const {
      data: { user },
    } = await supabase.auth.getUser();

    if (!user) return;

    // Business name from the users table (source of truth), not auth metadata.
    const { data: me } = await supabase
      .from('users')
      .select('full_name')
      .eq('id', user.id)
      .maybeSingle()
    businessName.value = (me as any)?.full_name || (user.user_metadata?.full_name as string) || 'Property Manager'

    // Accommodations managed by this landlord
    const { data: props, error: propsError } = await supabase
      .from('accommodations' as any)
      .select('id, name, address, status')
      .eq('accommodation_manager_id', user.id)
      .order('name');

    if (propsError) throw propsError;
    properties.value = (props ?? []) as unknown as PropertyRow[];
  } catch (e) {
    error.value = e instanceof Error ? e.message : 'Failed to load properties';
  }
}

onMounted(loadProperties);
</script>

<style scoped>
.header-section {
  background: #004d40;
  border-radius: 0 0 28px 28px;
  margin-bottom: -40px;
}
.text-white-7 {
  color: rgba(255, 255, 255, 0.7);
}
.content-section {
  position: relative;
  z-index: 1;
}
.custom-card {
  border-radius: 16px;
  background: white;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.05);
}
</style>
