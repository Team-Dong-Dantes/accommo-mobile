export interface LandlordProfile {
  id: string
  name: string
  memberSince: string
  contactNumber: string
  email: string
  rating: number
  totalReviews: number
  propertiesActive: number
  occupancyRate: number
  osasCompliance: ComplianceItem[]
}

export interface ComplianceItem {
  documentName: string
  expiryDate: string
  status: 'Valid' | 'Expiring' | 'Missing'
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
  isLandlord: boolean
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
  status: 'Pending' | 'Paid'
  paymentMethod: string
}

export type PaymentStatus = 'Pending' | 'Paid' | 'Overdue'

export type TenantStatus = 'Current' | 'Moved Out' | 'Evicted'

export type ComplianceStatus = 'Valid' | 'Expiring' | 'Missing'

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