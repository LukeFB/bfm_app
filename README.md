# bfm_app
Frontend for BFM financial assistance app

# Instructions
Follow 
https://www.geeksforgeeks.org/installation-guide/how-to-install-flutter-on-windows/
https://codelabs.developers.google.com/codelabs/flutter-codelab-first#0

Set device pin 

# To run
start pixel 5 VM on android studio
Run:
flutter clean,
flutter pub get,
flutter run -d emulator-5554.

# Mac for iphone 16e
open -a simulator 
flutter run -d "iphone 16e"

# Backend (BFM Staff API)
1. `cd backend`
2. Copy `env.example` to `.env` and set:
   - `DATABASE_URL` (e.g. `file:./dev.db`)
   - `JWT_SECRET`
   - `ADMIN_EMAIL` / `ADMIN_PASSWORD` (used by the seed script)
3. Install & build:
   - `npm install`
   - `DATABASE_URL="file:./dev.db" npm run prisma:migrate`
   - `npm run seed`
4. Run the API locally with `npm run dev` (defaults to `http://localhost:4000`).
5. Visit `http://localhost:4000/admin` for the secure staff console (login with the seeded admin credentials). Upload referrals (single or CSV), publish tips, and schedule events here.
6. The Flutter app expects the backend at `http://localhost:4000/api`. Override with `--dart-define=BFM_BACKEND_URL=<url>` when running Flutter if needed.

# Errors
If getting "Error initializing DevFS: DevFSException(Service disconnected, _createDevFS: (112) Service has disappeared, null)"
Stop VM
Run:
adb kill-server,
adb start-server.

Restart app


