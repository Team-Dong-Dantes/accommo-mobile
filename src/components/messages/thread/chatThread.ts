// ChatThread's state, in three parts: the messages, composing and acting on
// them, and the live channel. ChatThread provides it; ChatComposer reads the same instance.
import { inject, provide, type InjectionKey } from 'vue'
import { createMessages } from './messages'
import { createCompose } from './compose'
import { createLive } from './live'
import type { Seed } from './model'

function createAll(seed: Seed) {
  const messages = createMessages({ ...seed })
  const compose = createCompose({ ...seed, ...messages })
  const live = createLive({ ...seed, ...messages, ...compose })
  return { ...messages, ...compose, ...live }
}

const KEY: InjectionKey<ReturnType<typeof createAll>> = Symbol('ChatThread')

export function provideChatThread(seed: Seed) {
  const state = createAll(seed)
  provide(KEY, state)
  return state
}

export function useChatThread() {
  const state = inject(KEY)
  if (!state) throw new Error('useChatThread() outside its page')
  return state
}
