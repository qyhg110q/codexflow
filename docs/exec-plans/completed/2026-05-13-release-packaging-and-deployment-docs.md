# Status

Completed pending GitHub Release publish verification from the current environment.

# Goal

Prepare CodexFlow for a GitHub Release that end users can consume directly, with a clear deployment story for Windows host setup, LAN access, Tailscale access, Web assets, and Android APK distribution.

# Scope

- Define and implement a release packaging layout suitable for GitHub Releases.
- Build or refresh release artifacts where practical.
- Update README deployment and release instructions so users or AI agents can deploy without reverse engineering the repo.
- Decide whether APK should ship in the same release and document that decision.
- If repository tooling allows it, publish the release assets to GitHub Releases.

Out of scope:

- iOS signed release packaging.
- Linux/macOS packaged installers.
- Relay, auth, or device pairing features not already present in the product.

# Progress

- 2026-05-13: Confirmed the repo already has a Windows host startup script for end users, Android APK build tooling, existing Flutter Web build output, and a Git remote pointing at `qyhg110q/codexflow`.
- 2026-05-13: Confirmed `gh` CLI is not available on this machine, so GitHub Release publishing may need an alternate path or may be blocked.
- 2026-05-13: Added release packaging scripts, release publishing script, and dedicated Windows host bundle launcher templates under `scripts/release/windows/`.
- 2026-05-13: Reworked README so release-first deployment, LAN access, Tailscale access, and AI-assisted deployment prompts are documented in one place.
- 2026-05-13: Built release assets into `artifacts/release/v0.1.0/`.
- 2026-05-13: Validated the packaged Windows host bundle by launching from `artifacts/release/v0.1.0/codexflow-windows-host/` and confirming both local and Tailscale `/healthz`.

# Surprises & Discoveries

- Existing README mentions GitHub Releases and Web/APK outputs, but it does not yet provide a release-oriented deployment guide.
- Existing workspace has unrelated generated Flutter plugin files and untracked helper scripts; these should remain outside this task's commit unless directly needed.
- Tailscale Serve is already configured locally and currently maps `/` to Flutter Web and `/api` plus `/healthz` to the agent.
- `flutter build web` on this Windows environment is sensitive to symlink / Developer Mode when it tries to run `flutter pub get`, but `flutter build web --no-pub` succeeds after dependencies are already prepared.
- Release-bundle startup initially failed because `Get-Command codex` resolved to `codex.ps1`; the bundle launcher now prefers `codex.cmd` or `codex.exe`, which the Go agent can exec directly.

# Decision Log

- Release asset layout:
  - `codexflow-windows-host-v0.1.0.zip`
  - `codexflow-android-v0.1.0.apk`
  - `codexflow-web-v0.1.0.zip`
  - `SHA256SUMS.txt`
  - `release-notes.md`
- Android APK should ship in the same GitHub Release as the Windows host bundle because they are part of the same end-user product surface and GitHub Releases is well-suited to multi-asset distribution.
- Windows host release assets should not assume a source checkout or Go toolchain. The bundle includes a prebuilt agent, bundled Web files, and release-specific startup scripts.
- GitHub Release publication should use a dedicated script and prefer `GITHUB_TOKEN` / `GH_TOKEN`, with Git Credential Manager as fallback when available.

# Validation

- `go test ./internal/httpapi`
- `.\build_android_apk.ps1`
- `.\build_release_assets.ps1`
- `.\build_release_assets.ps1 -SkipApk -SkipWeb -SkipAgentBuild`
- Packaged bundle validation:
  - `artifacts/release/v0.1.0/codexflow-windows-host/start_codexflow.ps1`
  - `Invoke-WebRequest http://127.0.0.1:4318/healthz`
  - `Invoke-WebRequest https://laptop-g84e45ma.tailfa6379.ts.net/healthz`
- Asset checksums recorded in `artifacts/release/v0.1.0/SHA256SUMS.txt`

# Outcomes & Retrospective

- The repo now has a reproducible release packaging flow instead of ad hoc manual copying.
- README now explains the deployment story from the point of view of end users and AI deployers, not only source builders.
- Release asset generation was completed successfully in this environment.
- GitHub Release publishing still needs final confirmation against live repository credentials from this environment.
