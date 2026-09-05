import type { RouteRecordRaw } from 'vue-router'

const studentRoutes: RouteRecordRaw[] = [
  {
    path: '/student/home',
    component: () => import('@/pages/student/StudentDashboard.vue'),
  },
  {
    path: '/student/listing/:id',
    component: () => import('@/pages/student/StudentListingPage.vue'),
  },
  {
    path: '/student/discover',
    component: () => import('@/pages/student/StudentDiscoverPage.vue'),
  },
  {
    path: '/student/properties',
    component: () => import('@/pages/student/StudentPropertiesPage.vue'),
  },
  {
    path: '/student/room/:id',
    component: () => import('@/pages/student/StudentRoomPage.vue'),
  },
  {
    path: '/student/manager/:id',
    component: () => import('@/pages/student/StudentManagerPage.vue'),
  },
  {
    path: '/student/messages',
    component: () => import('@/pages/student/StudentMessagesPage.vue'),
  },
  {
    path: '/student/profile',
    component: () => import('@/pages/student/StudentProfilePage.vue'),
  },
  {
    path: '/student/profile/history',
    component: () => import('@/pages/student/StudentHistoryPage.vue'),
  },
  {
    path: '/student/notifications',
    component: () => import('@/pages/student/StudentNotificationsPage.vue'),
  },
  {
    path: '/student/support',
    component: () => import('@/pages/student/StudentOsasPage.vue'),
  },
  {
    path: '/student/concerns',
    component: () => import('@/pages/student/StudentConcernsPage.vue'),
  },
  {
    path: '/student/payments',
    component: () => import('@/pages/student/StudentPaymentsPage.vue'),
  },
  {
    path: '/student/stay',
    component: () => import('@/pages/student/StudentStayPage.vue'),
  },
  // Legacy path kept so old links and the auth guard both land somewhere real.
  {
    path: '/student/dashboard',
    redirect: '/student/home',
  },
]

export default studentRoutes
