# Releasing Labbiah to Google Play

Package name: **`com.labbiah.app`** (permanent). Flutter is pinned to **3.44.4** in CI.

## How releases flow

| Trigger | Workflow | Result |
|---|---|---|
| Pull request | `ci.yml` | format, analyze, test, debug build — must pass to merge |
| Push to `main` | `release.yml` | signed AAB → **internal** testing track |
| Tag `vX.Y.Z` | `release.yml` | signed AAB → **alpha** (closed testing) + GitHub Release with symbols |
| Manual run | `promote.yml` | alpha/internal → **production**, staged rollout, needs approval |

- **versionName**: from the tag (`v1.2.0` → `1.2.0`), otherwise from `pubspec.yaml`.
- **versionCode**: `1000 + run_number × 10 + run_attempt` — always increasing, no manual bumps.
- **Release notes**: edit `distribution/whatsnew/whatsnew-en-US` and `whatsnew-ar` (max 500 chars) before tagging.

To ship: merge to `main` → check internal testers → bump `version:` in `pubspec.yaml`, tag `git tag v1.0.1 && git push --tags` → check closed testers → run **Promote to production** (start at `0.1`, re-run with higher fractions, finish at `1.0`).

## Signing

- **Upload key** (ours): `~/labbiah-signing/upload-keystore.jks`, alias `upload`, passwords in `~/labbiah-signing/key.properties`.
  **Back up both files to a password manager now.** If lost, Play support can reset the upload key, but it takes days.
- **App signing key**: held by Google via Play App Signing (chosen on first upload).
- Local release builds read `android/key.properties` (git-ignored). Without it, release builds fall back to debug keys and Play will reject them. CI also refuses to upload a debug-signed bundle.

## One-time setup

### 1. Play Console
1. Create the app: name *Labbiah*, default language, App, Free.
2. Complete **App content**:
   - **Privacy policy URL**: required, because the app reads contacts and places calls.
   - **Data safety**: the app collects/shares **no data**. Contacts are read and written on device only, and emergency contacts are stored locally (shared_preferences). SOS hands SMS and calls off to the system apps through intents (no SMS permission).
   - **Accessibility API declaration**: *Labbiah Quick Switch*. The app is declared an accessibility tool (`isAccessibilityTool="true"`) for users who need a simplified phone. Explain: it only filters the Volume Up key to switch between Labbiah and the system launcher; it does not read screen content. Attach a short video showing the in-app disclosure dialog (long-press Home on the case) and enabling the service.
   - Target audience (not children), content rating, ads (none), government apps (no).
3. **Store listing**: icon 512×512, feature graphic 1024×500, at least 2 phone screenshots, short and full description (EN + AR).
4. **First upload by hand** (the API can't create the first release):
   ```bash
   flutter build appbundle --release --build-name=1.0.0 --build-number=1 \
     --obfuscate --split-debug-info=build/symbols
   ```
   Testing → Internal testing → Create release → accept **Play App Signing** → upload `build/app/outputs/bundle/release/app-release.aab`.
5. New personal developer accounts must run a **closed test with at least 12 testers for 14 days** before production access is granted. Plan for this.

### 2. Service account for CI
1. Google Cloud Console → create/choose a project → enable **Google Play Android Developer API**.
2. IAM → Service accounts → create `play-ci` → Keys → add JSON key → download.
3. Play Console → **Users and permissions** → invite the service-account email → app access for Labbiah with: *Release to testing tracks*, *Release to production*, *Manage testing tracks*, *View app information*.
   Permissions can take up to 24 h to start working.

### 3. GitHub
1. Create the repo and push.
2. `scripts/set-github-secrets.sh ~/labbiah-signing/key.properties ~/Downloads/play-ci.json`
3. Settings → Environments: create **`play-testing`** (no rules) and **`production`** (required reviewers).
4. Settings → Branches: protect `main`, require the **CI / checks** status and PRs.
5. After the app clears its first Play review, set the repo variable `PLAY_RELEASE_STATUS` to `completed`. Until then Play only accepts **draft** releases, which you roll out by hand in the Console.

## Secrets reference

| Name | Kind | Content |
|---|---|---|
| `ANDROID_KEYSTORE_BASE64` | secret | base64 of `upload-keystore.jks` |
| `ANDROID_KEYSTORE_PASSWORD` | secret | store password |
| `ANDROID_KEY_ALIAS` | secret | `upload` |
| `ANDROID_KEY_PASSWORD` | secret | key password |
| `PLAY_SERVICE_ACCOUNT_JSON` | secret | service-account JSON key |
| `PLAY_RELEASE_STATUS` | variable | `draft` → `completed` after first review |

## Crash symbolication

Dart code is obfuscated. To read a Play Console stack trace, grab `symbols-vX.Y.Z.tar.gz` from the GitHub Release (or the workflow artifact for internal builds) and run:
```bash
flutter symbolize -i stacktrace.txt -d symbols/app.android-arm64.symbols
```
The R8 `mapping.txt` is uploaded to Play automatically.
