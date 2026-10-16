// TenantProfile's state, shared with the overview, payments and sheets it is
// split into. The page provides it (it is the component KeepAlive caches, per
// lease) and the pieces read the same instance.
import { inject, provide, type InjectionKey } from 'vue'
import { createTenantState } from './state'
import { createTenantActions } from './actions'

function createAll() {
  const state = createTenantState()
  const actions = createTenantActions({ ...state })
  return { ...state, ...actions }
}

const KEY: InjectionKey<ReturnType<typeof createAll>> = Symbol('Tenant')

export function provideTenant() {
  const state = createAll()
  provide(KEY, state)
  return state
}

export function useTenant() {
  const state = inject(KEY)
  if (!state) throw new Error('useTenant() outside its page')
  return state
}
