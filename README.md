![version](https://img.shields.io/badge/version-15%2B-D74635)
![platform](https://img.shields.io/static/v1?label=platform&message=mac-intel%20|%20mac-arm%20|%20win-32%20|%20win-64&color=blue)
[![license](https://img.shields.io/github/license/miyako/4d-plugin-system-beep)](LICENSE)
![downloads](https://img.shields.io/github/downloads/miyako/4d-plugin-system-beep/total)

# 4d-plugin-system-beep

## Maintainer release workflow

Both workflows are manual. **Bump version** takes `patch`, `minor`, or `major`
on the explicitly selected branch. It checks out the dispatch's immutable
`github.sha`, requires a clean checkout and that exact remote branch tip, and
commits only source version metadata. Its mandatory executable pre-push guard
requires exactly one advertised update from the selected SHA to its single-parent
direct child, including a final check for branch advances, rewinds, deletion and
same-result races. Pushes are non-force and never follow tags. It creates no tag,
release, or Build dispatch. If the branch changes, dispatch again on its new tip.

Run **Build** separately on the desired source commit using the Actions branch/tag
selector; it has no inputs or default-branch restriction. Every checkout uses
`github.sha`. The strict source `X.Y.Z` determines `vX.Y.Z` and
`System Beep-X.Y.Z.zip` / `System Beep-X.Y.Z.dmg`. Build jobs across branches
share the constant `release-publication` concurrency group without cancellation.

Source authority is coordinated `MARKETING_VERSION` and
`CURRENT_PROJECT_VERSION`: six settings each (three target and three project
configurations), source `Info.plist`, and `English.lproj/InfoPlist.strings`.
Supported Xcode references are preserved; an absent `CFBundleVersion` stays absent.
The prior Bump header promised coordination, but its marketing-only implementation
left current settings at `1.0.1` and localization at `1.0.0`. These are repaired to
the existing marketing/plist authority **1.0.3**, not a new version. Rewrites
preserve copyright 2022, BOM, individual line endings (including CR-only), file
modes, and unrelated bytes. Prebuilt bundles/archives, dependencies, native
project settings other than versions, manifest/schema and 4D data/counters are
not version authorities and are not rewritten.

Build retains Windows x64 MSBuild (v143, Windows SDK 10.0), universal macOS
arm64/x86_64 Xcode configuration Default with deployment target 11.0, the
`test/Plugins` bundle layout, Windows artifact transfer/merge, signing and strict
verification, notarization of both archives and DMG stapling. Notarization must
explicitly return `Accepted`. The existing six signing/notary secret names are
unchanged. No native build, signing, notarization or 4D execution is performed
by the local Python tests.

Publication checks remote tags and authenticated, fully validated paginated
releases (including drafts) both before native work and after all native gates.
Authentication, 404, network, malformed-response and later-page errors stop
publication. It POSTs a **new** tag ref at exactly the selected SHA and verifies
it remotely, then separately POSTs a public, non-prerelease release with the
original empty notes and uploads only to that newly returned release ID.
No reuse, updates, deletes, clobbering, retries or rollback are performed.

**Partial-state recovery:** any failure retains the tag, release and assets
already created. Inspect the Actions log and remote state manually, including
drafts and the exact tag SHA. A rerun intentionally refuses any existing tag or
release, even at the same SHA. Do not delete or overwrite published state to make
a rerun pass; choose a fresh source version through Bump version, then run Build
separately after reviewing the retained partial release. Publication timeouts
can leave remote state even when no successful response was received.

Local validation (no production publication):

```sh
actionlint
python3 -B -m unittest discover -s .github/tests -v
```

The helpers and lifecycle coverage are adapted from committed proxy
`4dc9995e5523f86f4d6d4d111f89ad3f81d8fb87`, mapm
`739178b4b8629bb03fc716fd0872355c1b758666`, apple-speech-recognizer
`7b06cdc0657547234d67e7bb1a5756881cd2b353`, and mail-applescript
`6c8c10ecb82618b60acb3ff1ae6df3f2cf824a6f` (quoted duplicate localization
guard). JSMin `fb9087a70130bce570c1cf2c687e09ee931ae3e8`'s explicitly
independent build-version contract does not apply to this repository.

---

A single-command 4D plugin that plays a native system alert or notification sound. On Windows it calls the Win32 `MessageBeep` API; on macOS it calls `NSBeep()` for the generic system alert, or plays one of macOS's bundled named sound effects (Basso, Glass, Ping, etc.) via `NSSound`. The command has no return value — it's fire-and-forget.

| Command | Returns | Purpose |
|---|---|---|
| [`SYSTEM BEEP`](#system-beep) | (none) | Plays a system alert sound or a named sound effect |

**Platforms:** Windows, macOS

---

## Requirements & platform notes

- The command takes exactly one mandatory parameter — there's no optional/overloaded form.
- It has no return value; don't test or assign a result from it.
- Sound identifiers are split by platform: values `0`–`9` are the Windows alert icons plus the generic system beep; values `11`–`24` are macOS's named UI sound effects. Only `SYSTEM` (`9`) is meaningful on both platforms — every other constant only does something on the platform it belongs to.
- **Passing a value with no matching case on the current platform is a silent no-op** — nothing plays, and no 4D error is raised. This is the single most important thing to know before using this command in something like a validation-failure alert, where you might otherwise assume the sound always plays.
- The command is declared **not thread-safe** (`"threadSafe": false` in the plugin's manifest). Call it from your regular process, not from inside a worker/preemptive process — this is deliberate, because the macOS sound-effect path goes through AppKit (`NSSound`), which isn't guaranteed safe to call off the main thread.

---

## SYSTEM BEEP

### Syntax

```4d
SYSTEM BEEP ( soundType )
```

| Parameter | Type | Description |
|---|---|---|
| `soundType` | Longint | Which sound to play. Use one of the plugin's built-in constants — see the table below. |
| Result | — | This command has no return value. |

**Sound constants** (names as used in the plugin's own test method, values as declared in the plugin's source header):

| Constant | Value | Platform |
|---|---|---|
| `Beep SYSTEM` | 9 | Windows and macOS (generic default alert on either OS) |
| `Beep Windows OK` | 0 | Windows only |
| `Beep Windows ICONASTERISK` | 1 | Windows only |
| `Beep Windows ICONEXCLAMATION` | 2 | Windows only |
| `Beep Windows ICONERROR` | 3 | Windows only |
| `Beep Windows ICONHAND` | 4 | Windows only |
| `Beep Windows ICONINFORMATION` | 5 | Windows only |
| `Beep Windows ICONQUESTION` | 6 | Windows only |
| `Beep Windows ICONSTOP` | 7 | Windows only |
| `Beep Windows ICONWARNING` | 8 | Windows only |
| `Beep macOS Basso` | 11 | macOS only |
| `Beep macOS Blow` | 12 | macOS only |
| `Beep macOS Bottle` | 13 | macOS only |
| `Beep macOS Frog` | 14 | macOS only |
| `Beep macOS Funk` | 15 | macOS only |
| `Beep macOS Glass` | 16 | macOS only |
| `Beep macOS Hero` | 17 | macOS only |
| `Beep macOS Morsei` | 18 | macOS only |
| `Beep macOS Ping` | 19 | macOS only |
| `Beep macOS Pop` | 20 | macOS only |
| `Beep macOS Purr` | 21 | macOS only |
| `Beep macOS Sosumi` | 22 | macOS only |
| `Beep macOS Submarine` | 23 | macOS only |
| `Beep macOS Tink` | 24 | macOS only |

### Description

`soundType` is read unconditionally as a Longint — there's no default and no way to omit it.

**On Windows**, values `0`–`8` map directly to the standard `MessageBeep` alert icons (`MB_OK`, `MB_ICONASTERISK`, `MB_ICONHAND`, etc.), so what actually plays depends on the sound scheme configured in the user's Windows Sound settings for that alert type. `Beep SYSTEM` (`9`) is a special case: it triggers the documented "simple beep" tone rather than any of the named alert icons.

**On macOS**, `Beep SYSTEM` (`9`) plays the OS's current default alert sound via `NSBeep()`. Values `11`–`24` instead play one of macOS's bundled named sound effects by looking it up through `NSSound`'s system sound cache — these are the same sounds listed under **System Settings → Sound → Sound Effects**, so what a user hears for e.g. `Beep macOS Glass` is always the actual "Glass" system sound, not something the plugin generates itself.

There's no volume or duration control — the plugin only tells the OS which sound to play; timing and loudness follow the user's own system sound settings on both platforms.

### Example

From the plugin's own test method (`TEST.4dm`):

```4d
SYSTEM BEEP(Beep SYSTEM)

SYSTEM BEEP(Beep Windows ICONASTERISK)
SYSTEM BEEP(Beep Windows ICONERROR)
SYSTEM BEEP(Beep Windows ICONEXCLAMATION)
SYSTEM BEEP(Beep Windows ICONHAND)
SYSTEM BEEP(Beep Windows ICONINFORMATION)
SYSTEM BEEP(Beep Windows ICONQUESTION)
SYSTEM BEEP(Beep Windows ICONSTOP)
SYSTEM BEEP(Beep Windows ICONWARNING)
SYSTEM BEEP(Beep Windows OK)

SYSTEM BEEP(Beep macOS Basso)
SYSTEM BEEP(Beep macOS Blow)
SYSTEM BEEP(Beep macOS Bottle)
SYSTEM BEEP(Beep macOS Frog)
SYSTEM BEEP(Beep macOS Funk)
SYSTEM BEEP(Beep macOS Glass)
SYSTEM BEEP(Beep macOS Hero)
SYSTEM BEEP(Beep macOS Morsei)
SYSTEM BEEP(Beep macOS Ping)
SYSTEM BEEP(Beep macOS Pop)
SYSTEM BEEP(Beep macOS Purr)
SYSTEM BEEP(Beep macOS Sosumi)
SYSTEM BEEP(Beep macOS Submarine)
SYSTEM BEEP(Beep macOS Tink)
```

Playing a cross-platform alert on a validation failure — since `Beep SYSTEM` is the only constant that does something on both OSes, prefer it when you don't want to special-case the platform:

```4d
If ($vError)
	SYSTEM BEEP(Beep SYSTEM)
	ALERT("Please correct the highlighted fields before continuing.")
End if
```

Previewing every macOS sound effect in sequence (the constants are consecutive, `11` through `24`):

```4d
For ($i; 11; 24)
	SYSTEM BEEP($i)
End for
```

---

## Error handling & troubleshooting

- **Nothing happens and no 4D error is raised** if you pass a `soundType` that has no matching case on the current platform (e.g. a `Beep macOS …` constant while running on Windows, or a raw value like `10` that isn't defined on either OS). Always pick a constant valid for the platform you're targeting, or use `Beep SYSTEM` if you need one that works everywhere.
- **This command never returns anything and never raises a 4D error on its own**, even for an invalid `soundType` — don't wrap it in error-catching logic expecting it to signal failure; it can't.
- **Don't call it from a worker/preemptive process.** It's declared not thread-safe on purpose: the macOS sound-effect path uses AppKit, which isn't guaranteed callable off the main thread. Call it from your regular process.
- **What you hear depends on the user's OS sound configuration**, not the plugin. If a Windows alert icon seems to make no sound, check that user's Sound settings for that event — the plugin is correctly invoking `MessageBeep`, it's the mapped system sound that may be muted or unset.

---

## Quick reference

```4d
SYSTEM BEEP(Beep SYSTEM)              // generic default alert — works on both platforms
SYSTEM BEEP(Beep Windows ICONHAND)    // Windows only
SYSTEM BEEP(Beep macOS Glass)         // macOS only
```
