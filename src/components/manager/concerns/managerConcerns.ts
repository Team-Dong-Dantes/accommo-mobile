// ManagerConcernsPage's state, shared with the open concern. The page
// provides it (it is the component KeepAlive caches).
import { inject, provide, type InjectionKey } from 'vue'
import { createManagerConcerns } from './state'

function createAll() {
  const state = createManagerConcerns()
  return { ...state }
}

const KEY: InjectionKey<ReturnType<typeof createAll>> = Symbol('ManagerConcerns')

export function provideManagerConcerns() {
  const state = createAll()
  provide(KEY, state)
  return state
}

export function useManagerConcerns() {
  const state = inject(KEY)
  if (!state) throw new Error('useManagerConcerns() outside its page')
  return state
}
