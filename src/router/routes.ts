import type { RouteRecordRaw } from 'vue-router';

const routes: RouteRecordRaw[] = [
  {
    path: '/',
    component: () => import('@/layouts/AuthLayout.vue'),
    children: [
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
        path: 'register/landlord',
        component: () => import('@/pages/auth/LandlordRegisterPage.vue'),
      },
    ],
  },

  {
    path: '/',
    component: () => import('@/layouts/MainLayout.vue'),
    children: [
      {
        path: 'student/dashboard',
        component: () => import('@/pages/student/StudentDashboard.vue'),
      },
      {
        path: 'landlord/dashboard',
        component: () => import('@/pages/landlord/LandlordDashboard.vue'),
      },
    ],
  },

  {
    path: '/:catchAll(.*)*',
    component: () => import('@/pages/ErrorNotFound.vue'),
  },
];

export default routes;
