"""Actual native sources, complete unchanged SDK, synthetic platform only."""

import hashlib
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
SOURCE = Path(os.environ.get("OWNERSHIP_SOURCE_ROOT", ROOT)).resolve()
SDK = {
    "4DPluginAPI.c": "62f745e91d81ef2c3c901c656ea8e175d3b173e8",
    "4DPluginAPI.h": "528bf1d2552df08d6a8b1bc95011a9b72934ad5c",
    "4DPluginAPI.def": "5bbdb82fb724b6f8e307feb01d9f158b802de89d",
    "EntryPoints.h": "da428d5f6ca23b0a30371c7288a01d29aa3c466a",
    "Flags.h": "7a5a35539f27430a3fd9cb711d6b789051316471",
    "PrivateTypes.h": "a3098cb662cdbc43ba574fdef72a059c4c6d1cd4",
    "PublicTypes.h": "9ae20b001bff9128f690fff3e6c3f873b6238333",
}


@unittest.skipUnless(sys.platform == "darwin", "macOS synthetic host")
class OwnershipTests(unittest.TestCase):
    runs = 0
    passes = 0

    @classmethod
    def setUpClass(cls):
        cls.temp = tempfile.TemporaryDirectory(prefix="system-beep-ownership-")
        cls.addClassCleanup(cls.temp.cleanup)
        cls.binary = Path(cls.temp.name) / "ownership"
        api = SOURCE / "4D Plugin API"
        for name, expected in SDK.items():
            contents = (api / name).read_bytes()
            blob = hashlib.sha1(f"blob {len(contents)}\0".encode() + contents).hexdigest()
            if blob != expected:
                raise AssertionError(f"Re-audit changed SDK: {name}: {blob}")
        result = subprocess.run([
            "clang++", "-std=c++14", "-x", "objective-c++",
            "-include", str(ROOT / ".github/tests/ownership_platform.h"),
            "-I", str(api), "-I", str(api / "Classes"), "-I", str(SOURCE),
            "-fsanitize=address,undefined", "-fno-sanitize=alignment",
            "-fno-omit-frame-pointer", "-g",
            "-Wno-deprecated-declarations", "-Wno-return-type-c-linkage",
            "-Wno-ignored-attributes", "-Wno-writable-strings",
            str(api / "4DPluginAPI.c"),
            *map(str, sorted((api / "Classes").glob("*.cpp"))),
            str(SOURCE / "support/4DPlugin-JSON.cpp"),
            str(SOURCE / "4DPlugin-System-Beep.cpp"),
            str(ROOT / ".github/tests/ownership_host.mm"),
            "-framework", "Cocoa", "-framework", "Carbon", "-o", str(cls.binary),
        ], capture_output=True, text=True)
        if result.returncode:
            raise AssertionError(result.stdout + result.stderr)
        imports = subprocess.check_output(["nm", "-u", str(cls.binary)], text=True)
        linked = {line.split()[-1] for line in imports.splitlines() if line.split()}
        denied = {
            "_NSBeep", "_OBJC_CLASS_$_NSSound", "_OBJC_CLASS_$_NSURL",
            "_OBJC_CLASS_$_NSWorkspace", "_OBJC_CLASS_$_NSFileManager",
            "_OBJC_CLASS_$_NSProcessInfo", "_OBJC_CLASS_$_NSAppleScript",
            "_CFURLCreateWithFileSystemPath", "_CFURLCopyFileSystemPath",
            "_system", "_popen", "_execve", "_posix_spawn", "_kill",
            "_open", "_fopen", "_socket", "_connect", "_getenv",
        } & linked
        denied |= {name for name in linked if name.startswith((
            "_Audio", "_AVAudio", "_CGContext", "_IOService", "_IOPM", "_IOPS",
        ))}
        if denied:
            raise AssertionError(f"Real platform boundary linked: {denied}")

    @classmethod
    def tearDownClass(cls):
        print(f"LEAF runs={cls.runs} passed={cls.passes} "
              f"failed={cls.runs - cls.passes}", file=sys.stderr)

    def case(self, name, text="ASCII", empty="allocated", kind="string"):
        type(self).runs += 1
        result = subprocess.run(
            [str(self.binary), name, text, empty, kind],
            env={**os.environ, "ASAN_OPTIONS": "detect_leaks=0",
                 "UBSAN_OPTIONS": "halt_on_error=1"},
            capture_output=True, text=True,
        )
        if result.returncode == 0:
            type(self).passes += 1
        self.assertEqual(result.returncode, 0, f"{name}/{text}/{empty}/{kind}: "
                         f"{result.stdout}{result.stderr}")
        self.assertIn("strings=0 pictures=0 handles=0 objects=0 collections=0", result.stdout)

    def test_setter_empty_owner_overwrite(self):
        for setter in ("set-narrow", "set-wide", "set-wchars", "set-utf16"):
            for text in ("ASCII", "\u65e5", "\U0001f600", ""):
                for empty in ("allocated", "null"):
                    with self.subTest(setter=setter, text=text, empty=empty):
                        self.case(setter, text, empty)
        self.case("set-picture")

    def test_getter_success_owners_and_mismatches(self):
        for getter in ("get-a", "get-b", "get-n", "get-c"):
            for kind in ("string", "picture", "object", "collection", "boolean", "real"):
                for empty in ("allocated", "null"):
                    with self.subTest(getter=getter, kind=kind, empty=empty):
                        self.case(getter, "\u65e5\U0001f600", empty, kind)
            for empty in ("allocated", "null"):
                with self.subTest(getter=getter, empty=empty, text=""):
                    self.case(getter, "", empty, "string")

    def test_stringify_returns_and_failed_unspecified_results(self):
        for text in ("ASCII", "\u65e5", "\U0001f600", ""):
            for empty in ("allocated", "null"):
                with self.subTest(text=text, empty=empty):
                    self.case("stringify", text, empty)
        for kind in ("picture", "object", "collection", "boolean", "real"):
            with self.subTest(kind=kind):
                self.case("stringify", kind=kind)
        for case in ("get-a", "get-b", "get-n", "get-c", "stringify"):
            failures = ["error-poison", "error-kind0"]
            if case == "stringify":
                failures.append("error-handle")
            for kind in failures:
                with self.subTest(case=case, kind=kind):
                    self.case(case, kind=kind)
        self.case("stringify", kind="error-copy")

    def test_array_scalar_conversions_and_failure_predicates(self):
        for empty in ("allocated", "null"):
            for text in ("ASCII", "\u65e5", "\U0001f600", ""):
                with self.subTest(array=text, empty=empty):
                    self.case("array", text, empty)
                with self.subTest(text=text, empty=empty):
                    self.case("scalar", text, empty)
        self.case("sdk-failures")
        self.case("values")
        self.case("dispatch")
        self.case("null-controls")

    def test_owning_wrapper_copy_operations(self):
        for wrapper in ("C_TEXT", "ARRAY_TEXT", "C_BLOB", "CBytes", "C_LONGINT"):
            with self.subTest(wrapper=wrapper):
                self.case("traits", wrapper)
        for operation in ("copy-constructor", "copy-assignment"):
            for wrapper in ("ARRAY_TEXT", "C_BLOB"):
                with self.subTest(operation=operation, wrapper=wrapper):
                    self.case(operation, wrapper)


if __name__ == "__main__":
    unittest.main()
