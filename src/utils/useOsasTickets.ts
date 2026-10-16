// Support tickets raised with OSAS — the list, the open thread and the
// new-ticket form, as both OSAS pages (student and landlord/landlady) run them.
// The pages differ only in whose ticket it is, which `owner` supplies.

import { computed, onUnmounted, ref, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { supabase, authUser } from '@/utils/supabase'
import { closeOverlay } from '@/utils/closeOverlay'
import { chatFullscreen } from '@/utils/chatFullscreen'
import { errorMessage } from '@/utils/errors'
import { useNotify } from '@/utils/notify'
import { signRows } from '@/utils/upload'
import type { TablesInsert } from '@/types/database.gen'
import type { TicketDraft } from '@/components/shared/TicketCompose.vue'

export interface Ticket {
  id: string
  subject: string
  description: string
  category: string
  status: string
  reportedAt: string
  photoUrls: string[]
  ticketNo: number | null
}

export const TICKET_SELECT = 'id, ticket_no, subject, description, category, status, reported_at, photo_urls'

interface TicketRow {
  id: string
  ticket_no: number | null
  subject: string | null
  description: string | null
  category: string | null
  status: string
  reported_at: string
  photo_urls: string[] | null
}

/** Signs each row's screenshots for this viewer, then shapes it for the list. */
export async function toTickets(rows: TicketRow[] | null): Promise<Ticket[]> {
  await signRows('tickets', rows, 'photo_urls')
  return (rows ?? []).map((t) => ({
    id: t.id,
    subject: t.subject || 'Untitled',
    description: t.description || '',
    category: t.category || 'other',
    status: t.status,
    reportedAt: t.reported_at,
    photoUrls: t.photo_urls ?? [],
    ticketNo: t.ticket_no,
  }))
}

export function useOsasTickets(owner: (draft: TicketDraft, userId: string) => Partial<TablesInsert<'tickets'>>) {
  const route = useRoute()
  const router = useRouter()
  const notify = useNotify()
  const tickets = ref<Ticket[]>([])

  // ?t=<id> opens the ticket thread over this page, so the hardware/browser back
  // button closes it — the same arrangement MessagesPage uses for a conversation.
  const openTicket = computed(
    () => tickets.value.find((t) => t.id === route.query.t) ?? null,
  )
  function showTicket(t: Ticket) {
    void router.push({ path: route.path, query: { t: t.id } })
  }
  function closeTicket() {
    closeOverlay(router, 't')
  }

  // An open thread covers the screen, so the shell's nav and FAB step aside.
  watch(openTicket, (t) => { chatFullscreen.value = Boolean(t) }, { immediate: true })
  onUnmounted(() => { chatFullscreen.value = false })

  const newTicketOpen = ref(false)
  const submittingTicket = ref(false)

  function openNewTicket() {
    newTicketOpen.value = true
  }

  // TicketCompose owns the form, its validation and the screenshot upload; this
  // only does the insert.
  async function submitTicket(draft: TicketDraft) {
    if (submittingTicket.value) return
    submittingTicket.value = true
    try {
      const { data: authData } = await authUser()
      const user = authData?.user
      if (!user) throw new Error('Not logged in.')

      const { data: created, error: insertError } = await supabase
        .from('tickets')
        .insert({
          ...owner(draft, user.id),
          subject: draft.subject,
          description: draft.description || null,
          category: draft.category,
          status: 'open',
          priority: 'medium',
        })
        .select(TICKET_SELECT)
        .single()
      if (insertError) throw insertError

      tickets.value = [...(await toTickets([created])), ...tickets.value]

      newTicketOpen.value = false
      notify.success('Ticket submitted.')
    } catch (e) {
      notify.error(errorMessage(e, 'Could not submit your ticket.'))
    } finally {
      submittingTicket.value = false
    }
  }

  return { tickets, openTicket, showTicket, closeTicket, newTicketOpen, submittingTicket, openNewTicket, submitTicket }
}
