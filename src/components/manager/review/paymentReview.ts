// PaymentReviewSheet's state, shared with its body. Each sheet provides its own.
import { inject, provide, type InjectionKey } from 'vue'
import { createPaymentReview } from './state'
import type { Seed } from './model'

function createAll(seed: Seed) {
  const state = createPaymentReview({ ...seed })
  return { ...seed, ...state }
}

const KEY: InjectionKey<ReturnType<typeof createAll>> = Symbol('PaymentReview')

export function providePaymentReview(seed: Seed) {
  const state = createAll(seed)
  provide(KEY, state)
  return state
}

export function usePaymentReview() {
  const state = inject(KEY)
  if (!state) throw new Error('usePaymentReview() outside its page')
  return state
}
