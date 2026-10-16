// The two shells (manager and student): tabs, quick actions and sub-pages,
// plus the routes the chrome treats specially.
import { type ShellConfig } from '@/types/app-types'

// One shell, two configurations. The role is read from the path so the chrome
// renders correctly on first paint, with no async role lookup flicker.
export const SHELLS: Record<'manager' | 'student', ShellConfig> = {
  manager: {
    home: '/manager/dashboard',
    notifications: '/manager/notifications',
    tabs: [
      { name: 'home', route: '/manager/dashboard', icon: 'lucide:house', label: 'Home' },
      { name: 'properties', route: '/manager/properties', icon: 'lucide:building-2', label: 'Properties' },
      // Centre of the bar, raised (BottomNav). A tab, not a Menu entry, so it
      // is no longer in quickActions or secondaryPages either: a tab screen has
      // the nav under it and no back arrow.
      { name: 'tenants', route: '/manager/tenants', icon: 'lucide:users', label: 'My Boarders', match: ['/manager/tenant/'], featured: true },
      { name: 'messages', route: '/manager/messages', icon: 'lucide:message-circle', label: 'Messages' },
      { name: 'menu', route: '/manager/profile', icon: 'lucide:menu', label: 'Menu' },
    ],
    quickActions: [
      { icon: 'lucide:shield-check', label: 'OSAS', route: '/manager/osas' },
      { icon: 'lucide:triangle-alert', label: 'Concerns', route: '/manager/support' },
      { icon: 'lucide:megaphone', label: 'Announcements', route: '/manager/announcements' },
    ],
    secondaryPages: [
      { path: '/manager/profile', title: 'Profile', back: '/manager/dashboard', backLabel: 'dashboard' },
      { path: '/manager/settings', title: 'Settings', back: '/manager/profile', backLabel: 'profile' },
      { path: '/manager/profile/qr-scanner', title: 'QR scanner', back: '/manager/profile', backLabel: 'profile' },
      { path: '/manager/profile/history', title: 'History', back: '/manager/profile', backLabel: 'profile' },
      { path: '/manager/profile/complete', title: 'Complete profile', back: '/manager/profile', backLabel: 'profile' },
      { path: '/manager/settings/terms', title: 'Terms & Privacy', back: '/manager/settings', backLabel: 'settings' },
      { path: '/manager/notifications', title: 'Notifications', back: '/manager/dashboard', backLabel: 'dashboard' },
      { path: '/manager/announcements', title: 'Announcements', back: '/manager/dashboard', backLabel: 'dashboard' },
      { path: /^\/manager\/announcement\/[^/]+$/, title: 'Announcement', back: '/manager/notifications', backLabel: 'notifications' },
      { path: /^\/manager\/person\/[^/]+$/, title: 'Profile', back: '/manager/messages', backLabel: 'messages' },
      { path: '/manager/osas', title: 'OSAS', back: '/manager/dashboard', backLabel: 'dashboard' },
      { path: '/manager/support', title: 'Concerns', back: '/manager/dashboard', backLabel: 'dashboard' },
      { path: /^\/manager\/tenant\/[^/]+$/, title: 'Boarder', back: '/manager/tenants', backLabel: 'my boarders' },
      { path: '/manager/properties/new', title: 'New Accommodation', back: '/manager/properties', backLabel: 'properties' },
      { path: /^\/manager\/properties\/[^/]+$/, title: 'Accommodation Details', back: '/manager/properties', backLabel: 'properties' },
    ],
  },
  student: {
    home: '/student/home',
    notifications: '/student/notifications',
    tabs: [
      { name: 'home', route: '/student/home', icon: 'lucide:house', label: 'Home' },
      { name: 'discover', route: '/student/discover', icon: 'lucide:search', label: 'Discover' },
      // Centre of the bar, raised — see the manager's 'tenants' tab.
      { name: 'stay', route: '/student/stay', icon: 'lucide:bed-double', label: 'My Stay', featured: true },
      { name: 'messages', route: '/student/messages', icon: 'lucide:message-circle', label: 'Messages' },
      { name: 'menu', route: '/student/profile', icon: 'lucide:menu', label: 'Menu' },
    ],
    quickActions: [
      // Labelled by who answers, so a student picks the right one before opening it.
      { icon: 'lucide:shield-check', label: 'OSAS', route: '/student/support' },
      { icon: 'lucide:triangle-alert', label: 'Concerns', route: '/student/concerns' },
    ],
    secondaryPages: [
      { path: '/student/profile', title: 'Profile', back: '/student/home', backLabel: 'home' },
      { path: '/student/settings', title: 'Settings', back: '/student/profile', backLabel: 'profile' },
      { path: '/student/profile/qr', title: 'My QR', back: '/student/profile', backLabel: 'profile' },
      { path: '/student/profile/history', title: 'History', back: '/student/profile', backLabel: 'profile' },
      { path: '/student/profile/complete', title: 'Complete profile', back: '/student/profile', backLabel: 'profile' },
      { path: '/student/settings/terms', title: 'Terms & Privacy', back: '/student/settings', backLabel: 'settings' },
      { path: '/student/notifications', title: 'Notifications', back: '/student/home', backLabel: 'home' },
      { path: /^\/student\/announcement\/[^/]+$/, title: 'Announcement', back: '/student/notifications', backLabel: 'notifications' },
      { path: /^\/student\/person\/[^/]+$/, title: 'Profile', back: '/student/messages', backLabel: 'messages' },
      { path: '/student/support', title: 'OSAS', back: '/student/home', backLabel: 'home' },
      { path: '/student/concerns', title: 'Concerns', back: '/student/home', backLabel: 'home' },
      { path: '/student/payments', title: 'Payments', back: '/student/home', backLabel: 'home' },
      { path: /^\/student\/listing\/[^/]+$/, title: 'Listing', back: '/student/discover', backLabel: 'discover' },
      { path: '/student/properties', title: 'Properties', back: '/student/discover', backLabel: 'discover' },
      { path: /^\/student\/room\/[^/]+$/, title: 'Room', back: '/student/discover', backLabel: 'discover' },
      { path: /^\/student\/manager\/[^/]+$/, title: 'Landlord/Landlady', back: '/student/discover', backLabel: 'discover' },
    ],
  },
}

// Same idea for the quick-action menu, so both roles' Concerns entry carries
// the same kind of self-clearing signal.
export const CONCERNS_ROUTE: Record<'manager' | 'student', string> = {
  manager: '/manager/support',
  student: '/student/concerns',
}

// On desktop a detail shown inside a card has its way back right there — its
// list in the pane beside it (a listing beside Discover, an announcement beside
// Notifications), or a back button on the card itself (TenantProfile,
// AccommodationDetail) — so the header stays the plain one, not a back bar.
// Includes /manager/properties/new: the add-property form carries its own back
// button above its card. Both History pages carry theirs across the card's top.
export const OWN_BACK = /^\/(manager\/(tenant\/[^/]+|properties\/[^/]+)|(manager|student)\/profile\/history)$/
