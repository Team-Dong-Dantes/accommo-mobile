// ManagerTenantsPage's state, shared with the boarder list and sheets it is
// split into. The page provides it (it is the component KeepAlive caches).
import { inject, provide, type InjectionKey } from 'vue'
import { createTenantsState } from './state'

function createAll() {
  const state = createTenantsState()
  return { ...state }
}

const KEY: InjectionKey<ReturnType<typeof createAll>> = Symbol('Tenants')

export function provideTenants() {
  const state = createAll()
  provide(KEY, state)
  return state
}

export function useTenants() {
  const state = inject(KEY)
  if (!state) throw new Error('useTenants() outside its page')
  return state
}
