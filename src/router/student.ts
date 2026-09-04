import type { RouteRecordRaw } from 'vue-router';

const studentRoutes: RouteRecordRaw[] = [
  {
    path: '/student/home',
    component: () => import('@/pages/student/StudentDashboard.vue'),
  },
  // Legacy path kept so old links and the auth guard both land somewhere real.
  {
    path: '/student/dashboard',
    redirect: '/student/home',
  },
];

export default studentRoutes;
