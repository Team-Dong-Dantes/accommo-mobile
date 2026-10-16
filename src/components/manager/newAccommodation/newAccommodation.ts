// The new-accommodation wizard's state, shared with the step groups it is split
// into. The page provides it; each group renders its own steps.
import { inject, provide, type InjectionKey } from 'vue'
import { createWizard } from './wizard'

function createAll() {
  const wizard = createWizard()
  return { ...wizard }
}

const KEY: InjectionKey<ReturnType<typeof createAll>> = Symbol('NewAccommodation')

export function provideNewAccommodation() {
  const state = createAll()
  provide(KEY, state)
  return state
}

export function useNewAccommodation() {
  const state = inject(KEY)
  if (!state) throw new Error('useNewAccommodation() outside its page')
  return state
}
