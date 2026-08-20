import type { RouteRecordRaw } from 'vue-router';

const studentRoutes: RouteRecordRaw[] = [
  {
    path: '/student/home',
    component: () => import('@/modules/student/pages/StudentDashboard.vue'),
  },
  {
    path: '/student/discover',
    component: () => import('@/modules/student/pages/StudentDiscover.vue'),
  },
  {
    path: '/student/messages',
    component: () => import('@/modules/student/pages/StudentMessages.vue'),
  },
  {
    path: '/student/notifications',
    component: () => import('@/modules/student/pages/StudentNotifications.vue'),
  },
  {
    path: '/student/stay',
    component: () => import('@/modules/student/pages/StudentStay.vue'),
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
  {
    path: '/student/profile',
    component: () => import('@/modules/student/pages/StudentProfile.vue'),
  },
  // Redirect legacy dashboard path
  {
    path: '/student/dashboard',
    redirect: '/student/home',
  },
];

export default studentRoutes;
