# Quasar App (accommo-web)

## Install the dependencies

```bash
pnpm install
# or: yarn/npm/bun install
```

### Start the app in development mode (HMR, error reporting, etc.)

```bash
quasar dev
```

### Build the app for production

```bash
quasar build
```

### Customize the configuration

See [Configuring quasar.config.js](https://v2.quasar.dev/quasar-cli-vite/quasar-config-file).

### Local demo mode (no backend required)

Preview every screen without a real Supabase project. Create a (gitignored) `.env.local` with:

```bash
VITE_DEMO_MODE=true
```

Demo auth accepts any email and password. Sign in with an email containing `student` to open the Student Hub; any other email opens the Landlord Dashboard.
