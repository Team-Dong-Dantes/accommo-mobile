import type { RouteRecordRaw } from 'vue-router';

const osasRoutes: RouteRecordRaw[] = [
  {
    path: '/osas/complaints',
    component: () => import('@/modules/osas/pages/OSASComplaintsPage.vue'),
  },
];

export default osasRoutes;
