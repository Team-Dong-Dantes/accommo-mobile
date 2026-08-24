<template>
  <q-page class="register-page">
    <div class="register-container column">
      <h3 class="auth-title col-auto">Create Account</h3>
      <p class="auth-subtitle col-auto">Are you a student or a landlord?</p>

      <div class="col column q-gutter-y-md">
        <q-btn
          unelevated
          no-caps
          class="role-card full-width"
          @click="goStudent"
        >
          <div class="row items-center no-wrap full-width">
            <q-avatar size="48px" color="teal-1" text-color="teal-8" icon="material-icons:school" />
            <div class="col text-left q-ml-md">
              <div class="role-title">Student</div>
              <div class="role-desc">Find and rent a verified boarding house</div>
            </div>
            <IconifyIcon icon="material-icons:arrow_forward" class="text-grey-5" width="20" />
          </div>
        </q-btn>

        <q-btn
          unelevated
          no-caps
          class="role-card full-width"
          @click="goLandlord"
        >
          <div class="row items-center no-wrap full-width">
            <q-avatar size="48px" color="teal-1" text-color="teal-8" icon="material-icons:apartment" />
            <div class="col text-left q-ml-md">
              <div class="role-title">Landlord</div>
              <div class="role-desc">List your property and find tenants</div>
            </div>
            <IconifyIcon icon="material-icons:arrow_forward" class="text-grey-5" width="20" />
          </div>
        </q-btn>
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

const router = useRouter();

function goStudent() {
  void router.push('/register');
}

function goLandlord() {
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
  margin: 6px 0 28px 12px;
}

.role-card {
  background: #f5f5f5;
  border-radius: 16px;
  min-height: 88px;
  padding: 16px 20px;
  text-align: left;
  color: #1d1d1d;
  border: 1.5px solid transparent;
  transition: all 0.2s ease;
}

.role-card:hover {
  border-color: #00897b;
  background: #e0f2f1;
}

.role-title {
  font-size: 18px;
  font-weight: 700;
  line-height: 1.2;
}

.role-desc {
  font-size: 13px;
  color: #8b8b8b;
  margin-top: 2px;
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
