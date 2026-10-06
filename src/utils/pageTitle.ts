import { ref } from 'vue'

// A sub-page whose header names one person (a landlord/landlady's page: "Landlady")
// sets this while it is open; MainLayout shows it instead of the route's title.
export const pageTitleOverride = ref<string | null>(null)
