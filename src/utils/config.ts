export const EXTERNAL_URLS = {
  GOOGLE_ICON: 'https://www.gstatic.com/firebasejs/ui/2.0.0/images/auth/google.svg',
  ISU_BACKGROUND: 'https://isu.edu.ph/wp-content/uploads/2024/11/ISU-Aerial.jpg',
} as const;

// Bump alongside package.json's version — kept as a constant rather than a
// JSON import since resolveJsonModule isn't guaranteed in the generated
// Quasar tsconfig.
export const APP_VERSION = '0.0.1';
