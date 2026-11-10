# Native ownership audit

## Provenance and complete tracked native inventory

Baseline: `9ca7e1be47cdb013ebcd4b2d929b64885714dfdc`.
Guidance: `miyako/skills`, immutable
`e6b492fcb81e5e1a7f7db723594b420e63bf6eb9`,
`4d-skills/skills/4dplugin/SKILL.md`, read through the GitHub contents API.
The host-boundary pattern is adapted from `miyako/4d-plugin-sleep-notification`
at `7e79e3a34a262e1a5e6bd3f42122ee953d8b805f`; its results are not reused.

| Surface | Membership and ownership finding |
|---|---|
| `4DPlugin-System-Beep.cpp/.h` | Both native projects compile the actual dispatcher. The sole command is `SYSTEM BEEP(&L)`, selector 1, reading a scalar long. macOS uses NSBeep/NSSound; Windows uses MessageBeep. No exported string or array parameter, callback, worker, or retained string state. |
| `4D Plugin API/4DPluginAPI.c`, `.h`, `.def`, `EntryPoints.h`, `Flags.h`, `PrivateTypes.h`, `PublicTypes.h` | Both projects compile this complete SDK implementation. Protected and unchanged. The C file says rev v14, headers v13: these are file comments, not a verified upstream release. Exact blobs below. |
| `Classes/ARRAY_TEXT.cpp/.h` | Tracked but not compiled by either native project. Owns a heap vector; default copy operations alias it. Parameter reads copy borrowed strings into C++ strings before any mutation. Successful array insertion transfers independent newly created strings and does not dispose them afterward. |
| `Classes/C_TEXT.cpp/.h` | Dormant. Owns a heap string, already noncopyable. Reads copy parameter text; writes/returns use the content setter, not the array transfer setter. UTF conversion lengths are UTF-16 units on the input side and bytes on the UTF-8 output side. |
| `Classes/C_BLOB.cpp/.h` | Dormant. C_BLOB owns a heap CBytes; default copies alias it. CBytes itself owns a value vector and is safely copyable. Hex/base64 helpers consume C_TEXT by pointer, without copying its owner. |
| `Classes/C_LONGINT.cpp/.h` | Dormant scalar value wrapper; copyable without an owning pointer. |
| `Classes/C_TYPES.h` | Dormant type aliases, vectors and platform includes; no owner. No other tracked wrapper implementations exist. In particular there is no CPicture, C_PICTURE, pointer wrapper, picture-path conversion or `createCopy` implementation in this repository. |
| `support/4DPlugin-JSON.cpp/.h` | Dormant shared helper. All setter overloads, property getters, existence check, wchar conversion and stringify reviewed, including picture/object/collection handoffs. Four string setter overloads overwrite allocated initial empty strings. The picture setter similarly loses its initial empty picture. Successful property snapshots require cleanup, including mismatches; the matching collection result must instead retain its handoff. |
| `include/json/{allocator,assertions,autolink,config,features,forwards,json,reader,value,version,writer}.h` | Vendor JSON declarations/inline value helpers; no PA string/variable ownership calls and no native compilation members. Not replaced or modified. |
| `a/libjsoncpp.a`, `lib/windows/jsoncpp.lib`, `lib/windows64/jsoncpp.lib` | Prebuilt vendor archives, not executed or rebuilt. Neither project lists a JSON compilation unit. |
| `manifest.json`, `constants.json`, `constants.xlf` | One scalar-long command and platform sound-name constants; no text-array declaration. Absence of exported text arrays was not used to exclude dormant helpers. |
| `System Beep.sln`, `.vcxproj`, `.vcxproj.filters`, Xcode project/workspace/scheme | Source membership is only dispatcher plus SDK on both platforms. Headers/filters do not make dormant helpers compilation members. Xcode includes a Deployment-only signing/archive/notarization phase. Scheme launch/profile/archive select Deployment. MSBuild writes into the tracked test plugin location. No project build was run. |
| `System Beep.zip`, `.dmg`, `test/Plugins/System Beep.bundle/**` | Historical prebuilt deliverables/resources, not executed, changed or used as source evidence. Test database/journal/preferences and user workspace state were not read or exercised. |

Baseline wrapper blobs (implementation / header):

| Wrapper | Git blob IDs |
|---|---|
| ARRAY_TEXT | `534855e0959020ce9a66cef08f8434799c174495` / `cf8a458fc8519b824c726a59d346c44d4c26e845` |
| C_TEXT | `45ea6432dff52b681a5c6a7cea58ad5fc15df66b` / `6967390757db569ffcd3cfea8696bf14045cc748` |
| C_BLOB | `27bea3172ce90e4da339991c9b318a71ea8609b2` / `d181534e5a2e9bd46de492a040c1538ed81bf45a` |
| C_LONGINT | `005b83a4aec2c1466b8b219cb27ab845eb58de91` / `71e24df633aed7155cba1ffddc07d6a1dfc12fa9` |
| C_TYPES | `972cf3f597a8c21881a8c9aa69bc1699455be373` |
| JSON helper | `b033e44997010e3f45e9fec993c95b333525bc8c` / `4221eba4ff57e49cf9892fcd4351848e9e4cb589` |

Protected SDK blobs, checked by the regression driver before compilation:

| File | Git blob |
|---|---|
| 4DPluginAPI.c | `62f745e91d81ef2c3c901c656ea8e175d3b173e8` |
| 4DPluginAPI.h | `528bf1d2552df08d6a8b1bc95011a9b72934ad5c` |
| 4DPluginAPI.def | `5bbdb82fb724b6f8e307feb01d9f158b802de89d` |
| EntryPoints.h | `da428d5f6ca23b0a30371c7288a01d29aa3c466a` |
| Flags.h | `7a5a35539f27430a3fd9cb711d6b789051316471` |
| PrivateTypes.h | `a3098cb662cdbc43ba574fdef72a059c4c6d1cd4` |
| PublicTypes.h | `9ae20b001bff9128f690fff3e6c3f873b6238333` |

## Source-derived contracts and correction

SDK lines 265-299 forward string creation, disposal and content replacement
to the engine. `PA_CreateVariable(eVK_Unistring)` (4030) creates an empty
string, while `PA_SetStringVariable` (4254-4259) shallow-overwrites its
descriptor without releasing the old one. The corresponding picture
initialization and setter have the same overwrite shape. Use Undefined
initialization before adopting an existing owner; retain the final clear.
Do not remove the adopted value's cleanup or dispose its alias separately.

`PA_GetObjectProperty` (637-650) explicitly says its successful return
must be cleared. Clear copied string snapshots after conversion and all
successful nonmatching property kinds. `ob_get_c` transfers a matching
collection owner to its caller, who must call `PA_DisposeCollection` when
finished; clearing that variable before the handoff would invalidate it.
Object/collection setters' existing handoff semantics remain unchanged.

Capture the SDK error immediately after property/command calls, before
kind normalization, adoption, or cleanup. `UnifyVarKind(0)` normalizes raw
type zero to Unistring, so zeroed failed results are not successful empty
strings. Failed unspecified values are neither read nor cleared.
Stringify first checks object-copy success, then captures command success
before clearing its independently owned synchronous argument. Every
successful command result, including unexpected picture/object/collection
results, still gets cleared through the existing cleanup paths.

The helpers have no error-output channel. Existing failure outputs are
preserved: false/zero/null or unchanged destination text, and `ob_get_a`
continues to report the prior existence result. This is a documented
legacy error-reporting gap, not a newly added success fallback or an
assertion that a failed read succeeded. No exceptions or worker error
channels are introduced.

`PA_SetStringInArray` (4933-4947) accepts only Unicode arrays with non-null
data, `0 <= index <= fNbElements`, and non-null descriptor pointer. It
disposes the old element and shallow-adopts the incoming allocation.
Rejected assignments leave the caller as owner. Index zero is valid.
`PA_GetStringInArray` (4738-4755) is a borrowed alias. Existing successful
ARRAY_TEXT transfers and independent parameter copies are left intact.

ARRAY_TEXT and C_BLOB get only deleted copy constructor/assignment
declarations, following the existing C_TEXT pattern. This does not change
their field layout. Four baseline sanitizer cases prove the default-copy
use-after-free; fixed traits prove it cannot be instantiated afterward.
There are no production copy call sites in the actual dispatcher: this
is latent wrapper hardening, not a claimed reachable crash.

## Reproducible isolated evidence

Run on macOS with the existing Apple toolchain:

```sh
python3 .github/tests/test_ownership.py -v
```

The driver compiles the complete unchanged SDK, every actual wrapper
implementation, actual JSON helper and actual dispatcher into an unsigned
temporary executable. No SDK fragments or replacement PA functions are
compiled. ASan and UBSan are enabled; only alignment instrumentation is
disabled because this SDK uses packed ABI structures. LeakSanitizer is
disabled on macOS; explicit allocation/owner maps require zero live
strings, pictures, handles, objects and collections after each subprocess.
Fixture owner creation/adoption/copy/release is tracked independently.

Before any compilation or dispatch, a force-included header substitutes
synthetic NSBeep/NSSound, URL/path and SDK drawing boundaries. Unexpected
platform methods and engine selectors terminate the harness. `nm -u`
then gates real sound/audio, URL, drawing, process, file, network and
other platform imports before execution. Foundation/CoreFoundation
in-memory string conversion is used; no audio access, files, settings,
host methods, system changes or private test data are exercised.

The final identical harness was run with its normal source root and with
`OWNERSHIP_SOURCE_ROOT` pointing to an immutable `git archive` of the
baseline's SDK, wrappers, helper and dispatcher. Local environment:
arm64 macOS, Apple clang 21.0.0 (`clang-2100.1.1.101`).

| Named leaf group | Cases | Baseline failed | Fixed failed |
|---|---:|---:|---:|
| Four string setters, ASCII/BMP/supplementary/empty, allocated/null empties; picture setter | 33 | 17 | 0 |
| Four property getters, six successful result kinds, allocated/null empties, additional empty-string results | 56 | 34 | 0 |
| Stringify successful returns and getter/command poisoned/raw-zero/handle-allocation/copy failures | 25 | 9 | 0 |
| Array ownership/copy/churn/replacement/shrink/clear/rejection; scalar conversion/parameter/return; value copies; SDK failure predicates; synthetic actual dispatcher; null controls | 20 | 0 | 0 |
| Five wrapper copy traits and four actual baseline copy constructor/assignment cases | 9 | 6 | 0 |
| **Total** | **143** | **66** | **0** |

Baseline: **77 passed, 66 failed**. Fixed: **143 passed**.
Named failures include `set-{narrow,wide,wchars,utf16}` allocated-empty
owner leaks; `set-picture` initial picture leak; `get-{a,b,n,c}` owning
snapshot leaks; `get-*`/`stringify` poisoned-result UBSan failures;
`get-a`/`stringify` raw-zero invalid reads; stringify handle failure and
failed object-copy adoption; ARRAY_TEXT/C_BLOB copy traits and all four
copy-operation ASan heap-use-after-frees. The 77 passing baseline cases
are controls, not evidence that the baseline is safe.

Fixtures assert exact UTF-16 units, independent owned buffers, terminator
boundaries and round-trip UTF-8 bytes for ASCII, U+65E5, U+1F600 (surrogate
pair), and empty text. Both allocated and null empty engine strings are
modeled. Array controls include valid element zero, rejection by type,
null data, negative/high index, and null descriptor, with caller cleanup
after rejection. Collection handoff is explicitly consumed after return.
The actual macOS dispatcher traverses every defined sound branch:
one synthetic beep and fourteen named synthetic plays, plus no-op values
and unknown selectors. No real sound function/class is imported.

Final harness SHA-256:

| File | SHA-256 |
|---|---|
| ownership_host.mm | `003aef7800237b0916fbe2720182457ec183bd618d56704c9db92a90ad235c4b` |
| ownership_platform.h | `32fd74bdd1f1c9fceaa4e891397586ef294b04a24077395c1a5a712c2fa2985c` |
| test_ownership.py | `b4a91a74fef818bef526dc5c40d8366f535626197d437b3adf8a74b54eac0733` |

Full immutable-baseline and fixed logs are retained in the audit session's
artifact directory, not in release artifacts.

## Automation and limits

All existing workflows and automation scripts were read before validation
or push: `bump-version.yml`, `release.yml`, `release.py`,
`source_version.py`, and `bump-hooks/pre-push`. Existing workflows are
manual-dispatch-only. The new ownership job runs only on relevant path
pushes to `main` or the exact audit branch
`miyako-system-beep-ownership`, with read-only contents permission and
`macos-latest`; no uploads, deployment, release, signing, packaging,
notarization, tags, manual dispatch or reruns. Projects, existing
workflows, manifests, SDK ABI files and prebuilt binaries are unchanged.

This is not a native 4D engine/ABI validation or a reproduction of a
Windows 4D crash. The complete actual macOS consumers compile; that does
not validate the Windows conditional branches or MessageBeep ABI.
Engine-owned string creation/content-setter and object snapshot behavior
are modeled at the unchanged SDK boundary, not measured inside 4D.

Deferred, not certified:

- ARRAY_TEXT does not independently recover allocation or resize errors.
  The exact SDK can update array count even when handle resize fails and
  can dispose shrinking elements before a failed resize. A safe
  preservation contract needs an SDK/engine decision; no speculative
  metadata repair or global SDK rewrite is included.
- CBytes output may dispose the previous destination handle before a
  failed new allocation; preserving previous output is separate from
  string transfer and needs a dedicated behavior change.
- String/key allocation and object-copy engine failures have incomplete
  existing reporting contracts. The new failed-result guards do not
  establish general OOM safety. The failure-predicate control checks the
  SDK's returned error/handle shape, not wrapper recovery.
- Picture data ownership and converter byte/unit fixes described in other
  plugins cannot be inferred here: the corresponding picture wrappers
  and call sites do not exist in this source baseline.
- No asynchronous callbacks exist in this target. Stringify's temporary
  duplicated object argument is synchronously consumed and independently
  cleared. No blanket scalar or callback cleanup removal is applied.
