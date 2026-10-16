// What the panel is handed by its page.

/** What the component hands its state: its props and emit. */
export interface Seed {
  props: { version: number; query: string }
  emit: { (e: 'changed'): void; (e: 'count', n: number): void }
}
