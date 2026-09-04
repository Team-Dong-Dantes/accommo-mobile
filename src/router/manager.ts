import type { RouteRecordRaw } from 'vue-router'

const managerRoutes: RouteRecordRaw[] = [
  {
    path: '/manager/dashboard',
    component: () => import('@/pages/manager/ManagerDashboard.vue'),
  },
  {
    path: '/manager/tenants',
    component: () => import('@/pages/manager/ManagerTenantsPage.vue'),
  },
  {
    path: '/manager/tenant/:leaseId',
    component: () => import('@/components/manager/TenantProfile.vue'),
  },
  {
    path: '/manager/messages',
    component: () => import('@/pages/manager/ManagerMessagesPage.vue'),
  },
  {
    path: '/manager/profile',
    component: () => import('@/pages/manager/ManagerProfilePage.vue'),
  },
  {
    path: '/manager/notifications',
    component: () => import('@/pages/manager/ManagerNotificationsPage.vue'),
  },
  {
    path: '/manager/osas-compliance',
    component: () => import('@/pages/manager/ManagerOsasCompliancePage.vue'),
  },
  {
    path: '/manager/support',
    component: () => import('@/pages/manager/ManagerConcernsPage.vue'),
  },
  {
    path: '/manager/properties',
    component: () => import('@/pages/manager/ManagerAccommodationsPage.vue'),
  },
  {
    path: '/manager/properties/new',
    component: () => import('@/components/manager/NewAccommodation.vue'),
  },
  {
    path: '/manager/properties/:id',
    component: () => import('@/components/manager/AccommodationDetail.vue'),
  },
  {
    path: '/manager/payments',
    component: () => import('@/pages/manager/ManagerPaymentsPage.vue'),
  },
]

export default managerRoutes
