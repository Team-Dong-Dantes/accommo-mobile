import type { RouteRecordRaw } from 'vue-router';

const managerRoutes: RouteRecordRaw[] = [
  {
    path: '/manager/dashboard',
    component: () => import('@/pages/manager/ManagerDashboard.vue'),
  },
  {
    path: '/manager/tenants',
    component: () => import('@/pages/manager/ManagerTenants.vue'),
  },
  {
    path: '/manager/payments',
    component: () => import('@/pages/manager/ManagerPayments.vue'),
  },
  {
    path: '/manager/properties',
    component: () => import('@/pages/manager/ManagerPropertiesPage.vue'),
  },
  {
    path: '/manager/support',
    component: () => import('@/pages/manager/ManagerSupportPage.vue'),
  },
  {
    path: '/manager/osas-compliance',
    component: () => import('@/pages/manager/ManagerOSASCompliancePage.vue'),
  },
  {
    path: '/manager/properties/new',
    component: () => import('@/components/manager/AddPropertyWizard.vue'),
  },
  {
    path: '/manager/properties/:id',
    component: () => import('@/components/manager/PropertyDetail.vue'),
  },
  {
    path: '/manager/profile',
    component: () => import('@/pages/manager/ManagerProfile.vue'),
  },
  {
    path: '/manager/settings',
    component: () => import('@/pages/manager/ManagerSettingsPage.vue'),
  },
  {
    path: '/manager/profile/qr-scanner',
    component: () => import('@/components/manager/QRScanner.vue'),
  },
  {
    path: '/manager/chat',
    component: () => import('@/pages/manager/ManagerChatPage.vue'),
  },
  {
    path: '/manager/tenant/:tenantId',
    component: () => import('@/components/manager/TenantProfile.vue'),
  },
  {
    path: '/manager/notifications',
    component: () => import('@/pages/manager/ManagerNotifications.vue'),
  },
  {
    path: '/manager/messages',
    component: () => import('@/pages/manager/ManagerMessagesPage.vue'),
  },
];

export default managerRoutes;
