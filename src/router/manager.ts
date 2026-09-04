import type { RouteRecordRaw } from 'vue-router';

const managerRoutes: RouteRecordRaw[] = [
  {
    path: '/manager/dashboard',
    component: () => import('@/pages/manager/ManagerDashboard.vue'),
  },
];

export default managerRoutes;
