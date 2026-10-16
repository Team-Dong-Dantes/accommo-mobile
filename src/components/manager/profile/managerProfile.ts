// ManagerProfilePage's state, shared with its details half. The page provides
// it (it is the component KeepAlive caches).
import { inject, provide, type InjectionKey } from 'vue'
import { createManagerProfile } from './state'

function createAll() {
  const state = createManagerProfile()
  return { ...state }
}

const KEY: InjectionKey<ReturnType<typeof createAll>> = Symbol('ManagerProfile')

export function provideManagerProfile() {
  const state = createAll()
  provide(KEY, state)
  return state
}

export function useManagerProfile() {
  const state = inject(KEY)
  if (!state) throw new Error('useManagerProfile() outside its page')
  return state
}
