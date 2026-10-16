// ApplicationCard's state, shared with its sheets. Each card provides its own.
import { inject, provide, type InjectionKey } from 'vue'
import { createApplicationState } from './state'
import { createApplicationRefresh } from './refresh'
import { createApplicationActions } from './actions'
import type { Seed } from './model'

function createAll(seed: Seed) {
  const state = createApplicationState({ ...seed })
  const refresh = createApplicationRefresh({ ...seed, ...state })
  const actions = createApplicationActions({ ...seed, ...state, ...refresh })
  return { ...seed, ...state, ...refresh, ...actions }
}

const KEY: InjectionKey<ReturnType<typeof createAll>> = Symbol('Application')

export function provideApplication(seed: Seed) {
  const state = createAll(seed)
  provide(KEY, state)
  return state
}

export function useApplication() {
  const state = inject(KEY)
  if (!state) throw new Error('useApplication() outside its page')
  return state
}
