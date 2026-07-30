import { defineStore } from '#q-app'
import { createPinia } from 'pinia'
import type { Router } from 'vue-router'

declare module 'pinia' {
  export interface PiniaCustomProperties {
    readonly router: Router
  }
}

export default defineStore((/* { ssrContext } */) => {
  const pinia = createPinia()
  return pinia
})
