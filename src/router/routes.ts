import type { RouteRecordRaw } from 'vue-router';
import authRoutes from '@/router/auth';

// Feature routes were stripped for the rebuild. As each role's screens come
// back, add `src/router/manager.ts` / `src/router/student.ts` and mount them as
// children of MainLayout:
//
//   {
//     path: '/',
//     component: MainLayout,
//     children: [...managerRoutes, ...studentRoutes],
//   },
//
// MainLayout already carries the shell config for both roles.
// See docs/FEATURES.md for the screen-by-screen specification.
const routes: RouteRecordRaw[] = [
  {
    path: '/',
    component: () => import('@/layouts/AuthLayout.vue'),
    children: authRoutes,
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
