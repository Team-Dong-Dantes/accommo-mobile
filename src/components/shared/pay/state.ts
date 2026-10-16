// Paying: what is picked and how much, where it goes, the proof, and
// record_payments() — as one transfer the landlord/landlady confirms.
import { METHODS, type Method } from './model'
import { type Seed } from './model'
import { computed, ref, watch } from 'vue'
import { errorMessage } from '@/utils/errors'
import { fileFingerprint, minPayment, normalizeReference, referenceProblem } from '@/utils/payments'
import { formatPesoExact, landlordTitle } from '@/utils/format'
import { supabase } from '@/utils/supabase'
import { uploadSecureDocument } from '@/utils/upload'
import { useNotify } from '@/utils/notify'
import { usePayItems } from '@/utils/usePayItems'

export function createPaySheet(ctx: Seed) {
  const { props, emit } = ctx
  const notify = useNotify()

  const { loading, months, billIds, deposit, depositRow, picked, total, items, load } = usePayItems(
    () => props.leaseId,
    () => props.startDate,
    () => Boolean(props.settleOnly),
  )
  const payout = ref<{ gcash_number: string | null; gcash_name: string | null; maya_number: string | null; maya_name: string | null; bank_name: string | null; bank_account_number: string | null; bank_account_name: string | null; note: string | null } | null>(null)
  const landlordSex = ref<string | null>(null)
  const who = computed(() => landlordTitle(landlordSex.value).toLowerCase())
  const pronoun = computed(() => (landlordSex.value?.toUpperCase() === 'F' ? 'she' : landlordSex.value?.toUpperCase() === 'M' ? 'he' : 'they'))

  const step = ref<1 | 2>(1)
  const payLess = ref(false)
  const amount = ref<number | ''>(0)
  const method = ref<Method>('gcash')
  const reference = ref('')
  const proofUrl = ref('')
  const proofHash = ref('')
  const proofPreview = ref('')
  const uploading = ref(false)
  const note = ref('')
  const promiseDate = ref('')
  const submitting = ref(false)
  const serverRefProblem = ref('')
  const serverProofProblem = ref('')

  const minAmount = computed(() => {
    const first = picked.value[0]
    if (!first) return 0.01
    return Math.min(total.value, minPayment(first, Boolean(props.allowPartial), props.partialMinPct ?? 10))
  })
  const canPayLess = computed(() => minAmount.value + 0.009 < total.value)
  const payAmount = computed(() => (payLess.value ? Math.round((Number(amount.value) || 0) * 100) / 100 : total.value))
  const quick = computed(() =>
    [
      { label: '25%', value: total.value * 0.25 },
      { label: 'Half', value: total.value * 0.5 },
      { label: '75%', value: total.value * 0.75 },
    ]
      .map((q) => ({ ...q, value: Math.round(q.value * 100) / 100 }))
      .filter((q) => q.value + 0.009 >= minAmount.value),
  )
  const refProblem = computed(() => referenceProblem(method.value, reference.value))
  const resubmitTitle = computed(() => (props.resubmit?.reason.includes('\n') ? props.resubmit.reason.split('\n')[0] : 'see why below'))
  const resubmitText = computed(() => {
    const r = props.resubmit?.reason ?? ''
    return r.includes('\n') ? r.split('\n').slice(1).join(' ') : r
  })

  const payTo = computed(() => {
    const p = payout.value
    if (!p) return null
    if (method.value === 'gcash' && p.gcash_number) return { number: p.gcash_number, name: p.gcash_name }
    if (method.value === 'maya' && p.maya_number) return { number: p.maya_number, name: p.maya_name }
    if (method.value === 'bank' && p.bank_account_number) return { number: p.bank_account_number, name: [p.bank_name, p.bank_account_name].filter(Boolean).join(' · ') }
    return null
  })
  async function copyText(text: string) {
    try {
      await navigator.clipboard.writeText(text)
      notify.success('Copied.')
    } catch {
      notify.error('Could not copy — long-press the number instead.')
    }
  }

  function startPayLess() {
    amount.value = Math.max(minAmount.value, Math.round(total.value * 50) / 100)
    payLess.value = true
  }

  // Fresh each time it opens: what's owed now, with what is already due picked.
  watch(
    () => props.modelValue,
    async (open) => {
      if (!open || !props.leaseId) return
      const re = props.resubmit ?? null
      step.value = re ? 2 : 1
      payLess.value = false
      method.value = re && (METHODS as readonly string[]).includes(re.method) ? (re.method as Method) : 'gcash'
      reference.value = ''
      proofUrl.value = ''
      proofHash.value = ''
      proofPreview.value = ''
      note.value = ''
      promiseDate.value = ''
      serverRefProblem.value = ''
      serverProofProblem.value = ''
      try {
        const [, payoutResult, person] = await Promise.all([
          load(re?.pick ?? null),
          props.landlordId
            ? supabase
                .from('landlord_payout')
                .select('gcash_number, gcash_name, maya_number, maya_name, bank_name, bank_account_number, bank_account_name, note')
                .eq('landlord_id', props.landlordId)
                .maybeSingle()
            : Promise.resolve({ data: null }),
          props.landlordId ? supabase.from('users').select('sex').eq('id', props.landlordId).maybeSingle() : Promise.resolve({ data: null }),
        ])
        payout.value = payoutResult.data
        landlordSex.value = (person.data as { sex: string | null } | null)?.sex ?? null
      } catch (e) {
        notify.error(errorMessage(e, 'Could not load what is owed.'))
      }
    },
    { immediate: true },
  )

  async function onProof(event: Event) {
    const input = event.target as HTMLInputElement
    const file = input.files?.[0]
    if (!file) return
    uploading.value = true
    serverProofProblem.value = ''
    try {
      const [url, hash] = await Promise.all([uploadSecureDocument(file), fileFingerprint(file)])
      proofUrl.value = url
      proofHash.value = hash ?? ''
      proofPreview.value = URL.createObjectURL(file)
    } catch (e) {
      notify.error(errorMessage(e, 'Could not upload the screenshot.'))
    } finally {
      uploading.value = false
      input.value = ''
    }
  }

  // What step 1 must get right before step 2. The database checks each of
  // these too; saying so here saves a round trip.
  function amountProblem(): string | null {
    if (!picked.value.length) return 'Tick at least one thing to pay.'
    const pay = payAmount.value
    if (!(pay > 0)) return 'Enter an amount.'
    if (pay > total.value + 0.009) return `That is more than what you ticked (${formatPesoExact(total.value)}).`
    if (pay + 0.009 < minAmount.value) {
      return minAmount.value >= total.value
        ? `Pay the full ${formatPesoExact(total.value)} — your ${who.value} hasn't turned on partial payments.`
        : `Pay at least ${formatPesoExact(minAmount.value)}.`
    }
    return null
  }
  function next() {
    const problem = amountProblem()
    if (problem) return notify.error(problem)
    step.value = 2
  }

  async function submit() {
    if (submitting.value || uploading.value) return
    const problem = amountProblem()
    if (problem) {
      step.value = 1
      return notify.error(problem)
    }
    const ref = normalizeReference(reference.value)
    if (method.value !== 'cash') {
      if (!ref) return notify.error('Enter the reference number from your receipt.')
      if (refProblem.value) return notify.error(refProblem.value)
      if (!proofUrl.value) return notify.error('Attach a screenshot of the receipt.')
    }
    submitting.value = true
    try {
      const partial = payAmount.value + 0.009 < total.value
      const { error } = await supabase.rpc('record_payments', {
        p_lease: props.leaseId,
        p_months: months.value,
        p_bills: billIds.value,
        // The advance is rent now (20261009010000); the parameter stays for older builds.
        p_advance: false,
        p_deposit: deposit.value && !!depositRow.value,
        p_method: method.value,
        ...(partial ? { p_amount: payAmount.value } : {}),
        ...(method.value !== 'cash' ? { p_reference: ref, p_proof_url: proofUrl.value } : {}),
        ...(proofHash.value && method.value !== 'cash' ? { p_proof_hash: proofHash.value } : {}),
        ...(note.value.trim() ? { p_note: note.value.trim() } : {}),
        ...(partial && promiseDate.value ? { p_promise_date: promiseDate.value } : {}),
      })
      if (error) throw error
      notify.success(method.value === 'cash' ? `Sent — your ${who.value} confirms once ${pronoun.value} has it.` : 'Sent for confirmation.')
      emit('update:modelValue', false)
      emit('submitted')
    } catch (e) {
      const msg = errorMessage(e, 'Could not send this payment.')
      // The two the database can refuse after step 2 is filled: show them on the field.
      if (/reference number/i.test(msg)) serverRefProblem.value = msg
      else if (/receipt image/i.test(msg)) serverProofProblem.value = msg
      else notify.error(msg)
    } finally {
      submitting.value = false
    }
  }

  return {
    notify,
    loading,
    months,
    billIds,
    deposit,
    depositRow,
    picked,
    total,
    items,
    load,
    payout,
    landlordSex,
    who,
    pronoun,
    step,
    payLess,
    amount,
    method,
    reference,
    proofUrl,
    proofHash,
    proofPreview,
    uploading,
    note,
    promiseDate,
    submitting,
    serverRefProblem,
    serverProofProblem,
    minAmount,
    canPayLess,
    payAmount,
    quick,
    refProblem,
    resubmitTitle,
    resubmitText,
    payTo,
    copyText,
    startPayLess,
    onProof,
    amountProblem,
    next,
    submit,
  }
}
