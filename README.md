![version](https://img.shields.io/badge/version-15%2B-D74635)
![platform](https://img.shields.io/static/v1?label=platform&message=mac-intel%20|%20mac-arm%20|%20win-32%20|%20win-64&color=blue)
[![license](https://img.shields.io/github/license/miyako/4d-plugin-system-beep)](LICENSE)
![downloads](https://img.shields.io/github/downloads/miyako/4d-plugin-system-beep/total)

# 4d-plugin-system-beep

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
