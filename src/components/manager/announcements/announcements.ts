// ManagerAnnouncePage's state, shared with the open announcement and the
// filters. The page provides it.
import { inject, provide, type InjectionKey } from 'vue'
import { createAnnouncements } from './state'

function createAll() {
  const state = createAnnouncements()
  return { ...state }
}

const KEY: InjectionKey<ReturnType<typeof createAll>> = Symbol('Announcements')

export function provideAnnouncements() {
  const state = createAll()
  provide(KEY, state)
  return state
}

export function useAnnouncements() {
  const state = inject(KEY)
  if (!state) throw new Error('useAnnouncements() outside its page')
  return state
}
