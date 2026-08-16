import type { RouteRecordRaw } from 'vue-router';

const landlordRoutes: RouteRecordRaw[] = [
  {
    path: '/landlord/dashboard',
    component: () => import('@/modules/landlord/pages/LandlordDashboard.vue'),
  },
  {
    path: '/landlord/tenants',
    component: () => import('@/modules/landlord/pages/LandlordTenants.vue'),
  },
  {
    path: '/landlord/payments',
    component: () => import('@/modules/landlord/pages/LandlordPayments.vue'),
  },
  {
    path: '/landlord/properties',
    component: () => import('@/modules/landlord/pages/LandlordProperties.vue'),
  },
  {
    path: '/landlord/properties/new',
    component: () => import('@/modules/landlord/pages/LandlordAddProperty.vue'),
  },
  {
    path: '/landlord/profile',
    component: () => import('@/modules/landlord/pages/LandlordProfile.vue'),
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
];

export default landlordRoutes;