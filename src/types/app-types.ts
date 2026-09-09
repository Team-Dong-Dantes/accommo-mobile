export interface ManagerProfile {
  id: string
  name: string
  memberSince: string
  contactNumber: string
  email: string
  rating: number
  totalReviews: number
  propertiesActive: number
  occupancyRate: number
}

export interface ScannedStudent {
  studentId: string
  name: string
  course: string
  yearLevel: string
  osasVerified: boolean
  currentBoarding: {
    propertyName: string
    unit: string
    monthlyRate: number
  }
  tenancyHistory: TenancyRecord[]
}

export interface TenancyRecord {
  propertyName: string
  address: string
  period: string
  status: 'Moved Out' | 'Evicted' | 'Current'
  remarks: string
}

export interface ChatMessage {
  id: string
  text: string
  senderId: string
  timestamp: string
  isManager: boolean
  status: 'sent' | 'delivered' | 'read'
}

export interface TenantBillingState {
  monthlyRent: number
  payStreak: number
  pendingAmount: number
  paymentHistory: PaymentRecord[]
}

export interface PaymentRecord {
  month: string
  dueDate: string
  amount: number
  status: 'Pending' | 'Paid' | 'Overdue'
  paymentMethod: string
}

export type PaymentStatus = 'Pending' | 'Paid' | 'Overdue'

export type TenantStatus = 'Current' | 'Moved Out' | 'Evicted'

export interface QRScanResult {
  studentId: string
  name: string
  course: string
  osasVerified: boolean
  propertyName: string
  unit: string
  monthlyRate: number
}

export interface MetricCardData {
  label: string
  value: string | number
  icon: string
  color: string
}

// --- App shell (MainLayout) ---

export interface BottomTab {
  /** Stable id used for active-tab matching. */
  name: string
  /** Destination when the tab is tapped. */
  route: string
  /** Iconify icon name. Ignored when `avatar` is true. */
  icon: string
  /** Accessible label. */
  label: string
  /** Render the user's avatar instead of an icon (profile tab). */
  avatar?: boolean
  /** Extra path prefixes that should light this tab up. */
  match?: readonly string[]
  /** Unread-style count shown as a small pill on the tab; hidden when falsy. */
  badge?: number
  /** Plain red dot (no count) flagging something on this tab needs checking. */
  dot?: boolean
}

export interface QuickAction {
  icon: string
  label: string
  route: string
  /** Render the user's avatar instead of an icon (the Profile row). */
  avatar?: boolean
  /** Plain red dot flagging something behind this action needs checking. */
  dot?: boolean
}

/** A page that replaces the wordmark header with a back button + title. */
export interface SecondaryPage {
  /** Exact path, or a regex for parameterised routes. */
  path: string | RegExp
  title: string
  /** Where the back button goes. */
  back: string
  /** Spoken destination for the back button's aria-label. */
  backLabel: string
}

export interface ShellConfig {
  home: string
  notifications: string
  tabs: readonly BottomTab[]
  quickActions: readonly QuickAction[]
  secondaryPages: readonly SecondaryPage[]
}
