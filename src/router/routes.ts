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
    component: () => import('@/layouts/MainLayout.vue'),
    children: [
      ...landlordRoutes,
      {
        path: '/profile',
        component: () => import('@/shared/pages/ProfilePage.vue'),
      },
      {
        path: '/landlord/dashboard',
        component: () => import('@/modules/landlord/pages/LandlordDashboard.vue'),
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
      {
        path: '/landlord/support',
        component: () => import('@/modules/landlord/pages/LandlordSupportPage.vue'),
      },
      {
        path: '/landlord/osas-compliance',
        component: () => import('@/modules/landlord/pages/LandlordOSASCompliancePage.vue'),
      },
      {
        path: '/landlord/properties',
        component: () => import('@/modules/landlord/pages/LandlordPropertiesPage.vue'),
      },
    ],
  },

  {
    path: '/:catchAll(.*)*',
    component: () => import('@/shared/pages/ErrorNotFound.vue'),
  },
];

export default routes;

