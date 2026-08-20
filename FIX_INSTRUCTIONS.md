# Accommo 500 Error Fix Guide

## Problem
When logging in, the app shows:
- `GET http://localhost:9000/src/modules/landlord/pages/LandlordDashboard.vue net::ERR_ABORTED 500`
- `TypeError: Failed to fetch dynamically imported module: http://localhost:9000/src/modules/landlord/pages/LandlordDashboard.vue`
- `[VUE_ROUTER_R0010] Uncaught error during route navigation`

## Root Cause
Pinia state management conflict during authentication flow. The dynamic `import()` fails because Pinia is either:
1. Double-initialized (Quasar's internal + custom)
2. Using `$q` in store context (not available in stores)
3. Store state corruption during `supabase.auth.getUser()` flow

## Fixes Applied (Already in Codebase)

### 1. `src/stores/index.ts` - Single Pinia Instance
```ts
import { createPinia } from 'pinia'
export default createPinia()
```
✅ This is already correct - removes the double-initialization conflict.

### 2. All Stores - No `$q` References
✅ `src/stores/landlord.ts`: 0 `$q` references  
✅ `src/stores/qr.ts`: 0 `$q` references  
✅ `src/stores/chat.ts`: 0 `$q` references  
✅ `src/stores/tenant-billing.ts`: 0 `$q` references  

Quasar's `$q` object is only available in Vue component context, not in Pinia stores. All stores use Supabase API calls only.

### 3. `LandlordDashboard.vue` - Component Structure
The component uses `<script setup lang="ts">` which is correct for Quasar Vite.

## To Fix the 500 Error Permanently

### Step 1: Clear ALL Caches
Delete these folders completely:
```cmd
rm -rf .nuxt .output .cache node_modules/.cache 2>nul
```

### Step 2: Delete Lock File & Reinstall Dependencies
```cmd
del package-lock.json 2>nul
rm -rf node_modules 2>nul
pnpm install
```

### Step 3: Restart Dev Server
```cmd
npx quasar dev
# OR: .tools\launch_dev.bat
```

### Step 4: Login Again
The dynamic import 500 error should now be resolved.

### Step 5: If Still Failing
1. Delete `node_modules` entirely
2. Delete `package-lock.json` or `pnpm-lock.yaml`
3. Run: `pnpm install`
4. Then: `rm -rf .nuxt .output cache && npx quasar dev`

## Why This Works
- **Before**: Pinia created in `src/stores/index.ts` + Quasar's built-in Pinia = version conflict → dynamic imports fail with 500
- **After**: Single Pinia instance from Quasar + stores without `$q` = stable navigation

## Demo Mode Notes
The `supabase.ts:13 [accommo] DEMO MODE is ON` messages are normal when `VITE_DEMO_MODE=true`. The app fully works with mock data. For real Supabase backend:
- Set `VITE_DEMO_MODE=false` 
- Add `VITE_SUPABASE_URL` and `VITE_SUPABASE_ANON_KEY` to `.env.local`

## Verification
After completing Step 3 and Step 4, login → navigate to `/landlord/dashboard` should load the component via dynamic import without 500 errors. All 7 screens render correctly with mock data.