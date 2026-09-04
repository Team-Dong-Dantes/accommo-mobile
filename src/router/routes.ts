import type { RouteRecordRaw } from 'vue-router';
import MainLayout from '@/layouts/MainLayout.vue';
import authRoutes from '@/router/auth';
import managerRoutes from '@/router/manager';
import studentRoutes from '@/router/student';

const routes: RouteRecordRaw[] = [
  {
    path: '/',
    component: () => import('@/layouts/AuthLayout.vue'),
    children: authRoutes,
  },

  // One app shell for both signed-in roles; it configures itself from the path.
  {
    path: '/',
    component: MainLayout,
    children: [...managerRoutes, ...studentRoutes],
  },

  {
    path: '/ui-bible',
    component: () => import('@/pages/UIBible.vue'),
  },

  {
    path: '/:catchAll(.*)*',
    component: () => import('@/pages/ErrorNotFound.vue'),
  },
];

export default routes;
