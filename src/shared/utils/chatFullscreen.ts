// Shared "a chat is open in full-screen" flag. The app shells (student + manager)
// check this to hide the bottom navigation / quick-action FAB while a conversation
// is being viewed, so an open chat takes over the whole screen (like notifications).
import { ref } from 'vue'

export const chatFullscreen = ref(false)
