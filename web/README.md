# Collect — Web app & marketing site

Next.js (App Router) + Supabase. One app serves the public marketing pages, auth,
and the authenticated dashboard where users manage their inventory, listings, and
import/export. Same Supabase project as the iOS app and Chrome extension.

## Local development

```bash
cd web
cp .env.example .env.local   # fill in (defaults point at the prod Supabase project)
npm install
npm run dev                  # http://localhost:3000
```

## Environment variables

| Var | Required | Notes |
| --- | --- | --- |
| `NEXT_PUBLIC_SUPABASE_URL` | ✅ | Supabase project URL |
| `NEXT_PUBLIC_SUPABASE_ANON_KEY` | ✅ | Publishable/anon key (RLS protects all data) |
| `NEXT_PUBLIC_IOS_APP_URL` | – | TestFlight/App Store link; blank → "coming soon" |
| `NEXT_PUBLIC_EXTENSION_STORE_URL` | – | Chrome Web Store link; blank → serves `/downloads/collect-extension.zip` |

`NEXT_PUBLIC_*` values are inlined at **build** time, so they must be set on the
Railway service before the build runs (Nixpacks exposes service vars to the build).

## Deploy on Railway

1. **New Project → Deploy from GitHub repo** (this repo).
2. In the service **Settings → Root Directory**, set `web`.
3. Add the environment variables above under **Variables**.
4. Railway auto-detects Next.js (Nixpacks): it runs `npm run build` then
   `npm run start` (which binds to `$PORT`). `railway.json` pins this.
5. Generate a public domain under **Settings → Networking**.

## Auth

Uses Supabase email/password — the same accounts as the app and extension. If you
have email confirmation enabled in Supabase, new signups must confirm before login.

## Data

All reads/writes go straight to Supabase with the user's session; Row Level
Security (`auth.uid() = user_id`) scopes everything to the signed-in user. Photos
come from the private `asset-photos` bucket via short-lived signed URLs.

## Extension bundle

`public/downloads/collect-extension.zip` is the Chrome extension, offered on the
`/download` page. Regenerate it after extension changes:

```bash
cd ..                # repo root
zip -r "web/public/downloads/collect-extension.zip" "Collect Extension" -x "*.DS_Store"
```
