// PaySheet's state, shared with its body. Each sheet provides its own.
import { inject, provide, type InjectionKey } from 'vue'
import { createPaySheet } from './state'
import type { Seed } from './model'

function createAll(seed: Seed) {
  const state = createPaySheet({ ...seed })
  return { ...seed, ...state }
}

const KEY: InjectionKey<ReturnType<typeof createAll>> = Symbol('PaySheet')

export function providePaySheet(seed: Seed) {
  const state = createAll(seed)
  provide(KEY, state)
  return state
}

export function usePaySheet() {
  const state = inject(KEY)
  if (!state) throw new Error('usePaySheet() outside its page')
  return state
}
