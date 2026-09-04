<template>
  <q-page class="dash">
    <div v-if="loading" class="stack">
      <q-skeleton type="text" width="52%" height="26px" />
      <q-skeleton type="rect" height="146px" class="sk" />
      <q-skeleton type="rect" height="104px" class="sk" />
      <q-skeleton type="rect" height="66px" class="sk" />
    </div>

    <div v-else-if="error" class="stack">
      <q-card flat bordered class="card card--pad text-center">
        <IconifyIcon icon="lucide:cloud-off" width="24" class="text-grey-6" />
        <p class="err-title">Couldn't load your dashboard</p>
        <p class="err-sub">{{ error }}</p>
        <q-btn unelevated rounded no-caps dense color="primary" label="Try again" class="q-mt-sm q-px-md" @click="load" />
      </q-card>
    </div>

    <div v-else class="stack">
      <div class="greet">
        <span class="greet-time">{{ greeting }},</span>
        <span class="greet-name">{{ firstName }}</span>
      </div>

      <!-- Where you live -->
      <div class="stay" :class="{ 'stay--empty': !stay }">
        <div class="stay-top">
          <span class="stay-cap">{{ stay ? 'Your stay' : 'No stay yet' }}</span>
          <span v-if="stay" class="stay-tag">{{ statusLabel(stay.status) }}</span>
        </div>

        <template v-if="stay">
          <p class="stay-name">{{ stay.accommodationName }}</p>
          <p class="stay-room">{{ roomLabel }}</p>
          <div class="stay-foot">
            <span class="stay-rent">
              {{ formatPeso(stay.monthlyRent) }}<span class="stay-per">/mo</span>
            </span>
            <span class="stay-term">until {{ formatDate(stay.endDate) }}</span>
          </div>
        </template>

        <template v-else>
          <p class="stay-name">Find a place to stay</p>
          <p class="stay-room">Your room, rent and dates land here once a manager accepts you</p>
          <button type="button" class="stay-cta" @click="go('/student/discover')">
            Browse rooms
            <IconifyIcon icon="lucide:arrow-right" width="15" />
          </button>
        </template>
      </div>

      <!-- Broadcast from OSAS -->
      <button v-if="notice" type="button" class="notice" @click="go('/student/support')">
        <span class="notice-icon"><IconifyIcon icon="lucide:megaphone" width="16" /></span>
        <span class="notice-body">
          <span class="notice-title">{{ notice.title }}</span>
          <span class="notice-text">{{ notice.body }}</span>
        </span>
        <span class="notice-when">{{ notice.when }}</span>
      </button>

      <!-- Needs attention: one actionable lead, the rest kept quiet -->
      <section class="sec">
        <div class="sec-head">
          <h2 class="sec-title">Needs attention</h2>
        </div>

        <div v-if="lead" class="lead" :class="`lead--${lead.tone}`">
          <div class="lead-top">
            <span class="lead-icon"><IconifyIcon :icon="lead.icon" width="18" /></span>
            <span class="lead-kind">{{ lead.kind }}</span>
            <span v-if="lead.when" class="lead-when">{{ lead.when }}</span>
          </div>
          <p class="lead-label">{{ lead.label }}</p>
          <p class="lead-hint">{{ lead.hint }}</p>
          <button v-if="lead.action" type="button" class="lead-action" @click="go(lead.route)">
            {{ lead.action }}
            <IconifyIcon icon="lucide:arrow-right" width="15" />
          </button>
        </div>

        <div v-if="rest.length" class="minors">
          <button
            v-for="item in rest"
            :key="item.id"
            type="button"
            class="minor"
            @click="go(item.route)"
          >
            <span class="minor-dot" :class="`minor-dot--${item.tone}`" />
            <span class="minor-text">
              <span class="minor-label">{{ item.label }}</span>
              <span class="minor-hint">{{ item.hint }}</span>
            </span>
            <span v-if="item.when" class="minor-when">{{ item.when }}</span>
          </button>
        </div>

        <div v-if="!attention.length" class="clear">
          <span class="clear-icon"><IconifyIcon icon="lucide:check" width="17" /></span>
          <span class="clear-text">
            <span class="clear-label">Nothing needs you</span>
            <span class="clear-hint">Dues, replies and OSAS updates land here</span>
          </span>
        </div>
      </section>

      <!-- The people behind the stay -->
      <section v-if="manager || roommates.length" class="sec">
        <div v-if="manager" class="person">
          <span class="person-avatar">{{ manager.initials }}</span>
          <span class="person-body">
            <span class="person-name">{{ manager.name }}</span>
            <span class="person-role">
              Your manager<template v-if="manager.replyMinutes">
                · replies in ~{{ manager.replyMinutes }} min</template>
            </span>
          </span>
          <span class="person-actions">
            <button type="button" class="icon-btn" aria-label="Message manager" @click.stop="go('/student/messages')">
              <IconifyIcon icon="lucide:message-circle" width="17" />
            </button>
            <a v-if="manager.phone" class="icon-btn" :href="`tel:${manager.phone}`" aria-label="Call manager">
              <IconifyIcon icon="lucide:phone" width="16" />
            </a>
          </span>
        </div>

        <div v-if="roommates.length" class="mates">
          <span class="mates-stack" aria-hidden="true">
            <span v-for="m in roommates.slice(0, 4)" :key="m.id" class="mates-avatar">{{ m.initials }}</span>
            <span v-if="roommates.length > 4" class="mates-avatar mates-avatar--more">
              +{{ roommates.length - 4 }}
            </span>
          </span>
          <span class="mates-text">
            Sharing {{ stay?.roomNumber ? `Room ${stay.roomNumber}` : 'your room' }}
            with {{ roommates.length }} {{ roommates.length === 1 ? 'other' : 'others' }}
          </span>
        </div>
      </section>
    </div>
  </q-page>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { Icon as IconifyIcon } from '@iconify/vue'
import { supabase } from '@/utils/supabase'
import { formatPeso, formatDate, initialsOf } from '@/utils/format'

interface Stay {
  id: string
  status: string
  startDate: string
  endDate: string
  monthlyRent: number
  accommodationName: string
  roomNumber: string | null
  roomLabel: string | null
}

interface AttentionItem {
  id: string
  icon: string
  kind: string
  label: string
  hint: string
  when: string
  /** Empty when there is nothing for the student to do but wait. */
  action: string
  route: string
  tone: 'danger' | 'warn' | 'info'
  rank: number
}

interface Notice {
  title: string
  body: string
  when: string
}

interface Manager {
  name: string
  initials: string
  phone: string | null
  replyMinutes: number | null
}

interface Roommate {
  id: string
  initials: string
}

const MAX_MINOR = 3

const router = useRouter()

const loading = ref(true)
const error = ref('')
const firstName = ref('there')
const stay = ref<Stay | null>(null)
const attention = ref<AttentionItem[]>([])
const notice = ref<Notice | null>(null)
const manager = ref<Manager | null>(null)
const roommates = ref<Roommate[]>([])

const greeting = computed(() => {
  const h = new Date().getHours()
  return h < 12 ? 'Good morning' : h < 18 ? 'Good afternoon' : 'Good evening'
})

const lead = computed<AttentionItem | null>(() => attention.value[0] ?? null)
const rest = computed(() => attention.value.slice(1, 1 + MAX_MINOR))

const roomLabel = computed(() => {
  if (!stay.value) return ''
  const { roomNumber, roomLabel: label } = stay.value
  if (roomNumber && label) return `Room ${roomNumber} · ${label}`
  if (roomNumber) return `Room ${roomNumber}`
  return label || 'Room'
})

const STATUS_LABEL: Record<string, string> = {
  active: 'Active',
  pending: 'Pending',
  leave_requested: 'Leaving',
  ended: 'Ended',
  terminated: 'Ended',
}
function statusLabel(s: string) {
  return STATUS_LABEL[s] ?? s
}

function titleCase(raw: string | null | undefined) {
  if (!raw) return ''
  return raw.replace(/[_-]+/g, ' ').replace(/^\w/, (c) => c.toUpperCase())
}

function ago(iso: string | null | undefined) {
  if (!iso) return ''
  const then = new Date(iso).getTime()
  if (Number.isNaN(then)) return ''
  const days = Math.floor((Date.now() - then) / 86400000)
  if (days <= 0) return 'today'
  if (days === 1) return '1d'
  if (days < 30) return `${days}d`
  const months = Math.floor(days / 30)
  return months === 1 ? '1mo' : `${months}mo`
}

function go(path: string) {
  void router.push(path)
}

async function load() {
  loading.value = true
  error.value = ''
  try {
    const { data: auth } = await supabase.auth.getUser()
    const user = auth?.user
    if (!user) {
      void router.push('/login')
      return
    }

    const { data: profile } = await supabase
      .from('users')
      .select('full_name, status')
      .eq('id', user.id)
      .maybeSingle()
    firstName.value = String(profile?.full_name || 'there').split(' ')[0] || 'there'
    const verification = profile?.status || 'unverified'

    // A student holds at most one live lease, so one row is enough.
    const { data: leaseRow, error: leaseError } = await supabase
      .from('leases')
      .select(
        'id, status, start_date, end_date, monthly_rent, room_id, rooms(room_number, label, monthly_rent, accommodations(name, accommodation_manager_id))',
      )
      .eq('student_id', user.id)
      .in('status', ['active', 'pending', 'leave_requested'])
      .order('start_date', { ascending: false })
      .limit(1)
      .maybeSingle()
    if (leaseError) throw leaseError

    if (leaseRow) {
      const room = leaseRow.rooms as unknown as
        | {
            room_number: string | null
            label: string | null
            monthly_rent: number | null
            accommodations: { name: string; accommodation_manager_id: string } | null
          }
        | null
      stay.value = {
        id: leaseRow.id,
        status: leaseRow.status,
        startDate: leaseRow.start_date,
        endDate: leaseRow.end_date,
        monthlyRent: Number(leaseRow.monthly_rent ?? room?.monthly_rent ?? 0),
        accommodationName: room?.accommodations?.name || 'Your accommodation',
        roomNumber: room?.room_number ?? null,
        roomLabel: room?.label ?? null,
      }
    } else {
      stay.value = null
    }

    // Newest live broadcast aimed at students.
    const { data: noticeRows } = await supabase
      .from('announcements')
      .select('title, body, published_at, expires_at')
      .in('audience', ['all', 'students'])
      .eq('archived', false)
      .or(`expires_at.is.null,expires_at.gt.${new Date().toISOString()}`)
      .order('published_at', { ascending: false })
      .limit(1)

    const top = noticeRows?.[0]
    notice.value = top
      ? { title: top.title, body: top.body || '', when: ago(top.published_at) }
      : null

    if (leaseRow) {
      const room = leaseRow.rooms as unknown as {
        accommodations: { accommodation_manager_id: string } | null
      } | null
      const managerId = room?.accommodations?.accommodation_manager_id

      if (managerId) {
        const [{ data: mgr }, { data: mgrProfile }] = await Promise.all([
          supabase.from('users').select('full_name, initials, phone').eq('id', managerId).maybeSingle(),
          supabase
            .from('accommodation_manager_profiles')
            .select('avg_response_minutes')
            .eq('user_id', managerId)
            .maybeSingle(),
        ])
        if (mgr) {
          manager.value = {
            name: mgr.full_name,
            initials: mgr.initials || initialsOf(mgr.full_name),
            phone: mgr.phone || null,
            replyMinutes: mgrProfile?.avg_response_minutes ?? null,
          }
        }
      }

      // Everyone else currently housed in the same room.
      const { data: mateRows } = await supabase
        .from('leases')
        .select('student_id, users!leases_student_id_fkey(full_name, initials)')
        .eq('room_id', leaseRow.room_id)
        .eq('status', 'active')
        .neq('student_id', user.id)

      roommates.value = (mateRows || []).map((m) => {
        const person = m.users as unknown as { full_name: string; initials: string | null } | null
        return {
          id: m.student_id,
          initials: person?.initials || initialsOf(person?.full_name || '?'),
        }
      })
    }

    const items: AttentionItem[] = []

    // Verification: whether they must act depends on what they have already
    // submitted, so the pending documents decide the wording and the action.
    if (verification !== 'verified') {
      const { count: pendingDocs } = await supabase
        .from('verification_documents')
        .select('*', { count: 'exact', head: true })
        .eq('user_id', user.id)
        .eq('status', 'pending')

      if (verification === 'rejected' || verification === 'suspended') {
        items.push({
          id: 'verify-rejected',
          icon: 'lucide:file-x',
          kind: 'OSAS',
          label: verification === 'rejected' ? 'Your documents were rejected' : 'Your account is suspended',
          hint:
            verification === 'rejected'
              ? 'Upload clearer copies to get verified'
              : 'Contact OSAS to sort this out',
          when: '',
          action: verification === 'rejected' ? 'Re-upload documents' : 'Open OSAS',
          route: '/student/support',
          tone: 'danger',
          rank: 0,
        })
      } else if (pendingDocs && pendingDocs > 0) {
        items.push({
          id: 'verify-waiting',
          icon: 'lucide:hourglass',
          kind: 'OSAS',
          label: 'OSAS is reviewing your documents',
          hint: `${pendingDocs} ${pendingDocs === 1 ? 'document' : 'documents'} submitted — nothing to do but wait`,
          when: '',
          action: '',
          route: '/student/support',
          tone: 'info',
          rank: 2,
        })
      } else {
        items.push({
          id: 'verify-missing',
          icon: 'lucide:id-card',
          kind: 'OSAS',
          label: 'Finish your OSAS verification',
          hint: 'Managers can only accept verified students',
          when: '',
          action: 'Upload documents',
          route: '/student/support',
          tone: 'warn',
          rank: 0,
        })
      }
    }

    if (leaseRow?.status === 'pending') {
      items.push({
        id: `application-${leaseRow.id}`,
        icon: 'lucide:hourglass',
        kind: 'Application',
        label: 'Your application is under review',
        hint: `${stay.value?.accommodationName ?? 'The manager'} hasn't decided yet`,
        when: ago(leaseRow.start_date),
        action: '',
        route: '/student/stay',
        tone: 'info',
        rank: 1,
      })
    }

    if (leaseRow) {
      // Concerns the student filed against this stay, and any reply.
      const { data: concernRows } = await supabase
        .from('concerns')
        .select('id, category, status, reported_at, manager_response')
        .eq('lease_id', leaseRow.id)
        .neq('status', 'resolved')
        .order('reported_at', { ascending: false })
        .limit(4)

      for (const c of concernRows || []) {
        const answered = Boolean(c.manager_response)
        items.push({
          id: `concern-${c.id}`,
          icon: answered ? 'lucide:message-square-reply' : 'lucide:triangle-alert',
          kind: 'Your report',
          label: answered
            ? `Your manager replied about ${(titleCase(c.category) || 'your report').toLowerCase()}`
            : `${titleCase(c.category) || 'Concern'} still open`,
          hint: answered ? 'Read the reply and close it off' : 'Waiting on your manager',
          when: ago(c.reported_at),
          action: answered ? 'Read reply' : '',
          route: '/student/concerns',
          tone: answered ? 'warn' : 'info',
          rank: answered ? 0 : 3,
        })
      }

      // Unpaid rent, when payments are actually recorded.
      const { data: dueRows } = await supabase
        .from('payments')
        .select('id, amount, month, status')
        .eq('lease_id', leaseRow.id)
        .in('status', ['due', 'overdue'])
        .order('month', { ascending: true })
        .limit(1)

      const due = dueRows?.[0]
      if (due) {
        const overdue = due.status === 'overdue'
        items.push({
          id: `due-${due.id}`,
          icon: 'lucide:wallet-cards',
          kind: overdue ? 'Overdue' : 'Rent due',
          label: `${formatPeso(Number(due.amount || 0))} ${overdue ? 'overdue' : 'due'}`,
          hint: overdue ? 'Settle this to stay in good standing' : 'Pay before the month closes',
          when: '',
          action: 'Pay now',
          route: '/student/payments',
          tone: overdue ? 'danger' : 'warn',
          rank: overdue ? 0 : 1,
        })
      }
    }

    // Unread messages from the manager.
    const { data: convos } = await supabase
      .from('conversations')
      .select('user_a_id, user_b_id, unread_a, unread_b')
      .or(`user_a_id.eq.${user.id},user_b_id.eq.${user.id}`)
    const unread = (convos || []).reduce((n, c) => {
      const mine = c.user_a_id === user.id ? c.unread_a : c.unread_b
      return n + Number(mine || 0)
    }, 0)
    if (unread > 0) {
      items.push({
        id: 'unread',
        icon: 'lucide:message-circle',
        kind: 'Messages',
        label: `${unread} unread ${unread === 1 ? 'message' : 'messages'}`,
        hint: 'From your accommodation manager',
        when: '',
        action: 'Open messages',
        route: '/student/messages',
        tone: 'warn',
        rank: 1,
      })
    }

    attention.value = items.sort((a, b) => a.rank - b.rank)
  } catch (e) {
    error.value = e instanceof Error ? e.message : 'Something went wrong.'
  } finally {
    loading.value = false
  }
}

onMounted(load)
</script>

<style scoped>
.dash { background: var(--m-bg); }
.stack {
  display: flex;
  flex-direction: column;
  gap: 7px;
  padding: 5px var(--m-page-gutter) 16px;
}
.sk { border-radius: var(--m-radius); }

.card { border-radius: var(--m-radius); background: var(--m-surface); overflow: hidden; }
.card--pad { padding: 18px 14px; }
.err-title { margin: 8px 0 0; color: var(--m-ink); font-size: 14px; font-weight: 700; }
.err-sub { margin: 2px 0 0; color: var(--m-muted); font-size: 12px; }

.greet { display: flex; align-items: baseline; gap: 5px; padding: 0 2px; flex-wrap: wrap; }
.greet-time { color: var(--m-muted); font-size: 15px; font-weight: 500; }
.greet-name {
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 20px;
  font-weight: 700;
  letter-spacing: -0.02em;
}

/* Stay */
.stay {
  display: flex;
  flex-direction: column;
  padding: 12px 13px;
  border-radius: var(--m-radius);
  background: var(--m-primary);
  color: #fff;
}
.stay--empty { border: 1px dashed var(--m-border); background: var(--m-surface); color: var(--m-ink); }
.stay-top { display: flex; align-items: center; justify-content: space-between; gap: 8px; }
.stay-cap { font-size: 11px; font-weight: 700; letter-spacing: 0.05em; text-transform: uppercase; opacity: 0.9; }
.stay--empty .stay-cap { color: var(--m-muted); opacity: 1; }
.stay-tag { padding: 2px 9px; border-radius: 999px; background: rgba(255, 255, 255, 0.22); font-size: 10.5px; font-weight: 700; }
.stay-name {
  margin: 5px 0 0;
  font-family: var(--m-font-display);
  font-size: 19px;
  font-weight: 700;
  letter-spacing: -0.02em;
  line-height: 1.15;
}
.stay-room { margin: 2px 0 0; font-size: 12.5px; opacity: 0.88; }
.stay--empty .stay-room { color: var(--m-muted); opacity: 1; }
.stay-foot {
  display: flex;
  align-items: baseline;
  justify-content: space-between;
  gap: 10px;
  margin-top: 9px;
  padding-top: 8px;
  border-top: 1px solid rgba(255, 255, 255, 0.22);
}
.stay-rent { font-family: var(--m-font-display); font-size: 22px; font-weight: 700; letter-spacing: -0.02em; line-height: 1; }
.stay-per { font-size: 12px; font-weight: 600; opacity: 0.78; }
.stay-term { font-size: 12px; opacity: 0.88; }
.stay-cta {
  display: inline-flex;
  align-self: flex-start;
  align-items: center;
  gap: 6px;
  min-height: 40px;
  margin-top: 11px;
  padding: 0 15px;
  border: 0;
  border-radius: 999px;
  background: var(--m-primary);
  color: #fff;
  cursor: pointer;
  font: inherit;
  font-size: 13.5px;
  font-weight: 700;
  -webkit-tap-highlight-color: transparent;
}

/* Broadcast notice */
.notice {
  display: flex;
  width: 100%;
  align-items: flex-start;
  gap: 9px;
  padding: 9px 11px;
  border: 1px solid color-mix(in srgb, var(--m-info) 22%, var(--m-border));
  border-radius: var(--m-radius);
  background: var(--m-info-soft);
  cursor: pointer;
  font: inherit;
  text-align: left;
  -webkit-tap-highlight-color: transparent;
}
.notice-icon { display: grid; width: 26px; height: 26px; flex: 0 0 26px; place-items: center; border-radius: 999px; background: #fff; color: var(--m-info); }
.notice-body { display: flex; min-width: 0; flex: 1 1 auto; flex-direction: column; gap: 1px; }
.notice-title { color: var(--m-ink); font-size: 13px; font-weight: 700; line-height: 1.25; }
.notice-text {
  color: var(--m-text);
  font-size: 11.5px;
  line-height: 1.35;
  overflow: hidden;
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
}
.notice-when { flex: 0 0 auto; color: var(--m-muted); font-size: 11px; font-weight: 600; }

/* People */
.person {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 7px 11px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius);
  background: var(--m-surface);
}
.person-avatar {
  display: grid;
  width: 36px;
  height: 36px;
  flex: 0 0 36px;
  place-items: center;
  border-radius: 999px;
  background: var(--m-primary);
  color: #fff;
  font-size: 12.5px;
  font-weight: 800;
}
.person-body { display: flex; min-width: 0; flex: 1 1 auto; flex-direction: column; gap: 1px; }
.person-name { color: var(--m-ink); font-size: 14px; font-weight: 700; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.person-role { color: var(--m-muted); font-size: 11.5px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.person-actions { display: flex; flex: 0 0 auto; gap: 6px; }
.icon-btn {
  display: grid;
  width: 40px;
  height: 40px;
  place-items: center;
  border: 1px solid var(--m-border);
  border-radius: 999px;
  background: var(--m-surface);
  color: var(--m-primary-dark);
  cursor: pointer;
  text-decoration: none;
  -webkit-tap-highlight-color: transparent;
}

.mates { display: flex; align-items: center; gap: 10px; padding: 0 4px; }
.mates-stack { display: flex; flex: 0 0 auto; }
.mates-avatar {
  display: grid;
  width: 26px;
  height: 26px;
  place-items: center;
  margin-left: -7px;
  border: 2px solid var(--m-bg);
  border-radius: 999px;
  background: var(--m-primary-soft);
  color: var(--m-primary-dark);
  font-size: 9.5px;
  font-weight: 800;
}
.mates-avatar:first-child { margin-left: 0; }
.mates-avatar--more { background: var(--m-border); color: var(--m-text); }
.mates-text { color: var(--m-muted); font-size: 12px; font-weight: 600; }

/* Sections */
.sec { display: flex; flex-direction: column; gap: 5px; }
.sec-head { display: flex; align-items: baseline; justify-content: space-between; gap: 8px; padding: 0 2px; }
.sec-title { margin: 0; color: var(--m-ink); font-size: 12.5px; font-weight: 700; letter-spacing: 0.02em; text-transform: uppercase; }

/* Lead */
.lead {
  display: flex;
  flex-direction: column;
  gap: 1px;
  padding: 11px;
  border-radius: var(--m-radius);
  background: var(--m-surface);
  border: 1px solid var(--m-border);
}
.lead--danger { border-color: color-mix(in srgb, var(--m-danger) 22%, var(--m-border)); }
.lead--warn { border-color: color-mix(in srgb, var(--m-warning) 26%, var(--m-border)); }
.lead--info { border-color: color-mix(in srgb, var(--m-info) 22%, var(--m-border)); }
.lead-top { display: flex; align-items: center; gap: 7px; }
.lead-icon { display: grid; width: 25px; height: 25px; flex: 0 0 25px; place-items: center; border-radius: 999px; }
.lead--danger .lead-icon { background: var(--m-danger-soft); color: var(--m-danger); }
.lead--warn .lead-icon { background: var(--m-warning-soft); color: var(--m-warning); }
.lead--info .lead-icon { background: var(--m-info-soft); color: var(--m-info); }
.lead-kind { flex: 1 1 auto; font-size: 11px; font-weight: 700; letter-spacing: 0.05em; text-transform: uppercase; }
.lead--danger .lead-kind { color: var(--m-danger); }
.lead--warn .lead-kind { color: var(--m-warning); }
.lead--info .lead-kind { color: var(--m-info); }
.lead-when { flex: 0 0 auto; color: var(--m-muted); font-size: 11.5px; font-weight: 600; }
.lead-label {
  margin: 3px 0 0;
  color: var(--m-ink);
  font-family: var(--m-font-display);
  font-size: 15.5px;
  font-weight: 700;
  letter-spacing: -0.02em;
  line-height: 1.2;
  text-wrap: pretty;
}
.lead-hint { margin: 0; color: var(--m-muted); font-size: 11.5px; line-height: 1.3; text-wrap: pretty; }
.lead-action {
  display: inline-flex;
  align-self: flex-start;
  align-items: center;
  gap: 6px;
  min-height: 38px;
  margin-top: 7px;
  padding: 0 14px;
  border: 0;
  border-radius: 999px;
  background: var(--m-primary);
  color: #fff;
  cursor: pointer;
  font: inherit;
  font-size: 13.5px;
  font-weight: 700;
  -webkit-tap-highlight-color: transparent;
  transition: transform 0.12s ease;
}
.lead-action:active { transform: scale(0.97); }

/* Minors */
.minors { display: flex; flex-direction: column; gap: 3px; }
.minor {
  display: flex;
  width: 100%;
  min-height: 44px;
  align-items: center;
  gap: 9px;
  padding: 4px 11px;
  border: 0;
  border-radius: var(--m-radius-sm);
  background: var(--m-surface);
  cursor: pointer;
  font: inherit;
  text-align: left;
  -webkit-tap-highlight-color: transparent;
}
.minor-dot { width: 7px; height: 7px; flex: 0 0 7px; border-radius: 999px; }
.minor-dot--danger { background: var(--m-danger); }
.minor-dot--warn { background: var(--m-warning); }
.minor-dot--info { background: var(--m-info); }
.minor-text { display: flex; min-width: 0; flex: 1 1 auto; flex-direction: column; gap: 1px; }
.minor-label { color: var(--m-ink); font-size: 13px; font-weight: 600; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.minor-hint { color: var(--m-muted); font-size: 11.5px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.minor-when { flex: 0 0 auto; color: var(--m-muted); font-size: 11px; font-weight: 600; }

/* Clear */
.clear {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 10px 11px;
  border: 1px solid var(--m-border);
  border-radius: var(--m-radius);
  background: var(--m-surface);
}
.clear-icon { display: grid; width: 30px; height: 30px; flex: 0 0 30px; place-items: center; border-radius: 999px; background: var(--m-success-soft); color: var(--m-success); }
.clear-text { display: flex; min-width: 0; flex-direction: column; gap: 2px; }
.clear-label { color: var(--m-ink); font-size: 14px; font-weight: 700; }
.clear-hint { color: var(--m-muted); font-size: 12px; }

@media (prefers-reduced-motion: reduce) {
  .lead-action { transition: none; }
}
</style>
