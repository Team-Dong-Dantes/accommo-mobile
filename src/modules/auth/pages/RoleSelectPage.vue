<template>
  <q-page class="register-page">
    <div class="register-container column">
      <h3 class="auth-title col-auto">Create Account</h3>
      <p class="auth-subtitle col-auto">Are you a student or a landlord?</p>

      <div class="col column q-gutter-y-md q-mt-sm">
        <!-- Student — icon left, forward arrow right -->
        <button type="button" class="role-card full-width" @click="goStudent">
          <span class="role-icon role-icon--student">
            <IconifyIcon icon="material-icons:school" width="24" height="24" />
          </span>
          <span class="col text-left q-ml-md">
            <span class="role-title">Student</span>
            <span class="role-desc">Find and rent a verified boarding house</span>
          </span>
          <span class="role-arrow">
            <IconifyIcon icon="material-icons:arrow_forward" width="20" height="20" />
          </span>
        </button>

        <!-- Landlord — back arrow left, icon right -->
        <button type="button" class="role-card role-card--landlord full-width" @click="goLandlord">
          <span class="role-arrow">
            <IconifyIcon icon="material-icons:arrow_back" width="20" height="20" />
          </span>
          <span class="col text-left q-ml-md">
            <span class="role-title">Landlord</span>
            <span class="role-desc">List your property and find tenants</span>
          </span>
          <span class="role-icon role-icon--landlord">
            <IconifyIcon icon="material-icons:apartment" width="24" height="24" />
          </span>
        </button>
      </div>

      <div class="row justify-center items-center q-mt-lg">
        <span class="text-grey-7" style="font-size: 13px;">Already have an account?</span>
        <q-btn
          flat
          dense
          no-caps
          label="Sign In"
          color="teal-8"
          class="text-weight-bold q-ml-sm"
          to="/login"
        />
      </div>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { useRouter } from 'vue-router';
import { transitionDir } from '@/shared/utils/transition';

const router = useRouter();

function goStudent() {
  transitionDir.value = 'left';
  void router.push('/register');
}

function goLandlord() {
  transitionDir.value = 'right';
  void router.push('/register/landlord');
}
</script>

<style scoped>
.register-container {
  background: white;
  border-radius: 0 0 28px 28px;
  padding: 32px 24px 24px;
  min-height: calc(100vh - 160px);
  opacity: 0;
  animation: slideDown 0.6s cubic-bezier(0.25, 1, 0.3, 1) forwards;
}

.auth-title {
  margin: 0 0 0 12px;
  font-size: 34px;
  font-weight: 700;
}

.auth-subtitle {
  color: #8b8b8b;
  margin: 6px 0 8px 12px;
}

.role-card {
  display: flex;
  align-items: center;
  width: 100%;
  border: 1.5px solid var(--q-border, #e2e2e6);
  border-radius: 18px;
  padding: 18px 20px;
  background: #fafafa;
  color: #1d1d1d;
  text-align: left;
  font-family: inherit;
  cursor: pointer;
  transition: border-color 0.2s ease, background 0.2s ease, transform 0.2s ease;
}

.role-card:hover {
  border-color: #00897b;
  background: #f0faf9;
}

.role-card:active {
  transform: scale(0.985);
}

.role-icon {
  flex: 0 0 auto;
  width: 52px;
  height: 52px;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: 16px;
}

.role-icon--student {
  background: #e0f2f1;
  color: #00897b;
}

.role-icon--landlord {
  background: #fff3e0;
  color: #ef6c00;
}

.role-title {
  display: block;
  font-size: 18px;
  font-weight: 700;
  line-height: 1.2;
}

.role-desc {
  display: block;
  font-size: 13px;
  color: #8b8b8b;
  margin-top: 3px;
}

.role-arrow {
  flex: 0 0 auto;
  color: #9a9a9a;
  display: inline-flex;
}

@keyframes slideDown {
  0% {
    opacity: 0;
    transform: translateY(-80px);
  }

  100% {
    opacity: 1;
    transform: translateY(0);
  }
}
</style>
