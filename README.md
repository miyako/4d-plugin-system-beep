# 4d-plugin-system-beep
いろいろなビープ音を鳴らしたい

![version](https://img.shields.io/badge/version-15%2B-D74635)
![platform](https://img.shields.io/static/v1?label=platform&message=mac-intel%20|%20mac-arm%20|%20win-32%20|%20win-64&color=blue)
[![license](https://img.shields.io/github/license/miyako/4d-plugin-system-beep)](LICENSE)
![downloads](https://img.shields.io/github/downloads/miyako/4d-plugin-system-beep/total)

**注記**: v15-v17をサポートするため`manifest.json`は`Contents`に置かれています。

```4d
SYSTEM BEEP(Beep SYSTEM)
```

### Windows

```4d
SYSTEM BEEP(Beep Windows ICONASTERISK)
SYSTEM BEEP(Beep Windows ICONERROR)
SYSTEM BEEP(Beep Windows ICONEXCLAMATION)
SYSTEM BEEP(Beep Windows ICONHAND)
SYSTEM BEEP(Beep Windows ICONINFORMATION)
SYSTEM BEEP(Beep Windows ICONQUESTION)
SYSTEM BEEP(Beep Windows ICONSTOP)
SYSTEM BEEP(Beep Windows ICONWARNING)
SYSTEM BEEP(Beep Windows OK)
```

source: https://docs.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-messagebeep

* Windows 10
* 
|value|sound|
|:-:|:-:|
|OK|ポローン（BEEP）|
|ICONASTERISK|ポローン|
|ICONERROR|ピロロン|
|ICONEXCLAMATION|ポローン|
|ICONHAND|ピロロン|
|ICONINFORMATION|ピロロン|
|ICONQUESTION|無音|
|ICONSTOP|ピロロン|
|ICONWARNING|ポローン|
|OK|ポローン|

### macOS

```4d
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

c.f. https://developer.apple.com/documentation/appkit/nssound/1477318-soundnamed?language=objc
