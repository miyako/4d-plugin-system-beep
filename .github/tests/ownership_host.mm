// Engine-boundary model adapted from sleep-notification 7e79e3a34a262e1a5e6bd3f42122ee953d8b805f.
#include "4DPlugin-System-Beep.h"
#include "PrivateTypes.h"
#include "EntryPoints.h"
#include "C_TEXT.h"
#include "ARRAY_TEXT.h"
#include "C_BLOB.h"
#include "C_LONGINT.h"
#include "support/4DPlugin-JSON.h"
#include <codecvt>
#include <cstring>
#include <locale>
#include <type_traits>

static std::map<PA_Unichar*, size_t> strings;
static std::map<PA_Picture, int> pictures;
static std::map<PA_Handle, size_t> handles;
struct Reference { PA_Variable property; };
static std::map<void*, bool> refs;
static bool nullEmpty, failHandle, failResize;
static std::string kind;
static CUTF16String expected;
static int beeps, plays, named;

static void check(bool valid, const char* message)
{
    if (!valid) { std::cerr << message << "\n"; std::exit(1); }
}
static CUTF16String utf16(const char* text)
{
    std::wstring_convert<std::codecvt_utf8_utf16<char16_t>, char16_t> codec;
    auto u = codec.from_bytes(text);
    return CUTF16String(reinterpret_cast<const PA_Unichar*>(u.data()), u.size());
}
static PA_Unistring makeString(const PA_Unichar* text)
{
    size_t units = 0;
    while (text && text[units]) ++units;
    PA_Unistring value = {};
    if (units || !nullEmpty) {
        value.fString = new PA_Unichar[units + 1];
        if (units) std::memcpy(value.fString, text, units * sizeof(PA_Unichar));
        value.fString[units] = 0;
        value.fLength = static_cast<PA_long32>(units);
        strings[value.fString] = units;
    }
    return value;
}
static void disposeString(PA_Unistring value)
{
    if (!value.fString) { check(!value.fLength, "null nonempty string"); return; }
    check(strings.count(value.fString), "duplicate/unowned string disposal");
    check(strings.at(value.fString) == static_cast<size_t>(value.fLength), "allocation length");
    strings.erase(value.fString);
    delete[] value.fString;
}
static void textEquals(PA_Unistring value, const CUTF16String& wanted)
{
    check(value.fLength == static_cast<PA_long32>(wanted.size()), "exact UTF16 unit length");
    check(value.fString || wanted.empty(), "missing string");
    if (value.fString) {
        check(strings.count(value.fString), "read after release");
        check(value.fString[value.fLength] == 0, "terminator boundary");
        check(CUTF16String(value.fString, value.fLength) == wanted, "exact text");
    }
}
static PA_Picture makePicture()
{
    PA_Picture p = new unsigned char(42);
    pictures[p] = 1;
    return p;
}
static void clear(PA_Variable*);
static Reference* makeRef(bool collection)
{
    auto r = new Reference;
    r->property = PA_CreateVariable(eVK_Undefined);
    refs[r] = collection;
    return r;
}
static void releaseRef(void* p)
{
    if (!p) return;
    check(refs.count(p), "release dead reference");
    auto r = static_cast<Reference*>(p);
    clear(&r->property);
    refs.erase(p);
    delete r;
}
static PA_Variable clone(PA_Variable v)
{
    if (v.fType == eVK_Unistring) v.uValue.fString = makeString(v.uValue.fString.fString);
    else if (v.fType == eVK_Picture) {
        check(pictures.count(v.uValue.fPicture), "copy dead picture");
        ++pictures[v.uValue.fPicture];
    } else if (v.fType == eVK_Object || v.fType == eVK_Collection) {
        void* p = v.fType == eVK_Object ? v.uValue.fObject : v.uValue.fCollection;
        if (p) {
            check(refs.count(p), "copy dead reference");
            auto r = makeRef(v.fType == eVK_Collection);
            r->property = clone(static_cast<Reference*>(p)->property);
            if (v.fType == eVK_Object) v.uValue.fObject = r;
            else v.uValue.fCollection = r;
        }
    }
    return v;
}
static void clear(PA_Variable* v)
{
    switch (v->fType) {
    case eVK_Unistring: disposeString(v->uValue.fString); break;
    case eVK_Picture:
        if (v->uValue.fPicture) {
            auto p = v->uValue.fPicture;
            check(pictures.count(p), "release dead picture");
            if (--pictures[p] == 0) { pictures.erase(p); delete static_cast<unsigned char*>(p); }
        }
        break;
    case eVK_Object: releaseRef(v->uValue.fObject); break;
    case eVK_Collection: releaseRef(v->uValue.fCollection); break;
    case eVK_ArrayUnicode: {
        auto h = v->uValue.fArray.fData;
        check(handles.count(h), "clear dead array");
        auto values = reinterpret_cast<PA_Unistring*>(*h);
        for (PA_long32 i = 0; i <= v->uValue.fArray.fNbElements; ++i) disposeString(values[i]);
        std::free(*h); delete h; handles.erase(h);
        break;
    }
    case eVK_Undefined: case eVK_Boolean: case eVK_Real: case eVK_Longint: break;
    default: check(false, "clear unspecified failed/raw-kind0 return");
    }
    v->fType = eVK_Undefined;
    v->fFiller = 0;
}
static PA_Variable resultValue()
{
    PA_Variable v = PA_CreateVariable(eVK_Undefined);
    if (kind == "string") {
        auto s = makeString(expected.c_str()); PA_SetStringVariable(&v, &s);
    } else if (kind == "picture") PA_SetPictureVariable(&v, makePicture());
    else if (kind == "object") PA_SetObjectVariable(&v, makeRef(false));
    else if (kind == "collection") PA_SetCollectionVariable(&v, makeRef(true));
    else if (kind == "boolean") PA_SetBooleanVariable(&v, true);
    else if (kind == "real") PA_SetRealVariable(&v, 3.25);
    else check(false, "unknown result kind");
    return v;
}
static void failedResult(PA_Variable* v)
{
    std::memset(v, kind == "error-poison" ? 0xa5 : 0, sizeof(*v));
}
static void host(short selector, EngineBlock* eb)
{
    switch (selector) {
    case EX_CREATE_UNISTRING:
        eb->fUniString1 = makeString(reinterpret_cast<PA_Unichar*>(eb->fHandle)); break;
    case EX_DISPOSE_UNISTRING: disposeString(eb->fUniString1); break;
    case EX_SET_UNISTRING: {
        auto replacement = makeString(reinterpret_cast<PA_Unichar*>(eb->fHandle));
        disposeString(eb->fUniString1); eb->fUniString1 = replacement; break;
    }
    case EX_VARIABLE_TO_STRING: {
        auto v = reinterpret_cast<PA_Variable*>(eb->fHandle);
        check(v->fType == eVK_Unistring, "reading failed/non-string variable");
        textEquals(v->uValue.fString, expected);
        eb->fUniString1 = v->uValue.fString; break;
    }
    case EX_CREATE_PICTURE: eb->fPicture = makePicture(); break;
    case EX_CLEAR_VARIABLE: clear(static_cast<PA_Variable*>(eb->fPtr1)); break;
    case EX_SET_OBJ_VALUE: {
        check(refs.count(eb->fPtr1), "set dead object");
        auto r = static_cast<Reference*>(eb->fPtr1);
        clear(&r->property);
        r->property = clone(*static_cast<PA_Variable*>(eb->fPtr2));
        break;
    }
    case EX_GET_OBJ_VALUE: {
        check(refs.count(eb->fPtr1), "get dead object");
        auto v = static_cast<PA_Variable*>(eb->fPtr2);
        if (kind.find("error-") == 0) {
            failedResult(v); eb->fError = eER_IncompatibleTypes;
        } else *v = resultValue();
        break;
    }
    case EX_HANDLE_MANAGER: {
        auto h = eb->fHandle;
        switch (eb->fParam1) {
        case 1:
            if (failHandle) { eb->fHandle = nullptr; eb->fError = eER_IncompatibleTypes; break; }
            h = new char*;
            *h = static_cast<char*>(std::calloc(1, std::max<sLONG_PTR>(1, eb->fParam2)));
            check(*h, "test handle allocation failed");
            handles[h] = eb->fParam2; eb->fHandle = h; break;
        case 2:
            check(handles.count(h), "dispose dead handle");
            std::free(*h); delete h; handles.erase(h); break;
        case 3: {
            check(handles.count(h), "resize dead handle");
            if (failResize) { eb->fError = eER_IncompatibleTypes; break; }
            auto data = static_cast<char*>(std::realloc(*h, std::max<sLONG_PTR>(1, eb->fParam2)));
            check(data, "test resize allocation failed");
            *h = data; handles[h] = eb->fParam2; break;
        }
        case 4: check(handles.count(h), "size dead handle"); eb->fParam2 = handles[h]; break;
        case 5: check(handles.count(h), "lock dead handle"); eb->fParam3 = reinterpret_cast<sLONG_PTR>(*h); break;
        case 6: check(handles.count(h), "unlock dead handle"); break;
        default: check(false, "unexpected handle operation");
        }
        break;
    }
    case EX_EXECUTE_COMMAND_BY_ID: {
        auto args = static_cast<PA_Variable**>(eb->fPtr1);
        auto v = static_cast<PA_Variable*>(eb->fPtr2);
        check(v->fType == eVK_Undefined, "command result initialization");
        if (eb->fParam1 == 1231) {
            check(refs.count(args[0]->uValue.fObject), "existence on dead object");
            PA_SetBooleanVariable(v, true);
        } else if (eb->fParam1 == 1225) {
            if (kind == "error-copy") {
                failedResult(v); eb->fError = eER_IncompatibleTypes;
            } else {
                *v = clone(*args[0]);
                if (kind == "error-handle") failHandle = true;
            }
        } else if (eb->fParam1 == 1217) {
            check(refs.count(args[0]->uValue.fObject), "stringify dead argument");
            if (kind.find("error-") == 0) {
                failedResult(v); eb->fError = eER_IncompatibleTypes;
            } else *v = resultValue();
        } else check(false, "unexpected command");
        break;
    }
    default: std::cerr << "unexpected engine selector " << selector << "\n"; std::exit(1);
    }
}

void OwnershipBeep() { ++beeps; }
@implementation OwnershipSound
+ (id)soundNamed:(NSString *)name
{
    NSArray* allowed = @[@"Basso", @"Blow", @"Bottle", @"Frog", @"Funk", @"Glass",
                        @"Hero", @"Morsei", @"Ping", @"Pop", @"Purr", @"Sosumi",
                        @"Submarine", @"Tink"];
    check(named < 14 && [name isEqualToString:[allowed objectAtIndex:named]], "unexpected sound selector");
    ++named; return [[[self alloc] init] autorelease];
}
- (BOOL)play { ++plays; return YES; }
@end
@implementation OwnershipURL
- (id)initWithString:(NSString *)value { check(false, "unexpected URL selector"); return nil; }
- (NSString *)absoluteString { check(false, "unexpected URL selector"); return nil; }
@end
CFURLRef OwnershipCreateURL(CFAllocatorRef, CFStringRef, CFURLPathStyle, Boolean)
{ check(false, "unexpected path operation"); return nullptr; }
CFStringRef OwnershipCopyPath(CFURLRef, CFURLPathStyle)
{ check(false, "unexpected path operation"); return nullptr; }
void OwnershipScale(CGContextRef, CGFloat, CGFloat) { check(false, "unexpected drawing"); }
void OwnershipTranslate(CGContextRef, CGFloat, CGFloat) { check(false, "unexpected drawing"); }

template<class T> typename std::enable_if<std::is_copy_constructible<T>::value>::type copyConstruct()
{ T a; { T b(a); } }
template<class T> typename std::enable_if<!std::is_copy_constructible<T>::value>::type copyConstruct() {}
template<class T> typename std::enable_if<std::is_copy_assignable<T>::value>::type copyAssign()
{ T a; T b; b = a; }
template<class T> typename std::enable_if<!std::is_copy_assignable<T>::value>::type copyAssign() {}
template<class T> static void traits(bool copyable)
{
    check(std::is_copy_constructible<T>::value == copyable, "copy-construction trait");
    check(std::is_copy_assignable<T>::value == copyable, "copy-assignment trait");
}
static void scalarCase()
{
    PA_Unistring input = makeString(expected.c_str());
    PackagePtr params;
    BytePtr pointers[] = {reinterpret_cast<BytePtr>(&input)};
    params = pointers;
    {
        C_TEXT text;
        text.fromParamAtIndex(params, 1);
        PA_DisposeUnistring(&input);
        input = makeString(nullptr);
        text.toParamAtIndex(params, 1);
        textEquals(input, expected);
        CUTF8String u8;
        text.copyUTF8String(&u8);
        C_TEXT converted;
        converted.setUTF8String(&u8);
        check(converted.getUTF16Length() == expected.size(), "conversion UTF16 units");
        check(CUTF16String(converted.getUTF16StringPtr(), converted.getUTF16Length()) == expected, "conversion content");
        PA_Unistring output = makeString(nullptr);
        PA_Unistring* p = &output;
        text.setReturn(reinterpret_cast<sLONG_PTR*>(&p));
        textEquals(output, expected);
        PA_DisposeUnistring(&output);
    }
    textEquals(input, expected);
    PA_DisposeUnistring(&input);
}
static void arrayCase()
{
    PA_Variable ar = PA_CreateVariable(eVK_ArrayUnicode);
    PA_ResizeArray(&ar, 3);
    for (int i = 0; i <= 3; ++i) {
        auto owned = makeString(expected.c_str());
        PA_SetStringInArray(ar, i, &owned);
    }
    {
        ARRAY_TEXT copy;
        BytePtr params[] = {reinterpret_cast<BytePtr>(&ar)};
        copy.fromParamAtIndex(params, 1);
        PA_ClearVariable(&ar);
        ar = PA_CreateVariable(eVK_Undefined);
        for (int i = 0; i < 20; ++i) {
            auto churn = makeString(expected.c_str()); PA_DisposeUnistring(&churn);
            copy.toParamAtIndex(params, 1);
            for (int j = 0; j <= 3; ++j) textEquals(PA_GetStringInArray(ar, j), expected);
        }
        copy.setSize(2); copy.toParamAtIndex(params, 1);
        check(ar.uValue.fArray.fNbElements == 1, "shrink count");
        PA_ClearVariable(&ar);
    }
    auto owned = makeString(expected.c_str());
    auto wrong = PA_CreateVariable(eVK_Longint);
    PA_SetStringInArray(wrong, 0, &owned);
    textEquals(owned, expected);
    ar = PA_CreateVariable(eVK_ArrayUnicode);
    PA_SetStringInArray(ar, -1, &owned);
    PA_SetStringInArray(ar, 1, &owned);
    auto noData = ar; noData.uValue.fArray.fData = nullptr;
    PA_SetStringInArray(noData, 0, &owned);
    PA_SetStringInArray(ar, 0, nullptr);
    textEquals(owned, expected);
    PA_DisposeUnistring(&owned);
    PA_ClearVariable(&ar);
}
static void helperCase(const std::string& name, const char* raw)
{
    auto object = makeRef(false);
    if (name == "set-narrow") ob_set_s(object, "key", raw);
    else if (name == "set-wide") ob_set_s(object, L"key", raw);
    else if (name == "set-wchars") {
        std::wstring_convert<std::codecvt_utf8<wchar_t>> codec;
        auto wide = codec.from_bytes(raw);
        ob_set_a(object, L"key", wide.c_str());
    } else if (name == "set-utf16") ob_set_a(object, L"key", &expected);
    else if (name == "set-picture") ob_set_p(object, L"key", makePicture());
    else if (name == "get-a") {
        CUTF8String value(reinterpret_cast<const uint8_t*>("unchanged"));
        check(ob_get_a(object, L"key", &value), "existing-property boolean preserved");
        if (kind == "string") check(value == CUTF8String(reinterpret_cast<const uint8_t*>(raw)), "getter text");
        else check(value == CUTF8String(reinterpret_cast<const uint8_t*>("unchanged")), "failed/mismatched getter output");
    } else if (name == "get-b") check(ob_get_b(object, L"key") == (kind == "boolean"), "boolean getter");
    else if (name == "get-n") check(ob_get_n(object, L"key") == (kind == "real" ? 3.25 : 0.0), "real getter");
    else if (name == "get-c") {
        auto c = ob_get_c(object, L"key");
        check((c != nullptr) == (kind == "collection"), "collection matching handoff");
        if (c) { check(refs.count(c), "collection prematurely released"); PA_DisposeCollection(c); }
    } else if (name == "stringify") {
        CUTF8String value(reinterpret_cast<const uint8_t*>("unchanged"));
        ob_stringify(object, &value);
        if (kind == "string") check(value == CUTF8String(reinterpret_cast<const uint8_t*>(raw)), "stringify text");
        else check(value == CUTF8String(reinterpret_cast<const uint8_t*>("unchanged")), "failed stringify output");
    } else check(false, "unknown helper");
    if (name.find("set-") == 0 && name != "set-picture") textEquals(object->property.uValue.fString, expected);
    PA_DisposeObject(object);
}
int main(int argc, char** argv)
{
    @autoreleasepool {
        check(argc == 5, "arguments");
        gCall4D = host;
        const std::string name = argv[1], wrapper = argv[2];
        expected = utf16(argv[2]);
        nullEmpty = std::string(argv[3]) == "null";
        kind = argv[4];
        if (name == "scalar") scalarCase();
        else if (name == "array") arrayCase();
        else if (name == "traits") {
            if (wrapper == "C_TEXT") traits<C_TEXT>(false);
            else if (wrapper == "ARRAY_TEXT") traits<ARRAY_TEXT>(false);
            else if (wrapper == "C_BLOB") traits<C_BLOB>(false);
            else if (wrapper == "CBytes") traits<CBytes>(true);
            else if (wrapper == "C_LONGINT") traits<C_LONGINT>(true);
            else check(false, "unknown trait");
        } else if (name == "copy-constructor") {
            if (wrapper == "ARRAY_TEXT") copyConstruct<ARRAY_TEXT>(); else copyConstruct<C_BLOB>();
        } else if (name == "copy-assignment") {
            if (wrapper == "ARRAY_TEXT") copyAssign<ARRAY_TEXT>(); else copyAssign<C_BLOB>();
        } else if (name == "dispatch") {
            for (PA_long32 type = 0; type <= 25; ++type) {
                PA_long32* args[] = {&type};
                PluginBlock p = {}; p.fParameters = args;
                PluginMain(1, &p);
            }
            PluginMain(0, nullptr); PluginMain(999, nullptr);
            check(beeps == 1 && named == 14 && plays == 14, "exact synthetic macOS sound branches");
        } else if (name == "null-controls") {
            CUTF8String value(reinterpret_cast<const uint8_t*>("unchanged"));
            check(!ob_get_a(nullptr, L"key", &value), "null object string getter");
            check(!ob_get_b(nullptr, L"key") && ob_get_n(nullptr, L"key") == 0.0 &&
                  !ob_get_c(nullptr, L"key") && !ob_is_defined(nullptr, L"key"), "null object getters");
            ob_set_s(nullptr, "key", "text"); ob_set_s(nullptr, L"key", "text");
            ob_set_a(nullptr, L"key", L"text"); ob_set_a(nullptr, L"key", &expected);
            ob_stringify(nullptr, &value);
            check(value == CUTF8String(reinterpret_cast<const uint8_t*>("unchanged")), "null control output");
        } else if (name == "sdk-failures") {
            failHandle = true;
            auto h = PA_NewHandle(8);
            check(!h && PA_GetLastError() != eER_NoErr, "handle failure predicate");
            failHandle = false;
            h = PA_NewHandle(8);
            failResize = true;
            check(!PA_SetHandleSize(h, 16) && PA_GetLastError() != eER_NoErr, "resize failure predicate");
            check(handles.at(h) == 8, "model preserved handle capacity");
            failResize = false; PA_DisposeHandle(h);
        } else if (name == "values") {
            C_LONGINT a; a.setIntValue(42); C_LONGINT b = a; check(b.getIntValue() == 42, "value-copy integer");
            const uint8_t bytes[] = {1, 2, 3};
            CBytes original; original.setBytes(bytes, 3);
            CBytes copy = original; original.setBytes(reinterpret_cast<const uint8_t*>("x"), 1);
            check(copy.getBytesLength() == 3 && !std::memcmp(copy.getBytesPtr(), bytes, 3), "independent bytes");
            C_BLOB blob; blob.setBytes(bytes, 3);
            C_TEXT hex; blob.toHexText(&hex);
            check(CUTF16String(hex.getUTF16StringPtr()) == utf16("010203"), "actual blob text consumer");
        } else helperCase(name, argv[2]);
        check(strings.empty(), "unreleased string owner");
        check(pictures.empty(), "unreleased picture owner");
        check(handles.empty(), "unreleased handle owner");
        check(refs.empty(), "unreleased object/collection owner");
        std::cout << "strings=0 pictures=0 handles=0 objects=0 collections=0\n";
    }
}
