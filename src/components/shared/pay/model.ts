// What a payment can be paid with, and a transfer sent back to redo.
import { type PayPick } from '@/utils/usePayItems'

export interface Resubmit {
  reason: string
  method: string
  reference: string
  pick: PayPick
}

export const METHODS = ['gcash', 'maya', 'bank', 'cash'] as const
export type Method = (typeof METHODS)[number]

/** What the component hands its state: its props and emit. */
export interface Seed {
  props: { modelValue: boolean; leaseId: string; landlordId?: string | undefined; allowPartial?: boolean | undefined; partialMinPct?: number | undefined; subtitle?: string | undefined; settleOnly?: boolean | undefined; startDate?: string | undefined; resubmit?: Resubmit | null | undefined }
  emit: { (e: 'update:modelValue', open: boolean): void; (e: 'submitted'): void }
}
