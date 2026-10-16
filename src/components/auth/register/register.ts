// RegisterPage's state, shared with the step groups it is split into. The page
// provides it; each group renders its own screens and reads the same form.
import { inject, provide, type InjectionKey } from 'vue';
import { createRegisterForm } from './form';
import { createRegisterGoogle } from './google';
import { createRegisterFlow } from './flow';

function createAll() {
  const form = createRegisterForm();
  const google = createRegisterGoogle({ ...form });
  const flow = createRegisterFlow({ ...form, ...google });
  return { ...form, ...google, ...flow };
}

const KEY: InjectionKey<ReturnType<typeof createAll>> = Symbol('Register');

export function provideRegister() {
  const state = createAll();
  provide(KEY, state);
  return state;
}

export function useRegister() {
  const state = inject(KEY);
  if (!state) throw new Error('useRegister() outside its page');
  return state;
}
