import type { RouteRecordRaw } from 'vue-router';
import landlordRoutes from '@/modules/landlord/router/routes';
import studentRoutes from '@/modules/student/router/routes';
import authRoutes from '@/modules/auth/router/routes';

const routes: RouteRecordRaw[] = [
  {
    path: '/',
    component: () => import('@/layouts/AuthLayout.vue'),
    children: [
      ...authRoutes,
    ],
  },

  {
    path: '/',
    component: () => import('@/modules/student/layouts/MainLayout.vue'),
    children: [
      ...studentRoutes,
    ],
  },

  {
    path: '/',
    component: () => import('@/modules/landlord/layouts/MainLayout.vue'),
    children: [
      ...landlordRoutes,
    ],
  },

  {
    path: '/:catchAll(.*)*',
    component: () => import('@/shared/pages/ErrorNotFound.vue'),
  },
];

export default routes;
