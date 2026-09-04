import type { RouteRecordRaw } from 'vue-router';

const studentRoutes: RouteRecordRaw[] = [
  {
    path: '/student/home',
    component: () => import('@/pages/student/StudentDashboard.vue'),
  },
  {
    path: '/student/discover',
    component: () => import('@/pages/student/StudentDiscover.vue'),
  },
  {
    path: '/student/messages',
    component: () => import('@/pages/student/StudentMessages.vue'),
  },
  {
    path: '/student/notifications',
    component: () => import('@/pages/student/StudentNotifications.vue'),
  },
  {
    path: '/student/stay',
    component: () => import('@/pages/student/StudentStay.vue'),
  },
  {
    path: '/student/support',
    component: () => import('@/pages/student/StudentSupport.vue'),
  },
  {
    path: '/student/concerns',
    component: () => import('@/pages/student/StudentConcerns.vue'),
  },
  {
    path: '/student/payments',
    component: () => import('@/pages/student/StudentPayments.vue'),
  },
  {
    path: '/student/profile',
    component: () => import('@/pages/student/StudentProfile.vue'),
  },
  // Redirect legacy dashboard path
  {
    path: '/student/dashboard',
    redirect: '/student/home',
  },
];

export default studentRoutes;
