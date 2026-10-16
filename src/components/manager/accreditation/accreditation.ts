// AccreditationCard's state, shared with its status box. Each card provides
// its own.
import { inject, provide, type InjectionKey } from 'vue'
import { createAccreditation } from './state'
import type { Seed } from './model'

function createAll(seed: Seed) {
  const state = createAccreditation({ ...seed })
  return { ...seed, ...state }
}

const KEY: InjectionKey<ReturnType<typeof createAll>> = Symbol('Accreditation')

export function provideAccreditation(seed: Seed) {
  const state = createAll(seed)
  provide(KEY, state)
  return state
}

export function useAccreditation() {
  const state = inject(KEY)
  if (!state) throw new Error('useAccreditation() outside its page')
  return state
}
