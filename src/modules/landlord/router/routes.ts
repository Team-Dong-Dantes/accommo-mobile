import type { RouteRecordRaw } from 'vue-router';

const landlordRoutes: RouteRecordRaw[] = [
  {
    path: '/landlord/dashboard',
    component: () => import('@/modules/landlord/pages/LandlordDashboard.vue'),
  },
];

export default landlordRoutes;
