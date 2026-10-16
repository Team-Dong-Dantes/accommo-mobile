// CollectionsPanel's state, shared with the list under its tiles. Each panel
// provides its own.
import { inject, provide, type InjectionKey } from 'vue'
import { createCollections } from './state'
import type { Seed } from './model'

function createAll(seed: Seed) {
  const state = createCollections({ ...seed })
  return { ...seed, ...state }
}

const KEY: InjectionKey<ReturnType<typeof createAll>> = Symbol('Collections')

export function provideCollections(seed: Seed) {
  const state = createAll(seed)
  provide(KEY, state)
  return state
}

export function useCollections() {
  const state = inject(KEY)
  if (!state) throw new Error('useCollections() outside its page')
  return state
}
