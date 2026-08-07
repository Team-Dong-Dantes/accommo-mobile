<template>
  <q-page class="dashboard-page bg-grey-1">
    <div class="header-section text-white">
      <div class="row justify-between items-center q-pa-md">
        <h4 class="q-my-none text-weight-bold">Property Manager</h4>
        <q-btn flat round dense icon="logout" @click="handleLogout" />
      </div>
      <div class="q-px-md q-pb-xl">
        <p class="text-subtitle1 text-white-7">Overview of your properties and tenants</p>
      </div>
    </div>

    <div class="content-section q-pa-md">
      <div class="row q-col-gutter-md">
        <div class="col-12 col-sm-6 col-md-4">
          <q-card flat bordered class="custom-card">
            <q-card-section>
              <div class="text-overline text-teal-9">Active Tenants</div>
              <div class="text-h3 q-mt-sm text-weight-bold">0</div>
            </q-card-section>
          </q-card>
        </div>

        <div class="col-12 col-sm-6 col-md-4">
          <q-card flat bordered class="custom-card">
            <q-card-section>
              <div class="text-overline text-teal-9">Pending Payments</div>
              <div class="text-h3 q-mt-sm text-weight-bold">0</div>
            </q-card-section>
            <q-card-actions align="right" class="q-pa-md">
              <q-btn flat color="teal-9" class="text-weight-bold" label="View Details" />
            </q-card-actions>
          </q-card>
        </div>

        <div class="col-12 col-md-4">
          <q-card flat bordered class="custom-card">
            <q-card-section>
              <div class="text-overline text-teal-9">Properties</div>
              <div class="text-h6 q-mt-sm text-weight-bold">No properties listed</div>
              <div class="text-subtitle2 text-grey-7">
                Add a property to start accepting tenants.
              </div>
            </q-card-section>
            <q-card-actions align="right" class="q-pa-md">
              <q-btn unelevated color="teal-9" class="action-btn" label="Add Property" />
            </q-card-actions>
          </q-card>
        </div>
      </div>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { useRouter } from 'vue-router';
import { supabase } from '@/shared/utils/supabase';
import { useAuthStore } from '@/stores/auth';

const router = useRouter();

async function handleLogout() {
  useAuthStore().clearCachedRole();
  await supabase.auth.signOut();
  void router.push('/login');
}
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
.action-btn {
  border-radius: 12px;
  font-weight: 600;
  padding: 8px 24px;
}
</style>
