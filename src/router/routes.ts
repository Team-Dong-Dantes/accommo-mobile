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
    component: () => import('@/layouts/MainLayout.vue'),
    children: [
      ...landlordRoutes,
      ...studentRoutes,
      {
        path: '/profile',
        component: () => import('@/shared/pages/ProfilePage.vue'),
      },
      {
        path: '/landlord/profile',
        component: () => import('@/modules/landlord/pages/LandlordProfile.vue'),
      },
      {
        path: '/landlord/dashboard',
        component: () => import('@/modules/landlord/pages/LandlordDashboard.vue'),
      },
      {
        path: '/landlord/profile/qr-scanner',
        component: () => import('@/modules/landlord/pages/QRScannerPage.vue'),
      },
      {
        path: '/landlord/chat',
        component: () => import('@/modules/landlord/pages/ChatPage.vue'),
      },
      {
        path: '/landlord/tenant/:tenantId',
        component: () => import('@/modules/landlord/pages/TenantProfileBilling.vue'),
      },
      {
        path: '/landlord/notifications',
        component: () => import('@/modules/landlord/pages/LandlordNotifications.vue'),
      },
    ],
  },

  {
    path: '/:catchAll(.*)*',
    component: () => import('@/shared/pages/ErrorNotFound.vue'),
  },
];

export default routes;