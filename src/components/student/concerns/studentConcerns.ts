// StudentConcernsPage's state, shared with the open concern and the report
// form. The page provides it (it is the component KeepAlive caches).
import { inject, provide, type InjectionKey } from 'vue'
import { createStudentConcerns } from './state'

function createAll() {
  const state = createStudentConcerns()
  return { ...state }
}

const KEY: InjectionKey<ReturnType<typeof createAll>> = Symbol('StudentConcerns')

export function provideStudentConcerns() {
  const state = createAll()
  provide(KEY, state)
  return state
}

export function useStudentConcerns() {
  const state = inject(KEY)
  if (!state) throw new Error('useStudentConcerns() outside its page')
  return state
}
