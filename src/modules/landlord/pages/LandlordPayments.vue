<template>
  <q-page class="dashboard-page bg-grey-1">
    <div class="header-section text-white">
      <div class="row justify-between items-center q-pa-md">
        <div>
          <h4 class="q-my-none text-weight-bold">Payment History</h4>
          <p class="text-subtitle1 text-white-7 q-mb-none">
            All payments received across your properties
          </p>
        </div>
        <q-btn flat round dense icon="logout" @click="handleLogout" />
      </div>
    </div>

    <div class="content-section q-pa-md">
      <q-list
        v-if="payments.length > 0"
        bordered
        separator
        class="rounded-borders bg-white"
      >
        <q-item v-for="payment in payments" :key="payment.id">
          <q-item-section>
            <q-item-label class="text-weight-bold">
              {{ payment.student_name }} ·
              {{ formatPeso(payment.amount) }}
            </q-item-label>
            <q-item-label caption>
              {{ payment.month }} ·
              {{ payment.method_display }} ·
              {{ payment.status_display }}
            </q-item-label>
          </q-item-section>
          <q-item-section side>
            <q-badge :color="payment.statusColor" :label="payment.statusDisplay" />
          </q-item-section>
        </q-item>
      </q-list>

      <q-card v-if="payments.length === 0" flat bordered class="custom-card q-mt-sm">
        <q-card-section class="text-center">
          <div class="text-subtitle2 text-grey-7 q-py-md">
            No payments recorded yet. Add tenants and collect payments to see history here.
          </div>
        </q-card-section>
      </q-card>

      <div v-if="error" class="text-negative q-mt-md">{{ error }}</div>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { supabase } from '@/shared/utils/supabase'
import { useAuthStore } from '@/stores/auth'
import { showToast } from '@/boot/notify'

const isDemo = (import.meta.env.VITE_DEMO_MODE as unknown) === 'true'

interface PaymentRow {
  id: string
  amount: number
  method: string
  method_display: string
  month: string
  status: string
  statusColor: string
  status_display: string
  statusDisplay: string
  student_name: string
  room_number: string | null
  property_name: string | null
  paid_at: string | null
}

const payments = ref<PaymentRow[]>([])
const error = ref<string | null>(null)

if (isDemo) {
  showToast('Demo Mode', 'Connect to real Supabase for payment history', 'info')
  onMounted(() => {})
} else {
  onMounted(loadPayments)
}

function formatPeso(amount: number): string {
  return '₱' + amount.toLocaleString('en-PH', { minimumFractionDigits: 2, maximumFractionDigits: 2 })
}

function statusInfo(status: string) {
  const info: Record<string, { color: string; label: string }> = {
    due: { color: 'teal', label: 'Due' },
    paid: { color: 'green', label: 'Paid' },
    overdue: { color: 'red', label: 'Overdue' },
    pending_verification: { color: 'amber', label: 'Awaiting verification' },
  }
  return info[status] || { color: 'grey', label: status }
}

async function loadPayments() {
  error.value = null
  try {
    const { data: { user }, error: userError } = await supabase.auth.getUser()
    if (userError) throw userError
    if (!user) return

    const { data: accs } = await supabase
      .from('accommodations' as any)
      .select('id, name, business_name')
      .eq('accommodation_manager_id', user.id)
    const accIds = (accs ?? []).map((a: any) => a.id)
    const accNameById = new Map((accs ?? []).map((a: any) => [a.id, a.business_name || a.name]))

    // Lease -> student/room linkage (payments link via lease_id, not landlord_id)
    const leaseStudent = new Map<string, string>()
    const leaseRoom = new Map<string, string>()
    const roomAcc = new Map<string, string>()
    if (accIds.length) {
      const { data: rooms } = await supabase
        .from('rooms')
        .select('id, accommodation_id')
        .in('accommodation_id', accIds)
      const roomRows = rooms ?? []
      roomRows.forEach((r: any) => roomAcc.set(r.id, r.accommodation_id))
      const roomIds = roomRows.map((r: any) => r.id)
      if (roomIds.length) {
        const { data: leases } = await supabase
          .from('leases')
          .select('id, student_id, room_id')
          .in('room_id', roomIds)
        ;(leases ?? []).forEach((l: any) => {
          leaseStudent.set(l.id, l.student_id)
          leaseRoom.set(l.id, l.room_id)
        })
      }
    }

    let paymentRows: any[] = []
    if (leaseStudent.size) {
      const { data: pays, error: paymentsError } = await supabase
        .from('payments')
        .select('id, amount, method, month, status, paid_at, lease_id')
        .in('lease_id', Array.from(leaseStudent.keys()))

      if (paymentsError) throw paymentsError
      paymentRows = pays ?? []
    }

    // Student display names
    const studentIds = Array.from(new Set(leaseStudent.values()))
    const userMap = new Map<string, any>()
    if (studentIds.length) {
      const { data: users } = await supabase
        .from('users')
        .select('id, full_name')
        .in('id', studentIds)
      ;(users ?? []).forEach((u: any) => userMap.set(u.id, u))
    }

    payments.value = paymentRows.map((payment: any) => {
      const info = statusInfo(payment.status)
      const student = userMap.get(leaseStudent.get(payment.lease_id) || '')
      const roomId = leaseRoom.get(payment.lease_id)
      const accId = roomId ? roomAcc.get(roomId) : undefined
      return {
        id: payment.id,
        amount: Number(payment.amount ?? 0),
        method: payment.method ?? 'cash',
        method_display: payment.method ?? 'cash',
        month: payment.month ?? '—',
        status: payment.status ?? 'due',
        statusColor: info.color,
        status_display: info.label,
        statusDisplay: info.label,
        student_name: student?.full_name ?? 'Unknown Student',
        room_number: '—',
        property_name: accId ? accNameById.get(accId) ?? 'Unassigned' : 'Unassigned',
        paid_at: payment.paid_at ?? null,
      }
    })
  } catch (e) {
    error.value = e instanceof Error ? e.message : 'Failed to load payments'
    console.error('loadPayments error:', e)
  }
}

function handleLogout() {
  useAuthStore().clearCachedRole()
  void supabase.auth.signOut()
  void useRouter().push('/login')
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
</style>

