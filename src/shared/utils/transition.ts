// Shared horizontal-transition direction for the auth flow.
// RoleSelectPage sets the direction before navigating to a register page;
// AuthLayout reads it (then resets) to pick the slide-left / slide-right
// transition so Student slides left and Landlord slides right.

import { ref } from 'vue';

export type TransitionDir = 'left' | 'right' | null;

export const transitionDir = ref<TransitionDir>(null);
