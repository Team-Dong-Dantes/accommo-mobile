// A payment under review, and the reasons a landlord/landlady can send one back.

export const REASONS = [
  "The amount doesn't match what arrived",
  "I can't find this reference number",
  'The screenshot is unclear',
  'Nothing has arrived yet',
  'Something else',
] as const

export interface Row {
  id: string
  lease_id: string
  batch_id: string | null
  kind: string
  month: string
  bill_id: string | null
  amount: number
  method: string
  status: string
  txn_reference: string | null
  proof_url: string | null
  note: string | null
  promise_date: string | null
  created_at: string
  paid_at: string | null
  rejection_reason: string | null
  receipt_no: string | null
  verified_by_user: { full_name: string | null } | null
}

/** What the component hands its state: its props and emit. */
export interface Seed {
  props: { modelValue: boolean; paymentId: string | null }
  emit: { (e: 'update:modelValue', open: boolean): void; (e: 'changed'): void }
}
