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
    component: () => import('@/modules/landlord/pages/PropertiesListPage.vue'),
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
    path: '/landlord/properties/new',
    component: () => import('@/modules/landlord/pages/AddPropertyWizard.vue'),
  },
  {
    path: '/landlord/properties/:id',
    component: () => import('@/modules/landlord/pages/PropertyDetailPage.vue'),
  },
  {
    path: '/landlord/profile',
    component: () => import('@/modules/landlord/pages/LandlordProfile.vue'),
  },
  {
    path: '/landlord/settings',
    component: () => import('@/modules/landlord/pages/LandlordSettingsPage.vue'),
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
