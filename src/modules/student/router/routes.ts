import type { RouteRecordRaw } from 'vue-router';

const studentRoutes: RouteRecordRaw[] = [
  {
    path: '/student/dashboard',
    component: () => import('@/modules/student/pages/StudentDashboard.vue'),
  },
  {
    path: '/student/support',
    component: () => import('@/modules/student/pages/StudentSupport.vue'),
  },
  {
    path: '/student/concerns',
    component: () => import('@/modules/student/pages/StudentConcerns.vue'),
  },
  {
    path: '/student/payments',
    component: () => import('@/modules/student/pages/StudentPayments.vue'),
  },
];

export default studentRoutes;
