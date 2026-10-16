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
</template>

<script setup lang="ts">
// A student's screens: studies, the student ID and the optional enrolment
// documents.
import AppSelect from '@/components/shared/AppSelect.vue';
import AuthDocumentCard from '@/components/auth/AuthDocumentCard.vue';
import AuthFieldGroup from '@/components/auth/AuthFieldGroup.vue';
import AuthInput from '@/components/auth/AuthInput.vue';
import { checkDocument } from '@/utils/docReading';
import { yearOptions } from '@/constants/academics';
import { useRegister } from './register';

const {
  digitsOnly,
  collegeOptions,
  current,
  form,
  filteredPrograms,
  onCollegeChange,
  documentExpected,
} = useRegister();
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
</style>
