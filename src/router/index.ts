import { defineRouter } from '#q-app';
import {
  createMemoryHistory,
  createRouter,
  createWebHashHistory,
  createWebHistory,
} from 'vue-router';
import routes from './routes';
import { supabase } from '@/utils/supabase';
import { useAuthStore } from '@/stores/auth';

export default defineRouter(() => {
  const createHistory = import.meta.env.QUASAR_SERVER
    ? createMemoryHistory
    : (import.meta.env.QUASAR_VUE_ROUTER_MODE === 'history' ? createWebHistory : createWebHashHistory);

  const Router = createRouter({
    scrollBehavior: () => ({ left: 0, top: 0 }),
    routes,
    history: createHistory(import.meta.env.QUASAR_VUE_ROUTER_BASE)
  });

  let roleFetchInProgress: Promise<string | null> | null = null;

  async function fetchUserRole(session: { user: { id: string } }): Promise<string | null> {
    const authStore = useAuthStore();
    if (authStore.cachedRole) return authStore.cachedRole;

    if (roleFetchInProgress) return roleFetchInProgress;

    roleFetchInProgress = (async () => {
      try {
        const { data, error } = await supabase
          .from('users')
          .select('role')
          .eq('id', session.user.id)
          .maybeSingle();

        if (error || !data) return null;

        authStore.cachedRole = data.role;
        return data.role;
      } catch {
        return null;
      } finally {
        roleFetchInProgress = null;
      }
    })();

    return roleFetchInProgress;
  }

  Router.beforeEach(async (to) => {
    const { data: { session } } = await supabase.auth.getSession();
    const isAuthenticated = !!session;

    const publicRoutes = ['/', '/login', '/register', '/register/landlord'];
    const isPublicRoute = publicRoutes.includes(to.path);

    if (!isAuthenticated && !isPublicRoute) {
      return '/login';
    }

    if (isAuthenticated) {
      if (to.path === '/register' || to.path === '/register/landlord') {
        await supabase.auth.signOut();
        return '/login?accountExists=true';
      }

      if (isPublicRoute) {
        const role = await fetchUserRole(session);
        if (role === 'student') return '/student/dashboard';
        if (role === 'landlord') return '/landlord/dashboard';
        if (role === 'admin') return '/admin/dashboard';
        if (role === null) {
          await supabase.auth.signOut();
          return '/register?newUser=true';
        }
        return '/';
      }
    }

    return true;
  });

  return Router;
});
