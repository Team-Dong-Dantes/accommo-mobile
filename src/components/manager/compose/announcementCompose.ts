// AnnouncementCompose's state, shared with its sections. Each compose
// overlay provides its own.
import { inject, provide, type InjectionKey } from 'vue'
import { createAnnouncementCompose } from './state'
import type { Seed } from './model'

function createAll(seed: Seed) {
  const state = createAnnouncementCompose({ ...seed })
  return { ...seed, ...state }
}

const KEY: InjectionKey<ReturnType<typeof createAll>> = Symbol('AnnouncementCompose')

export function provideAnnouncementCompose(seed: Seed) {
  const state = createAll(seed)
  provide(KEY, state)
  return state
}

export function useAnnouncementCompose() {
  const state = inject(KEY)
  if (!state) throw new Error('useAnnouncementCompose() outside its page')
  return state
}
