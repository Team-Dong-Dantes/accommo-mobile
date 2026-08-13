<template>
  <q-page class="bg-grey-1 q-pb-md">
    <div class="q-pa-md">
      <div class="row justify-between items-end q-mb-md">
        <div>
          <div class="text-h4 text-weight-bold" style="letter-spacing: -0.5px">Notifications</div>
          <div class="text-grey-6 text-caption">2 unread</div>
        </div>
        <q-btn flat color="teal-8" label="Mark all read" no-caps class="text-weight-bold bg-teal-1 rounded-borders q-px-sm" dense />
      </div>

      <div class="q-gutter-y-sm">
        <q-card v-for="notif in notifications" :key="notif.id" flat bordered class="custom-card">
          <q-item class="q-pa-md">
            <q-item-section avatar top>
              <q-avatar :color="notif.avatarColor" :text-color="notif.avatarTextColor" :icon="notif.icon" />
            </q-item-section>
            <q-item-section>
              <q-item-label class="text-weight-bold">{{ notif.title }}</q-item-label>
              <q-item-label caption class="q-mt-xs">{{ notif.body }}</q-item-label>
            </q-item-section>
            <q-item-section side top class="items-end">
              <q-item-label caption class="q-mb-xs">{{ notif.time }}</q-item-label>
              <div v-if="notif.unread" class="bg-teal-8" style="width: 8px; height: 8px; border-radius: 50%;" />
            </q-item-section>
          </q-item>
        </q-card>
      </div>
    </div>
  </q-page>
</template>

<script setup lang="ts">
interface NotificationItem {
  id: number;
  title: string;
  body: string;
  time: string;
  unread: boolean;
  icon: string;
  avatarColor: string;
  avatarTextColor: string;
}

const notifications: NotificationItem[] = [
  { id: 1, title: 'Rent Due Reminder', body: 'Your August rent of \u20B12,500 is overdue. Please settle immediately to avoid penalties.', time: '2 hours ago', unread: true, icon: 'credit_card', avatarColor: 'teal-1', avatarTextColor: 'teal-8' },
  { id: 2, title: 'Repair Update', body: 'Your faucet repair request (MR-002) is now In Progress. Technician scheduled for Aug 14.', time: '5 hours ago', unread: true, icon: 'build', avatarColor: 'orange-1', avatarTextColor: 'orange' },
  { id: 3, title: 'Payment Verified', body: 'Your July 2026 rent payment of \u20B12,500 has been verified by your landlord.', time: '1d ago', unread: false, icon: 'check_circle', avatarColor: 'green-1', avatarTextColor: 'green' },
];
</script>

<style scoped>
.custom-card {
  border-radius: 16px;
  background: white;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.04);
}
</style>
