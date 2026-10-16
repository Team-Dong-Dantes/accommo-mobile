// An announcement as the compose form builds it.

export interface AnnouncementDraft {
  /** One notice per house: the same text, addressed to each set of tenants. */
  accommodationIds: string[]
  title: string
  summary: string
  body: string
  /** What the notice is about — shown as facts, not buried in the sentence. */
  eventAt: string
  eventEnd: string
  location: string
  /** When a reply or action is needed by. */
  deadlineAt: string
  imageUrl: string
  publishAt: string
  expiresAt: string
}

/** What the component hands its state: its props and emit. */
export interface Seed {
  props: { accommodations: { id: string; name: string }[]; submitting?: boolean | undefined }
  emit: { (e: 'close'): void; (e: 'submit', draft: AnnouncementDraft): void }
}
