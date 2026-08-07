import type { RouteRecordRaw } from 'vue-router';

const studentRoutes: RouteRecordRaw[] = [
  {
    path: '/student/dashboard',
    component: () => import('@/modules/student/pages/StudentDashboard.vue'),
  },
];

export default studentRoutes;
