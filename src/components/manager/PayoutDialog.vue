<template>
  <q-dialog :model-value="modelValue" position="bottom" @update:model-value="emit('update:modelValue', $event)">
    <q-card class="po-sheet">
      <h3 class="po-title">Payment details</h3>
      <p class="po-note">Your tenants see these when they pay, with a button to copy the number. Leave out any you don't use.</p>

      <p class="po-group">GCash</p>
      <input v-model="form.gcash_number" type="tel" inputmode="numeric" maxlength="11" class="po-input" placeholder="09XXXXXXXXX" />
      <input v-model="form.gcash_name" type="text" maxlength="100" class="po-input" placeholder="Account name" />

      <p class="po-group">Maya</p>
      <input v-model="form.maya_number" type="tel" inputmode="numeric" maxlength="11" class="po-input" placeholder="09XXXXXXXXX" />
      <input v-model="form.maya_name" type="text" maxlength="100" class="po-input" placeholder="Account name" />

      <p class="po-group">Bank</p>
      <input v-model="form.bank_name" type="text" maxlength="100" class="po-input" placeholder="Bank (e.g. Landbank)" />
      <input v-model="form.bank_account_number" type="text" inputmode="numeric" maxlength="30" class="po-input" placeholder="Account number" />
      <input v-model="form.bank_account_name" type="text" maxlength="100" class="po-input" placeholder="Account name" />

      <p class="po-group">Note for tenants (optional)</p>
      <input v-model="form.note" type="text" maxlength="300" class="po-input" placeholder="e.g. Cash is fine too — I'm home after 5 PM" />

      <q-btn unelevated rounded no-caps color="primary" class="po-submit" :loading="saving" label="Save" @click="save" />
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { reactive, ref, watch } from 'vue'
import { supabase, authUser } from '@/utils/supabase'
import { errorMessage } from '@/utils/errors'
import { useNotify } from '@/utils/notify'

// Where tenants send money (landlord_payout). Only the landlord/landlady's own
// tenants can read it; the database checks the number formats.
const props = defineProps<{ modelValue: boolean }>()
const emit = defineEmits<{ 'update:modelValue': [boolean] }>()
const notify = useNotify()

const FIELDS = ['gcash_number', 'gcash_name', 'maya_number', 'maya_name', 'bank_name', 'bank_account_number', 'bank_account_name', 'note'] as const
type Field = (typeof FIELDS)[number]
const form = reactive<Record<Field, string>>(Object.fromEntries(FIELDS.map((k) => [k, ''])) as Record<Field, string>)
const saving = ref(false)

watch(
  () => props.modelValue,
  async (open) => {
    if (!open) return
    const { data: auth } = await authUser()
    const { data } = await supabase.from('landlord_payout').select(FIELDS.join(',')).eq('landlord_id', auth?.user?.id ?? '').maybeSingle()
    for (const k of FIELDS) form[k] = ((data as Record<Field, string | null> | null)?.[k] ?? '') || ''
  },
)

async function save() {
  if (saving.value) return
  const row = Object.fromEntries(FIELDS.map((k) => [k, form[k].replace(k.endsWith('_number') && k !== 'bank_account_number' ? /\D/g : /^\s+|\s+$/g, '') || null])) as Record<Field, string | null>
  for (const k of ['gcash_number', 'maya_number'] as const) {
    if (row[k] && !/^09\d{9}$/.test(row[k])) return notify.error(`The ${k.startsWith('gcash') ? 'GCash' : 'Maya'} number should be 11 digits starting with 09.`)
  }
  if (row.bank_account_number && !/^[0-9 -]{6,30}$/.test(row.bank_account_number)) return notify.error('A bank account number is 6 to 30 digits.')
  saving.value = true
  try {
    const { data: auth } = await authUser()
    const { error } = await supabase
      .from('landlord_payout')
      .upsert({ landlord_id: auth?.user?.id ?? '', ...row, updated_at: new Date().toISOString() })
    if (error) throw error
    notify.success('Payment details saved.')
    emit('update:modelValue', false)
  } catch (e) {
    notify.error(errorMessage(e, 'Could not save your payment details.'))
  } finally {
    saving.value = false
  }
}
</script>

<style scoped>
.po-sheet {
  display: flex;
  width: 100%;
  max-width: 480px;
  flex-direction: column;
  gap: 8px;
  margin: 0 auto;
  padding: 16px var(--m-page-gutter) calc(16px + env(safe-area-inset-bottom));
  border-radius: var(--m-radius-lg, var(--m-radius)) var(--m-radius-lg, var(--m-radius)) 0 0;
}
.po-title {
  margin: 0;
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 17px;
  font-weight: 700;
}
.po-note {
  margin: -4px 0 0;
  color: var(--m-muted);
  font-size: 13px;
}
.po-group {
  margin: 6px 0 0;
  color: var(--m-muted);
  font-size: 12px;
  font-weight: 700;
  letter-spacing: 0.02em;
  text-transform: uppercase;
}
.po-input {
  min-height: 44px;
  padding: 0 12px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius-sm);
  background: var(--m-surface);
  color: var(--m-ink);
  font: inherit;
  font-size: 14px;
}
.po-submit {
  min-height: 48px;
  margin-top: 6px;
  font-weight: 700;
}
</style>
