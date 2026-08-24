import type { RouteRecordRaw } from 'vue-router';

const authRoutes: RouteRecordRaw[] = [
  {
    path: '',
    component: () => import('@/modules/auth/pages/GetStartedPage.vue'),
  },
  {
    path: 'login',
    component: () => import('@/modules/auth/pages/LoginPage.vue'),
  },
  {
    path: 'register',
    component: () => import('@/modules/auth/pages/RegisterPage.vue'),
  },
  {
    path: 'register/role',
    component: () => import('@/modules/auth/pages/RoleSelectPage.vue'),
  },
  {
    path: 'register/landlord',
    component: () => import('@/modules/auth/pages/LandlordRegisterPage.vue'),
  },
];

export default authRoutes;
