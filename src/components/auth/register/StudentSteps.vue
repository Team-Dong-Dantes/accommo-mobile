<template>
  <!-- Studies (student only) -->
  <template v-if="current === 'studies'">
    <AuthFieldGroup>
      <AppSelect
        v-model="form.college"
        :options="collegeOptions"
        label="College"
        class="auth-row"
        :rules="[(val) => !!val || 'Please select your college']"
        acronym
        @update:model-value="onCollegeChange"
      />

      <AppSelect
        v-model="form.program"
        :options="filteredPrograms"
        label="Program"
        class="auth-row"
        :rules="[(val) => !!val || 'Please select your program']"
        acronym
        :disable="!form.college"
      />

      <AppSelect
        v-model="form.yearLevel"
        :options="yearOptions"
        label="Year Level"
        class="auth-row"
        :rules="[(val) => !!val || 'Please select your year level']"
      />
    </AuthFieldGroup>
</template>

<!-- Student ID -->
<!-- Two halves, because that is what a student ID is: an entry year
     and a student number. One free-text box let "Lol" and
     "TEST-LICHTZY-0" into the table. -->
<template v-else-if="current === 'studentId'">
  <AuthFieldGroup>
    <div class="row name-row">
      <div class="col-4">
        <AuthInput
          v-model="form.studentIdYear"
          label="Year"
          maxlength="2"
          inputmode="numeric"
          placeholder="YY"
          autofocus
          :rules="[
            (val: string) => !!val || 'Required',
            (val: string) => /^\d{2}$/.test(val) || '2 digits',
          ]"
          @update:model-value="form.studentIdYear = digitsOnly($event, 2)"
        />
      </div>
      <div class="col-8 name-split">
        <AuthInput
          v-model="form.studentIdNumber"
          label="Student Number"
          maxlength="6"
          inputmode="numeric"
          placeholder="NNNN"
          :rules="[
            (val: string) => !!val || 'Student number is required',
            (val: string) => /^\d{4,6}$/.test(val) || 'Between 4 and 6 digits',
          ]"
          @update:model-value="form.studentIdNumber = digitsOnly($event, 6)"
        />
      </div>
    </div>
  </AuthFieldGroup>
</template>

<!-- Proof of enrolment (student, optional): one document per screen,
     each skippable on its own. -->
<template v-else-if="current === 'schoolId'">
  <AuthDocumentCard
    v-model="form.schoolIdFile"
    v-model:text="form.schoolIdText"
    :check="(text: string) => checkDocument('school_id', text, documentExpected)"
    title="School ID"
    hint="The front, with all four corners in the frame."
    icon="lucide:id-card"
  />
</template>

<template v-else-if="current === 'assessment'">
  <AuthDocumentCard
    v-model="form.assessmentFile"
    v-model:text="form.assessmentText"
    :check="(text: string) => checkDocument('assessment_of_fees', text, documentExpected)"
    title="Assessment of Fees"
    hint="This term's copy, showing your name."
    icon="lucide:receipt-text"
  />
</template>

<!-- App PIN (student, optional, last).
     Plain fields rather than PinSetupDialog's keypad: that component
     is right for an interruption — Settings, the forgot-PIN path, the
     offer after signing in — but this is a question in a form, and it
     should look like the screens before it. -->
<!-- Two separate blocks, not two rows of one group: a PIN and its
     confirmation are the same secret typed twice, and fusing them
     behind a hairline made the second read as another field to fill
     rather than a check on the first. Six cells apiece, because the
     PIN is exactly six digits and the boxes say so without a rule
     having to. -->
<template v-else-if="current === 'pin'">
  <q-field
    :model-value="form.pin + form.pinConfirm"
    :rules="[pinPairRule]"
    lazy-rules="ondemand"
    borderless
    hide-bottom-space
    class="pin-field"
  >
    <template #control>
      <div class="pin-blocks">
        <div class="pin-block">
          <span class="pin-label">Choose a PIN</span>
          <PinCells ref="pinCellsRef" v-model="form.pin" aria-label="PIN" />
        </div>

        <div class="pin-block">
          <span class="pin-label">Type it again</span>
          <PinCells
            v-model="form.pinConfirm"
            aria-label="Confirm PIN"
            :invalid="pinMismatch"
          />
        </div>
      </div>
    </template>
  </q-field>
</template>
</template>

<script setup lang="ts">
// A student's screens: studies, the student ID, the optional enrolment
// documents and the optional app PIN.
import AppSelect from '@/components/shared/AppSelect.vue'
import AuthDocumentCard from '@/components/auth/AuthDocumentCard.vue'
import AuthFieldGroup from '@/components/auth/AuthFieldGroup.vue'
import AuthInput from '@/components/auth/AuthInput.vue'
import PinCells from '@/components/shared/PinCells.vue'
import { computed, nextTick, ref, watch } from 'vue'
import { checkDocument } from '@/utils/docReading'
import { yearOptions } from '@/constants/academics'
import { useRegister } from './register'

const {
  digitsOnly,
  collegeOptions,
  current,
  form,
  filteredPrograms,
  onCollegeChange,
  documentExpected,
} = useRegister()

const pinCellsRef = ref<InstanceType<typeof PinCells> | null>(null)

// The PIN cells are a label over a hidden input, so `autofocus` has nothing
// obvious to attach to — the screen focuses them itself, as the text screens do
// with their first field.
watch(current, (step) => {
  if (step === 'pin') void nextTick(() => pinCellsRef.value?.focus())
})

/**
 * The PIN is optional, so an empty pair passes — but a half-entered one must
 * not. One rule over both cells rather than one each: the only thing worth
 * saying is about the pair, and a message under the first block would be
 * pointing at the wrong one.
 */
function pinPairRule(): boolean | string {
  if (!form.pin && !form.pinConfirm) return true
  if (form.pin.length !== 6) return 'A PIN is six digits'
  if (form.pin !== form.pinConfirm) return 'The two PINs do not match'
  return true
}

/** Shakes the second row once both are full and they disagree. */
const pinMismatch = computed(
  () => form.pinConfirm.length === 6 && form.pin.length === 6 && form.pin !== form.pinConfirm,
)
</script>

<style scoped>
/* Each name row is a wide field and a narrow one — First + M.I., then Last +
   Ext. — so the hairline runs between them vertically rather than the group's
   usual horizontal one. The group supplies the horizontal rule between rows. */
.name-row > div {
  min-width: 0;
}
.name-split {
  border-left: 1px solid var(--m-border);
}

/* The PIN pair. Two blocks with air between them rather than two rows sharing a
   hairline: the second is a check on the first, not another thing to fill in. */
.pin-field :deep(.q-field__control) {
  min-height: 0;
  padding: 0;
}
.pin-field :deep(.q-field__native) {
  padding: 0;
}
.pin-blocks {
  display: flex;
  width: 100%;
  flex-direction: column;
  gap: 18px;
}
.pin-block {
  display: flex;
  flex-direction: column;
  gap: 8px;
}
.pin-label {
  margin-left: 2px;
  color: var(--m-muted);
  font-size: 11.5px;
  font-weight: 700;
  letter-spacing: 0.05em;
  text-transform: uppercase;
}
</style>
