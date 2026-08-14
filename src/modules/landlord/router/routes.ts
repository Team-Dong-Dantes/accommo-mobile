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
];

export default landlordRoutes;
