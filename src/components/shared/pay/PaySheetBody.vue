<template>
  <div v-if="loading" class="mx-body ps-center"><q-spinner size="24px" color="primary" /></div>
  <div v-else-if="!items.length" class="mx-body ps-center">
    <IconifyIcon icon="lucide:circle-check" width="32" class="ps-done" />
    <p class="mx-hint">Nothing is owed on this stay right now.</p>
  </div>

  <!-- Step 1: what, and where to send it. -->
  <div v-else-if="step === 1" class="mx-body">
    <PayItemList :items="items" />

    <div v-if="payLess" class="mx-field">
      <span class="mx-label">How much now?</span>
      <span class="mx-money">
        <span class="mx-money-sign">₱</span>
        <input v-model.number="amount" type="number" :min="minAmount" :max="total" step="0.01" inputmode="decimal" class="mx-money-input" aria-label="Amount now" />
        <span class="mx-money-of">of {{ formatPesoExact(total) }}</span>
      </span>
      <span class="ps-quick">
        <button v-for="q in quick" :key="q.label" type="button" class="ps-quick-btn" :class="{ 'ps-quick-btn--on': Math.abs(Number(amount) - q.value) < 0.01 }" @click="amount = q.value">
          {{ q.label }}
        </button>
      </span>
      <span class="mx-hint">Your {{ who }} allows part payments of at least {{ formatPesoExact(minAmount) }}.</span>
      <label v-if="Number(amount) + 0.009 < total" class="mx-field ps-promise">
        <span class="mx-label">When will you pay the other {{ formatPesoExact(total - (Number(amount) || 0)) }}?</span>
        <DateTimeField v-model="promiseDate" mode="date" :min="manilaToday()" placeholder="Pick a date" class="mx-input" />
        <span class="mx-hint">Optional. We'll remind you that day.</span>
      </label>
    </div>

    <div class="mx-field">
      <span class="mx-label">Send {{ formatPesoExact(payAmount) }} to</span>
      <div class="mx-segs" role="tablist" aria-label="How you'll pay">
        <button
          v-for="m in METHODS"
          :key="m"
          type="button"
          role="tab"
          class="mx-seg"
          :class="{ 'mx-seg--on': method === m }"
          :aria-selected="method === m"
          @click="method = m"
        >
          {{ m === 'bank' ? 'Bank' : PAYMENT_METHOD_LABEL[m] }}
        </button>
      </div>
      <div v-if="method !== 'cash' && payTo" class="ps-payto">
        <span class="ps-payto-body">
          <span class="ps-payto-number">{{ payTo.number }}</span>
          <span v-if="payTo.name" class="mx-hint">{{ payTo.name }}</span>
        </span>
        <button type="button" class="ps-copy" @click="copyText(payTo.number)">
          <IconifyIcon icon="lucide:copy" width="15" /> Copy
        </button>
      </div>
      <p v-else-if="method !== 'cash'" class="mx-hint">Your {{ who }} hasn't added {{ PAYMENT_METHOD_LABEL[method] }} details yet — ask them where to send it.</p>
      <p v-else class="mx-hint">You'll hand it over in person.</p>
      <p v-if="payout?.note" class="mx-hint">From your {{ who }}: “{{ payout.note }}”</p>
    </div>
  </div>

  <!-- Step 2, cash: no receipt — the landlord/landlady's own check is the proof. -->
  <div v-else-if="method === 'cash'" class="mx-body">
    <div v-if="props.resubmit" class="mx-banner mx-banner--danger">
      <IconifyIcon icon="lucide:undo-2" width="18" class="mx-banner-icon" />
      <span><b>Sent back</b> · {{ props.resubmit.reason.replace('\n', ' — ') }}</span>
    </div>
    <ol class="ps-steps">
      <li><span class="ps-num">1</span><span>Give {{ formatPesoExact(payAmount) }} to your {{ who }} in person.</span></li>
      <li><span class="ps-num">2</span><span>Tap <b>I handed it over</b> below, right after.</span></li>
      <li><span class="ps-num">3</span><span>Your {{ who }} confirms {{ pronoun }} got it, and it shows as paid.</span></li>
    </ol>
    <label class="mx-field">
      <span class="mx-label">Note (optional)</span>
      <input v-model="note" type="text" maxlength="300" class="mx-input" placeholder="e.g. Gave it at the gate" />
    </label>
  </div>

  <!-- Step 2: the reference and a screenshot. -->
  <div v-else class="mx-body">
    <div v-if="props.resubmit" class="mx-banner mx-banner--danger">
      <IconifyIcon icon="lucide:undo-2" width="18" class="mx-banner-icon" />
      <span>
        <b>Sent back: {{ resubmitTitle }}</b>
        <template v-if="resubmitText"><br />“{{ resubmitText }}”</template>
      </span>
    </div>
    <label class="mx-field">
      <span class="mx-label">{{ PAYMENT_METHOD_LABEL[method] }} reference number</span>
      <input
        :value="reference"
        type="text"
        class="mx-input mx-input--mono"
        :class="{ 'mx-input--bad': refProblem || serverRefProblem }"
        :inputmode="method === 'gcash' ? 'numeric' : 'text'"
        :placeholder="method === 'gcash' ? '13-digit GCash reference' : 'Reference number'"
        autocomplete="off"
        @input="onReference"
      />
      <span v-if="refProblem || serverRefProblem" class="mx-hint mx-hint--bad">{{ serverRefProblem || refProblem }}</span>
      <span v-else-if="props.resubmit && reference && normalizeReference(reference) !== props.resubmit.reference" class="mx-hint ps-ok">
        <IconifyIcon icon="lucide:check" width="14" /> Changed from last time
      </span>
    </label>
    <div class="mx-field">
      <span class="mx-label">Receipt screenshot</span>
      <span class="ps-file" :class="{ 'ps-file--chosen': proofUrl }">
        <img v-if="proofPreview" :src="proofPreview" alt="" class="ps-file-thumb" />
        <IconifyIcon v-else icon="lucide:image-plus" width="20" />
        <span class="ps-file-body">
          <span class="ps-file-title">{{ uploading ? 'Uploading…' : proofUrl ? 'Screenshot attached' : 'Attach a screenshot' }}</span>
          <span class="mx-hint">{{ proofUrl ? 'Tap to replace with a clearer one' : 'Of the receipt in your app' }}</span>
        </span>
        <input type="file" accept="image/*" class="ps-file-input" :disabled="uploading" @change="onProof" />
      </span>
      <span v-if="serverProofProblem" class="mx-hint mx-hint--bad">{{ serverProofProblem }}</span>
    </div>
    <label class="mx-field">
      <span class="mx-label">Note to your {{ who }} (optional)</span>
      <input v-model="note" type="text" maxlength="300" class="mx-input" placeholder="e.g. The rest after my allowance comes in" />
    </label>
  </div>
</template>

<script setup lang="ts">
// The sheet's body: step 1 picks what to pay and shows where to send it;
// step 2 is the reference and screenshot, or for cash just the hand-over.
import DateTimeField from '@/components/shared/DateTimeField.vue'
import { Icon as IconifyIcon } from '@iconify/vue'
import { METHODS } from './model'
import { PAYMENT_METHOD_LABEL, formatPesoExact } from '@/utils/format'
import PayItemList from '@/components/shared/PayItemList.vue'
import { formatReference, manilaToday, normalizeReference } from '@/utils/payments'
import { usePaySheet } from './paySheet'

const {
  props,
  loading,
  total,
  items,
  payout,
  who,
  pronoun,
  step,
  payLess,
  amount,
  method,
  reference,
  proofUrl,
  proofPreview,
  uploading,
  note,
  promiseDate,
  serverRefProblem,
  serverProofProblem,
  minAmount,
  payAmount,
  quick,
  refProblem,
  resubmitTitle,
  resubmitText,
  payTo,
  copyText,
  onProof,
} = usePaySheet()

// Written back to the field as well: a 14th GCash digit formats to the same
// value, so Vue would see no change and leave the extra digit on screen.
function onReference(e: Event) {
  const el = e.target as HTMLInputElement
  el.value = reference.value = formatReference(method.value, el.value)
  serverRefProblem.value = ''
}
</script>

<style scoped>
.ps-center {
  align-items: center;
  justify-content: center;
  text-align: center;
}
.ps-done {
  color: var(--m-success);
}
.ps-quick {
  display: flex;
  gap: 6px;
}
.ps-quick-btn {
  flex: 1;
  min-height: 40px;
  border: 1px solid var(--m-border);
  border-radius: 10px;
  background: var(--m-surface);
  color: var(--m-ink);
  cursor: pointer;
  font: inherit;
  font-size: 13.5px;
  font-weight: 700;
}
.ps-quick-btn--on {
  border-color: var(--m-primary);
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
}
.ps-promise {
  margin-top: 6px;
}
.ps-payto {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 14px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius-sm);
}
.ps-payto-body {
  display: flex;
  min-width: 0;
  flex: 1;
  flex-direction: column;
  gap: 2px;
}
.ps-payto-number {
  color: var(--m-ink);
  font-family: var(--m-font-mono);
  font-size: 19px;
  font-weight: 500;
  letter-spacing: 0.02em;
}
.ps-copy {
  display: inline-flex;
  min-height: 40px;
  flex: 0 0 auto;
  align-items: center;
  gap: 6px;
  padding: 0 14px;
  border: 0;
  border-radius: 999px;
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
  cursor: pointer;
  font: inherit;
  font-size: 13.5px;
  font-weight: 700;
}
.ps-steps {
  display: flex;
  flex: 0 0 auto;
  flex-direction: column;
  gap: 14px;
  margin: 0;
  padding: 16px;
  border-radius: var(--m-radius);
  background: var(--m-bg);
  list-style: none;
}
.ps-steps li {
  display: flex;
  align-items: flex-start;
  gap: 12px;
  color: var(--m-text);
  font-size: 14px;
  line-height: 1.45;
}
.ps-num {
  display: inline-flex;
  width: 26px;
  height: 26px;
  flex: 0 0 auto;
  align-items: center;
  justify-content: center;
  border-radius: 50%;
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
  font-size: 13px;
  font-weight: 700;
}
.ps-ok {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  color: var(--m-success);
  font-weight: 600;
}
.ps-file {
  position: relative;
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 10px;
  border: 1.5px dashed var(--m-border);
  border-radius: var(--m-radius-sm);
  background: var(--m-bg);
  color: var(--m-muted);
}
.ps-file--chosen {
  border-style: solid;
}
.ps-file-thumb {
  width: 52px;
  height: 70px;
  flex: 0 0 auto;
  border: 1px solid var(--m-border);
  border-radius: 8px;
  object-fit: cover;
}
.ps-file-body {
  display: flex;
  min-width: 0;
  flex: 1;
  flex-direction: column;
  gap: 2px;
}
.ps-file-title {
  color: var(--m-ink);
  font-size: 14px;
  font-weight: 700;
}
.ps-file-input {
  position: absolute;
  inset: 0;
  width: 100%;
  height: 100%;
  opacity: 0;
  cursor: pointer;
}
</style>
