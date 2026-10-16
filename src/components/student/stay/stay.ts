// StudentStayPage's state, shared with the stay and payments panels and the
// sheets it is split into. The page provides it (it is the component KeepAlive
// caches) and the pieces read the same instance.
import { inject, provide, type InjectionKey } from 'vue'
import { createStayState } from './state'
import { createStayActions } from './actions'

function createAll() {
  const state = createStayState()
  const actions = createStayActions({ ...state })
  return { ...state, ...actions }
}

const KEY: InjectionKey<ReturnType<typeof createAll>> = Symbol('Stay')

export function provideStay() {
  const state = createAll()
  provide(KEY, state)
  return state
}

export function useStay() {
  const state = inject(KEY)
  if (!state) throw new Error('useStay() outside its page')
  return state
}
