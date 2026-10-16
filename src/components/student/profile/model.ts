// What the student profile lists: documents and the current stay.

export interface DocRow {
  id: string
  label: string
  statusLabel: string
  tone: string
  icon: string
  when: string
}
export interface Stay {
  leaseId: string
  managerId: string
  accommodationName: string
  roomNumber: string | null
  status: 'active' | 'pending' | 'leave_requested'
}
