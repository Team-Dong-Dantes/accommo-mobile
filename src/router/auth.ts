import type { RouteRecordRaw } from 'vue-router';

const authRoutes: RouteRecordRaw[] = [
  {
    path: '',
    component: () => import('@/pages/auth/GetStartedPage.vue'),
  },
  {
    path: 'login',
    component: () => import('@/pages/auth/LoginPage.vue'),
  },
  {
    path: 'register',
    component: () => import('@/pages/auth/RegisterPage.vue'),
  },
  {
    path: 'register/role',
    component: () => import('@/pages/auth/RoleSelectPage.vue'),
  },
  {
    path: 'register/manager',
    component: () => import('@/pages/auth/ManagerRegisterPage.vue'),
  },
];

export default authRoutes;
