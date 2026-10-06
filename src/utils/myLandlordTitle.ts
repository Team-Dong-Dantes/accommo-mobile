import { ref } from 'vue'
import { supabase, authUser } from '@/utils/supabase'
import { landlordTitle } from '@/utils/format'

// The signed-in student's own landlord/landlady, titled by their sex, in lower
// case for running text ("your landlady"). Screens that talk about "your
// landlord/landlady" without loading the stay themselves read it from here.
// The neutral compound until it loads, or when there is no current stay.
const title = ref(landlordTitle(null).toLowerCase())

async function refresh() {
  const { data: auth } = await authUser()
  const uid = auth?.user?.id
  if (!uid) return
  const { data } = await supabase
    .from('leases')
    .select('landlord:users!leases_landlord_id_fkey(sex)')
    .eq('student_id', uid)
    .in('status', ['active', 'pending', 'leave_requested'])
    .maybeSingle()
  title.value = landlordTitle((data?.landlord as { sex: string | null } | null)?.sex).toLowerCase()
}

export function useMyLandlordTitle() {
  void refresh()
  return title
}
