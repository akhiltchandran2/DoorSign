# Phase 2a setup: Google sign-in

Code for slice 2a is committed. It will not run until the two setup steps
below are done. Until then the panel shows "Not configured for this build"
and no sign-in button, which is the intended behaviour, not a failure.

## 1. Google Cloud, once per organization

Needs someone who can create a project inside QBurst's Workspace org.

1. **Create a Google Cloud project** inside the QBurst organization. It must
   be in the org, not a personal account, or step 2 cannot be set to Internal.
2. **OAuth consent screen: User Type = Internal.** This matters. Internal
   limits sign-in to qburst.com accounts and skips Google's verification
   review. External with a sensitive scope means weeks of review.
3. **Enable the Google Chat API.** Add the Google Calendar API too if you
   want it ready for slice 2c.
4. **Create an OAuth client** under APIs & Services > Credentials. Pick the
   Apple application type (the console may label it iOS, and group macOS with
   it; take the macOS option if offered separately). Bundle ID is
   `com.qburst.doorsign`, which is why we settled that first.
5. **Copy both values** from the client: the client ID, and the reversed
   client ID used as the callback URL scheme.

**Ask your Workspace admin early.** Admins can restrict which third-party
apps reach Workspace data. If QBurst has that locked down, the app is blocked
until the client is allowlisted, and that is measured in days, not minutes.

## 2. On your Mac, once per clone

**Secrets file.** From the repo root:

```bash
cp Secrets.xcconfig.example Secrets.xcconfig
```

Fill in both values. `Secrets.xcconfig` is gitignored, so it never leaves
your machine. The project already points at it, so nothing else to wire.

**Add the SDK.** In Xcode: File > Add Package Dependencies, enter

```
https://github.com/google/GoogleSignIn-iOS
```

Add the **GoogleSignIn** product to the DoorSign target. Do not add
GoogleSignInSwift; the panel draws its own row and does not use Google's
button. Commit the resulting project file changes, since everyone needs them.

Then build as usual.

## What slice 2a does

Signs in, shows the account email in the panel, signs out, and restores the
session on relaunch so nobody signs in twice. It asks only for basic profile
and email. The Chat and Calendar scopes are requested by the slices that
need them, so nobody grants access to something the app cannot yet use.

Nothing is published to Chat yet. That is slice 2b.

## Expected snags

**Sign-in window appears behind everything.** An agent app is never frontmost.
`GoogleAuth.signIn` calls `NSApp.activate(ignoringOtherApps:)` first, but if
the consent window still hides, tell me.

**Nothing happens on click.** GoogleSignIn needs a window to anchor to, and a
menubar app has none of its own. The code borrows the panel if it is open and
otherwise makes a small window for the purpose. This is the part of 2a most
likely to need a second pass, because it cannot be verified without running
it. If it misbehaves, the fallback is `ASWebAuthenticationSession` with an
explicit presentation anchor.

**"Not configured for this build" after filling in the secrets.** The Info.plist
keys resolve at build time, so a stale build keeps the old values. Clean and
rebuild.

## Checklist

| # | Step | Done |
|---|---|---|
| 1 | Cloud project created in the QBurst org | |
| 2 | Consent screen set to Internal | |
| 3 | Chat API enabled | |
| 4 | OAuth client created for `com.qburst.doorsign` | |
| 5 | Workspace admin has allowlisted the client, if required | |
| 6 | `Secrets.xcconfig` filled in | |
| 7 | GoogleSignIn package added to the target | |
| 8 | Builds, panel shows "Not signed in" | |
| 9 | Sign in works, email appears | |
| 10 | Quit and relaunch, still signed in | |
