<template>
  <!-- Name. Google sits on this screen rather than a chooser of its own:
       connecting Google fills in exactly the name and e-mail this screen
       and the next one ask for, so it belongs beside the fields it
       saves you typing. The consent closes the screen, below the fields:
       an ordinary part of the form, required to leave the screen, and
       deliberately not a gate on the Google button above it. -->
  <template v-if="current === 'name'">
    <template v-if="!isGoogleMode">
      <!-- "Connect", because that is what it does. This button signs
           nobody up: it links a Google account, fills in the two name
           fields and the e-mail, and leaves every remaining screen —
           phone, studies, student ID, proof — to be answered as normal.
           The app already said so on the other side of it, where success
           renders ConnectedGoogleBox reading "Google Connected" with an
           unlink button. Login is a different action and keeps its own
           wording, since signing in with Google really is signing in.

           Pressable with nothing else on the screen filled in — no
           fields, no consent. See handleGoogleAuth for what that costs
           and what still holds. -->

      <AuthGoogleBtn @click="handleGoogleAuth">Connect with Google</AuthGoogleBtn>
      <AuthDivider />
    </template>
    <template v-else>
      <ConnectedGoogleBox :email="form.email" @cancel="cancelGoogle" />
    </template>

    <!-- Given name, middle initial, surname, extension — the order a
         Philippine record is written in, so the surname lands after the
         initial and the extension sits with the surname it belongs to. -->
    <AuthFieldGroup>
      <div class="row name-row">
        <div class="col-8">
          <AuthInput
            v-model="form.firstName"
            label="First Name"
            autofocus
            :rules="nameRules('First name')"
            @blur="tidyName('firstName')"
          />
        </div>
        <div class="col-4 name-split">
          <AuthInput
            v-model="form.middleInitial"
            label="M.I."
            maxlength="1"
            :rules="middleInitialRules"
            @blur="tidyName('middleInitial')"
          />
        </div>
      </div>

      <div class="row name-row">
        <div class="col-8">
          <AuthInput
            v-model="form.lastName"
            label="Last Name"
            :rules="nameRules('Last name')"
            @blur="tidyName('lastName')"
          />
        </div>
        <div class="col-4 name-split">
          <AppSelect
            v-model="form.nameExtension"
            :options="nameExtensions"
            label="Ext."
            class="auth-row"
          />
        </div>
      </div>

      <AppSelect
        v-model="form.sex"
        :options="sexOptions"
        label="Sex"
        class="auth-row"
        :rules="[(val) => !!val || 'Please select your sex']"
      />

      <!-- OSAS checks this against the birth date printed on the school or
           government ID uploaded later. The same calendar as the permit
           expiry dates; its month/year header jumps to a year grid. -->
      <DateTimeField
        v-model="form.dateOfBirth"
        mode="date"
        label="Date of Birth"
        class="auth-row"
        :max="adultCutoff"
        :rules="dateOfBirthRules"
      />
    </AuthFieldGroup>

    <AuthConsent v-model="agreedToTerms" />
</template>

<!-- Phone -->
<template v-else-if="current === 'phone'">
  <AuthFieldGroup>
    <!-- The +63 prefix stays: unlike the icons this replaced, it is
         part of the value rather than decoration. -->
    <AuthInput
      :model-value="spacedPhone(form.phoneDigits)"
      label="Phone Number"
      maxlength="12"
      inputmode="numeric"
      placeholder="912 345 6789"
      autofocus
      :rules="[
        (val: string) => !!val || 'Phone number is required',
        (val: string) => /^\d{10}$/.test(val.replace(/ /g, '')) || 'Enter exactly 10 digits',
        (val: string) => /^9\d{9}$/.test(val.replace(/ /g, '')) || 'Must start with 9 (e.g. 912 345 6789)',
        // The shared rule, so this screen and the profile editors
        // cannot drift apart on what counts as a number again.
        (val: string) => isPhMobile(val) || 'That is not a usable mobile number',
      ]"
      @update:model-value="form.phoneDigits = phNationalDigits($event).slice(0, 10)"
    >
      <template #prepend>
        <span class="phone-prefix">+63</span>
      </template>
    </AuthInput>
  </AuthFieldGroup>
</template>

<!-- E-mail address -->
<template v-else-if="current === 'email'">
  <AuthFieldGroup>
    <AuthInput
      v-model="form.emailUser"
      label="Email"
      autofocus
      :rules="[
        (val: string) => !!val || 'Email is required',
        (val: string) => /^[a-zA-Z0-9._%+-]+$/.test(val) || 'Invalid email username',
      ]"
    >
      <template #append>
        <div class="row items-center no-wrap">
          <span class="text-grey-7 text-weight-medium q-mr-xs" style="font-size: 16px">@</span>
          <!-- Sits inside the e-mail field, so it carries no box of its
               own; .stop keeps the tap from also focusing the input. -->
          <span @click.stop>
            <AppSelect
              v-model="form.emailDomain"
              :options="emailDomains"
              placeholder="E-mail domain"
              class="email-domain"
            />
          </span>
        </div>
      </template>
    </AuthInput>
  </AuthFieldGroup>
</template>

<!-- Password -->
<template v-else-if="current === 'password'">
  <AuthFieldGroup>
  <AuthInput
    v-model="form.password"
    :type="showPassword ? 'text' : 'password'"
    label="Password"
    autofocus
    :rules="[
      (val: string) => !!val || 'Password is required',
      (val: string) => val.length >= 8 || 'At least 8 characters',
      (val: string) => /[a-z]/.test(val) || 'Must include a lowercase letter',
      (val: string) => /[A-Z]/.test(val) || 'Must include an uppercase letter',
      (val: string) => /\d/.test(val) || 'Must include a number',
      (val: string) => /[!@#$%^&*]/.test(val) || 'Must include a special character (!@#$%^&*)',
    ]"
  >
    <template #append>
      <IconifyIcon
        :icon="showPassword ? 'lucide:eye-off' : 'lucide:eye'"
        class="cursor-pointer"
        @click="showPassword = !showPassword"
      />
    </template>
  </AuthInput>

  <!-- A row of chips inside the group, not a five-line bullet list
       below it: the same five rules in a fifth of the height, and
       they sit attached to the field they describe. -->
  <div class="pw-checks">
    <span v-for="item in passwordChecks" :key="item.label" class="pw-chip" :class="{ ok: item.ok }">
      <IconifyIcon :icon="item.ok ? 'lucide:check' : 'lucide:minus'" width="12" />
      {{ item.short }}
    </span>
  </div>

  <AuthInput
    v-model="form.confirmPassword"
    :type="showConfirmPassword ? 'text' : 'password'"
    label="Confirm Password"
    :rules="[
      (val: string) => !!val || 'Please confirm your password',
      (val: string) => val === form.password || 'Passwords do not match',
    ]"
  >
    <template #append>
      <IconifyIcon
        :icon="showConfirmPassword ? 'lucide:eye-off' : 'lucide:eye'"
        class="cursor-pointer"
        @click="showConfirmPassword = !showConfirmPassword"
      />
    </template>
  </AuthInput>
  </AuthFieldGroup>
</template>

<!-- Confirm e-mail -->
<!-- The account already exists by the time this screen renders —
     nextStep() creates it on leaving Password — and EmailVerifyInline
     sends the code itself on mount. So there is nothing to press
     before the code field: the screen opens ready to type into.
     The confirmed panel below is the back-navigation state; verifying
     advances the flow on its own, so nobody arrives at it forwards. -->
<template v-else-if="current === 'verify'">
  <EmailVerifyInline v-if="!emailVerified" :email="form.email" @verified="onEmailVerified" />
  <div v-else class="otp-verified">
    <IconifyIcon icon="lucide:circle-check" width="26" class="q-mr-sm" />
    <div>
      <strong>E-mail confirmed</strong>
      <span class="text-grey-7">
        {{ isManager ? ' Continue to upload your requirements.' : ' You’re verified. Continue to your academic details.' }}
      </span>
    </div>
  </div>
</template>
</template>

<script setup lang="ts">
// The account screens every role sees: name (with Google), phone, e-mail,
// password and the e-mail code.
import AppSelect from '@/components/shared/AppSelect.vue';
import AuthConsent from '@/components/auth/AuthConsent.vue';
import AuthDivider from '@/components/auth/AuthDivider.vue';
import AuthFieldGroup from '@/components/auth/AuthFieldGroup.vue';
import AuthGoogleBtn from '@/components/auth/AuthGoogleBtn.vue';
import AuthInput from '@/components/auth/AuthInput.vue';
import ConnectedGoogleBox from '@/components/auth/ConnectedGoogleBox.vue';
import DateTimeField from '@/components/shared/DateTimeField.vue';
import EmailVerifyInline from '@/components/auth/EmailVerifyInline.vue';
import { Icon as IconifyIcon } from '@iconify/vue';
import { isPhMobile, phNationalDigits } from '@/utils/format';
import { nameExtensions, sexOptions } from './model';
import { useRegister } from './register';

const {
  isManager,
  spacedPhone,
  agreedToTerms,
  isGoogleMode,
  emailVerified,
  showPassword,
  showConfirmPassword,
  adultCutoff,
  dateOfBirthRules,
  nameRules,
  middleInitialRules,
  tidyName,
  emailDomains,
  current,
  form,
  passwordChecks,
  handleGoogleAuth,
  cancelGoogle,
  onEmailVerified,
} = useRegister();
</script>

<style scoped>
.otp-verified {
  display: flex;
  align-items: center;
  padding: 8px;
  font-size: 13px;
  line-height: 1.4;
}
/* Part of the value, so it matches the input rather than sitting back like the
   icons it replaced. */
.phone-prefix {
  color: var(--m-ink);
  font-size: 16px;
  font-weight: 500;
}
/* Each name row is a wide field and a narrow one — First + M.I., then Last +
   Ext. — so the hairline runs between them vertically rather than the group's
   usual horizontal one. The group supplies the horizontal rule between rows. */
.name-row > div {
  min-width: 0;
}
.name-split {
  border-left: 1px solid var(--m-border);
}
.pw-checks {
  display: flex;
  flex-wrap: wrap;
  gap: 5px;
  padding: 10px 16px 12px;
}
.pw-chip {
  display: inline-flex;
  align-items: center;
  gap: 3px;
  padding: 3px 9px;
  border-radius: 999px;
  background: var(--m-surface);
  color: var(--m-muted);
  font-size: 11.5px;
  font-weight: 600;
}
.pw-chip.ok {
  background: var(--m-success-soft);
  color: var(--m-success);
}
.email-domain {
  min-height: 36px;
  padding: 0 2px;
  border: 0;
  background: transparent;
  color: var(--m-ink);
  font-size: 16px;
  gap: 4px;
}
</style>
