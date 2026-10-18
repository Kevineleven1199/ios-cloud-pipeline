# ios-cloud-pipeline

Headless, cloud-based iOS development & deployment. Code is pushed to this
repo; GitHub-hosted **macOS runners** compile it with Apple's real Xcode
toolchain; **Fastlane** ships it. No local Mac, no manual Xcode steps.

## What's in here

| Piece | File |
|---|---|
| Demo SwiftUI app (iOS 17+) | `PipelineDemo/` + `PipelineDemo.xcodeproj` |
| Pipeline proof workflow (unsigned build) | `.github/workflows/build.yml` |
| TestFlight workflow (signed, manual dispatch) | `.github/workflows/testflight.yml` |
| Fastlane lanes: `build_ci`, `beta`, `release` | `fastlane/Fastfile` |
| Bundle ID | `com.kevinflanagan.pipelinedemo` |

## Go Green Triage (the first real app on this pipeline)

`GoGreenTriage/` + `GoGreenTriage.xcodeproj` — the dead-simple approvals
triage app from the GoGreenOS office-manager build. Bundle ID
`com.kevinflanagan.gogreentriage`. Built by `.github/workflows/build-triage.yml`.

- **Queue screen:** every draft waiting on Kevin, oldest first, with category
  chips (Confirmation / Cleaner offer / Reminder / Customer text / Custom),
  gate badges (Ready / Blocked / Duplicate / Needs info), and wait times.
- **Decide fast:** swipe right to approve, swipe left to deny, or open the
  draft for the full message + context and use the big Approve/Deny bar.
  Approve/deny only — no editing, by design.
- **Gate semantics match the platform:** `Blocked` items (e.g. outside
  texting hours) can't be approved until the platform clears them;
  `Duplicate` / `Needs info` show their note and remain Kevin's call.
- **Data:** runs on clearly-labeled demo data (`MockApprovalService`)
  shaped exactly like the live approvals queue. `APIApprovalService` is the
  drop-in live client — wiring it needs Kevin's call on the app's
  send-release authority + auth design, since an approval in this app
  releases a real send.

## Pipeline states

- **build_ci — WORKS TODAY, no Apple account needed.** Every push to `main`
  compiles the app on a cloud Mac with signing disabled and verifies the
  `.app` bundle. This proves the full develop-in-the-cloud loop.
- **beta (TestFlight) — wired, waiting on signing secrets** (below).
- **release (App Store) — wired, upload-only.** The lane uploads the binary
  to App Store Connect; a human taps "Submit for Review". Nothing
  auto-submits to Apple review.

## To unlock TestFlight / App Store (one-time, account owner only)

1. **Enroll in the Apple Developer Program** ($99/yr) at
   developer.apple.com — requires the account holder + 2FA.
2. **Register the bundle ID** `com.kevinflanagan.pipelinedemo` in the
   Developer portal and **create the app** in App Store Connect.
3. **Create an App Store Connect API key** (Users and Access → Integrations →
   API Keys, role: App Manager). Add repo secrets:
   - `ASC_KEY_ID` — the key's ID
   - `ASC_ISSUER_ID` — the issuer ID shown on the same page
   - `ASC_KEY_CONTENT` — base64 of the downloaded `.p8` file
     (`base64 -i AuthKey_XXXX.p8`)
4. **Create the signing store once** from any Mac signed into the account:
   ```
   bundle install
   bundle exec fastlane match appstore
   ```
   This creates a private certs repo + the distribution certificate and
   provisioning profile, encrypted with a passphrase you choose. Then add
   repo secrets:
   - `MATCH_GIT_URL` — the certs repo URL
   - `MATCH_PASSWORD` — the passphrase from step 4
   - `MATCH_GIT_BASIC_AUTHORIZATION` — base64 of `username:github-token`
     with read access to the certs repo
5. **Run it:** Actions tab → "TestFlight (signed)" → Run workflow — or ask
   Muse to dispatch it via the API.

After step 4, every future build is fully hands-off: push code (or dispatch
the workflow) and the signed app lands in TestFlight.

## Notes

- Repo is currently **public** so GitHub Actions runners will start. On this
  account, private-repo jobs currently get no runner (GitHub's Actions
  billing/spending-limit state — see Settings → Billing & plans). Once that's
  in good standing, private builds work identically; macOS minutes bill at
  10x on private repos, and a build here takes ~2–5 min.
- Set secrets under Settings → Secrets and variables → Actions. Never commit
  keys, certificates, or the `.p8` file.
