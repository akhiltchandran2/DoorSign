# Phase 2a setup: Google sign-in

Code for slice 2a is committed. It will not run until the two setup steps
below are done. Until then the panel shows "Not configured for this build"
and no sign-in button, which is the intended behaviour, not a failure.

## 1. Google Cloud

### Blocked: project creation is restricted at QBurst

Creating the project from a normal work account fails with:

```
You do not have the required "resourcemanager.projects.create"
permission to create projects in this location.
```

This appears for both the qburst.com organization and "No organization", so
it is an account permission, not an organization setting. QBurst has Cloud
project creation locked down. Nobody on the team can work around this from
the console. An admin has to act.

The qburst.com organization is also not visible in the parent resource
picker, which means either it does not exist or the account cannot see it.
The admin request below covers both cases.

### What to ask the Cloud or Workspace admin

> We are building DoorSign, an internal macOS menubar app that sets a
> person's Google Chat status automatically from signals on their own Mac.
> It needs a Google Cloud project and an OAuth client.
>
> I cannot create the project myself:
> `resourcemanager.projects.create` is denied for my account, under the
> qburst.com organization and under "No organization".
>
> Three things, in order of preference:
>
> 1. Does QBurst have a Google Cloud organization for qburst.com? If so,
>    either grant me `roles/resourcemanager.projectCreator` on it, or create
>    a project named DoorSign under it and grant me Owner or Editor.
> 2. The OAuth consent screen must be set to **Internal**, so sign-in is
>    limited to qburst.com accounts. Internal also avoids Google's
>    verification review, which External would require for the scope below
>    and takes weeks.
> 3. We need the Google Chat API enabled, and the OAuth client allowlisted
>    for Workspace API access if third-party app access is restricted. The
>    scope is `chat.users.availability`, which only lets the app set the
>    signed-in person's own Chat status. It reads no messages and no spaces.

Why Internal matters, if they push back on it:

| | Internal, under the org | External, in Testing |
|---|---|---|
| Google verification | Not needed | Not needed |
| Who can sign in | Everyone at qburst.com | Only listed test users, max 100 |
| Consent warning | None | "Unverified app" |
| Refresh token life | Normal | **7 days for sensitive scopes** |

That last row rules External out for a real rollout. Everyone would have to
sign in again every week.

### Once the project exists

1. **Enable the Google Chat API.** Add the Google Calendar API too if you
   want it ready for slice 2c.
2. **Create an OAuth client** under APIs & Services > Credentials. Pick the
   Apple application type (the console may label it iOS, and group macOS
   with it; take the macOS option if offered separately). Bundle ID is
   `com.qburst.doorsign`.
3. **Copy both values** from the client: the client ID, and the reversed
   client ID used as the callback URL scheme.

### Optional while you wait: prove the sign-in plumbing

Slice 2a's real unknown is whether the Google consent window behaves in an
agent app that owns no window of its own. That question has nothing to do
with QBurst's Workspace, so it can be answered with a throwaway project on a
personal Google account, which has no such restriction.

Create a project there, set the consent screen to External in Testing, add
yourself as a test user, and create an OAuth client for
`com.qburst.doorsign`. Put those values in `Secrets.xcconfig`. Signing in
then exercises the exact code path: the window anchor, the browser handoff,
the keychain restore on relaunch.

This proves the plumbing only. Do not point it at anything work related, and
do not use it for slice 2b, because Chat availability is a Workspace feature.
When the real project lands, swap the two values in `Secrets.xcconfig`. No
code changes.

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

| # | Step | Done | Owner |
|---|---|---|---|
| 1 | Admin asked about the Cloud organization and project creation | | you |
| 2 | Project created, under the qburst.com org if one exists | | admin |
| 3 | Consent screen set to Internal | | admin |
| 4 | Chat API enabled | | either |
| 5 | OAuth client created for `com.qburst.doorsign` | | either |
| 6 | Client allowlisted for Workspace API access, if required | | admin |
| 7 | `Secrets.xcconfig` filled in | | you |
| 8 | GoogleSignIn package added to the target | | done |
| 9 | Builds, panel shows "Not signed in" | | you |
| 10 | Sign in works, email appears | | you |
| 11 | Quit and relaunch, still signed in | | you |
