/**
 * The one row shape both dashboards use for "something you may have to act on".
 * The student screen feeds it from rent, messages and OSAS; the manager screen
 * from concerns, applications, leave requests and permit expiry. Same card,
 * same list, same ranking — so the type lives here rather than in either.
 */

export interface Task {
  id: string
  icon: string
  /** Short uppercase source label: 'Rent', 'OSAS', 'Application'… */
  kind: string
  label: string
  hint: string
  /** Relative time, or '' when the task isn't time-based. */
  when: string
  /** '' means there is nothing to do but wait. */
  action: string
  route: string
  tone: 'danger' | 'warn' | 'info' | 'done'
  /** Lower sorts first. Rank 0 is the most urgent thing on the screen. */
  rank: number
}
