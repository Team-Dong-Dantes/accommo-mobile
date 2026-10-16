// StudentProfilePage's state, shared with its details half. The page provides
// it (it is the component KeepAlive caches).
import { inject, provide, type InjectionKey } from 'vue'
import { createStudentProfile } from './state'

function createAll() {
  const state = createStudentProfile()
  return { ...state }
}

const KEY: InjectionKey<ReturnType<typeof createAll>> = Symbol('StudentProfile')

export function provideStudentProfile() {
  const state = createAll()
  provide(KEY, state)
  return state
}

export function useStudentProfile() {
  const state = inject(KEY)
  if (!state) throw new Error('useStudentProfile() outside its page')
  return state
}
