import { defineStore } from 'pinia'
import type { PaymentRecord, TenantBillingState } from '@/shared/types/app-types'

export const useTenantBillingStore = defineStore('tenant-billing', {
  state: () => ({
    currentTenant: null as any,
    billingState: {
      monthlyRent: 0,
      payStreak: 0,
      pendingAmount: 0,
      paymentHistory: [] as PaymentRecord[],
    } as TenantBillingState,
    isLoggingPayment: false,
  }),

  getters: {
    hasPendingPayments: (state) => state.billingState.paymentHistory.some(
      (ph: PaymentRecord) => ph.status === 'Pending',
    ),
    overdueCount: (state) => state.billingState.paymentHistory.filter(
      (ph: PaymentRecord) => ph.status === 'Overdue' || ph.status === 'Pending',
    ).length,
  },

  actions: {
    async setCurrentTenant(tenantData: any) {
      this.currentTenant = tenantData
      this.billingState = {
        monthlyRent: tenantData.monthlyRate || 0,
        payStreak: tenantData.payStreak || 0,
        pendingAmount: 0,
        paymentHistory: tenantData.paymentHistory || [],
      }
    },

    async logCashPayment(amount: number, month: string, onSuccess?: (msg: string) => void) {
      this.isLoggingPayment = true

      const newRecord: PaymentRecord = {
        month,
        dueDate: new Date().toISOString().split('T')[0],
        amount,
        status: 'Pending',
        paymentMethod: 'Cash',
      }

      this.billingState.paymentHistory.unshift(newRecord)
      this.billingState.pendingAmount += amount

      const lastStatus = this.billingState.paymentHistory
        .slice(1)
        .find((ph: PaymentRecord) => ph.status === 'Paid')

      if (lastStatus) {
        this.billingState.payStreak =
          this.billingState.payStreak + 1
      }

      this.isLoggingPayment = false

      const msg = `Cash payment of ₱${amount} logged for ${month}.`
      if (onSuccess) onSuccess(msg)
      else console.log(msg)
    },

    async markPaymentPaid(month: string, onSuccess?: (msg: string) => void) {
      const record = this.billingState.paymentHistory.find(
        (ph) => ph.month === month,
      )

      if (record) {
        record.status = 'Paid'
        record.paymentMethod = 'Cash'

        this.billingState.pendingAmount -= record.amount

        const allPaid = this.billingState.paymentHistory.every(
          (ph) => ph.status === 'Paid',
        )
        if (allPaid) {
          this.billingState.payStreak += 1
        }

        const msg = `Payment for ${month} marked as Paid.`
        if (onSuccess) onSuccess(msg)
        else console.log(msg)
      }
    },
  },
})