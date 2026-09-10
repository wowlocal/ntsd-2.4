/* Actual Windows API collector for NTSD's unresolved VC80 NLS dependency.
 * Research-only: no game execution, hooks, memory faults or protection changes.
 * Exact finite inputs and full destination snapshots are emitted; snapshots
 * are NOT instruction-level write masks. See WINDOWS_REFERENCE_PLAN.md.
 * Freestanding Windows C: SDK-compatible declarations, no CRT dependency.
 */
typedef unsigned char BYTE;
typedef unsigned short WORD;
typedef unsigned int DWORD;
typedef int BOOL;
typedef void *HANDLE;
typedef WORD WCHAR;
typedef __UINTPTR_TYPE__ UINTPTR;
#define API __declspec(dllimport)
#define WIN __stdcall
_Static_assert(sizeof(DWORD) == 4 && sizeof(WCHAR) == 2, "Windows ABI");

API HANDLE WIN CreateFileW(const WCHAR *, DWORD, DWORD, void *, DWORD, DWORD, HANDLE);
API BOOL WIN WriteFile(HANDLE, const void *, DWORD, DWORD *, void *);
API BOOL WIN FlushFileBuffers(HANDLE);
API BOOL WIN CloseHandle(HANDLE);
API __declspec(noreturn) void WIN ExitProcess(DWORD);
API DWORD WIN GetLastError(void);
API void WIN SetLastError(DWORD);
API BOOL WIN GetStringTypeW(DWORD, const WCHAR *, int, WORD *);
API BOOL WIN GetCPInfo(DWORD, void *);
API int WIN MultiByteToWideChar(DWORD, DWORD, const char *, int, WCHAR *, int);
API int WIN WideCharToMultiByte(DWORD, DWORD, const WCHAR *, int, char *, int, const char *, BOOL *);
API int WIN LCMapStringW(DWORD, DWORD, const WCHAR *, int, WCHAR *, int);
API DWORD WIN GetACP(void);
API DWORD WIN GetOEMCP(void);
API DWORD WIN GetThreadLocale(void);
API DWORD WIN GetSystemDefaultLCID(void);
API DWORD WIN GetUserDefaultLCID(void);
API HANDLE WIN GetModuleHandleW(const WCHAR *);
API void *WIN GetProcAddress(HANDLE, const char *);
API DWORD WIN GetModuleFileNameW(HANDLE, WCHAR *, DWORD);
API HANDLE WIN GetCurrentProcess(void);
API BOOL WIN GetVersionExW(void *);

static HANDLE output;
static DWORD cases;
_Alignas(8) static BYTE before[2048], after[2048], input[256];
static WCHAR converted[512], mapped[1024];
static const WCHAR filename[] = {'n','l','s','.','j','s','o','n',0};
static const WCHAR kernel32[] = {'k','e','r','n','e','l','3','2','.','d','l','l',0};
static const WCHAR kernelbase[] = {'k','e','r','n','e','l','b','a','s','e','.','d','l','l',0};
static const WCHAR ntdll[] = {'n','t','d','l','l','.','d','l','l',0};
static const WCHAR enUS[] = {'e','n','-','U','S',0};
static const DWORD errorSeed = 0x6e747364;

static void fill(void *ptr, DWORD n, BYTE value) {
    BYTE *p = ptr; for (DWORD i = 0; i < n; ++i) p[i] = value;
}
static void copy(void *dst, const void *src, DWORD n) {
    BYTE *d = dst; const BYTE *s = src;
    for (DWORD i = 0; i < n; ++i) d[i] = s[i];
}
static void bytes(const void *ptr, DWORD n) {
    const BYTE *p = ptr;
    while (n) {
        DWORD written = 0;
        if (!WriteFile(output, p, n, &written, 0) || !written || written > n)
            ExitProcess(22); /* Partial capture remains on disk. */
        p += written; n -= written;
    }
}
static void text(const char *s) {
    DWORD n = 0; while (s[n]) ++n; bytes(s, n);
}
static void number(DWORD n) {
    char b[10]; DWORD i = 10;
    do { b[--i] = (char)('0' + n % 10); n /= 10; } while (n);
    bytes(b + i, 10 - i);
}
static void hex(const void *ptr, DWORD n) {
    static const char digits[] = "0123456789abcdef";
    const BYTE *p = ptr; char b[128];
    text("\"");
    for (DWORD i = 0; i < n;) {
        DWORD count = n - i; if (count > 64) count = 64;
        for (DWORD j = 0; j < count; ++j) {
            b[j * 2] = digits[p[i + j] >> 4];
            b[j * 2 + 1] = digits[p[i + j] & 15];
        }
        bytes(b, count * 2); i += count;
    }
    text("\"");
}
static void field(const char *name, DWORD value) {
    text(",\""); text(name); text("\":"); number(value);
}
static DWORD begin(const char *api, const void *src, DWORD srcBytes,
                   int count, DWORD capacity, int parent) {
    DWORD id = cases++;
    if (id) text(",");
    text("{\"id\":"); number(id);
    text(",\"api\":\""); text(api); text("\",\"sourceBytes\":"); hex(src, srcBytes);
    field("sourceCount", (DWORD)count); field("destinationCapacity", capacity);
    if (parent >= 0) field("parentConversion", (DWORD)parent);
    field("lastErrorBefore", errorSeed);
    return id;
}
static void result(int value, DWORD error, DWORD n) {
    field("resultBits", (DWORD)value); field("lastErrorAfter", error);
    text(",\"destinationBefore\":"); hex(before, n);
    text(",\"destinationAfter\":"); hex(after, n);
    text("}");
}
static void prepare(DWORD n, BYTE seed) {
    fill(before, n, seed); fill(after, n, seed);
}
static void classify(const WCHAR *source, int n, int parent, BYTE seed) {
    prepare((DWORD)n * 2, seed);
    begin("GetStringTypeW", source, (DWORD)n * 2, n, (DWORD)n, parent);
    field("infoType", 1);
    SetLastError(errorSeed);
    int r = GetStringTypeW(1, source, n, (WORD *)after);
    DWORD error = GetLastError(); result(r, error, (DWORD)n * 2);
}
static void mapping(const WCHAR *source, int n, int parent, BYTE seed, DWORD flags) {
    prepare(sizeof(mapped), seed); copy(mapped, before, sizeof(mapped));
    begin("LCMapStringW", source, (DWORD)n * 2, n, 1024, parent);
    field("locale", 0x409); field("flags", flags);
    SetLastError(errorSeed);
    int r = LCMapStringW(0x409, flags, source, n, mapped, 1024);
    DWORD error = GetLastError(); copy(after, mapped, sizeof(mapped));
    result(r, error, sizeof(mapped));
}
static void reverse(const WCHAR *source, int n, int parent, BYTE seed) {
    BOOL used = 0x5a5a5a5a;
    prepare(1024, seed);
    begin("WideCharToMultiByte", source, (DWORD)n * 2, n, 1024, parent);
    field("codePage", 1252); field("flags", 0);
    text(",\"defaultChar\":null"); field("usedDefaultBefore", (DWORD)used);
    SetLastError(errorSeed);
    int r = WideCharToMultiByte(1252, 0, source, n, (char *)after, 1024, 0, &used);
    DWORD error = GetLastError(); field("usedDefaultAfter", (DWORD)used);
    result(r, error, 1024);
}
static void module(const WCHAR *name, const char *label) {
    WCHAR path[1024]; fill(path, sizeof(path), 0);
    HANDLE h = GetModuleHandleW(name);
    SetLastError(errorSeed);
    DWORD n = h ? GetModuleFileNameW(h, path, 1024) : 0;
    DWORD error = GetLastError();
    text("{\"name\":\""); text(label); text("\"");
    field("loaded", h != 0); field("pathCharacters", n); field("lastErrorAfter", error);
    text(",\"pathUTF16LE\":"); hex(path, n <= 1024 ? n * 2 : sizeof(path)); text("}");
}
static void metadata(void) {
    DWORD version[71]; fill(version, sizeof(version), 0); version[0] = sizeof(version);
    SetLastError(errorSeed); BOOL vr = GetVersionExW(version); DWORD ve = GetLastError();
    text("\"environment\":{\"compiledMachine\":");
#if defined(_M_IX86)
    number(0x14c);
#elif defined(_M_ARM64)
    number(0xaa64);
#else
#error Collector currently supports x86 and ARM64 only
#endif
    field("pointerBits", sizeof(void *) * 8);
    field("acp", GetACP()); field("oemcp", GetOEMCP());
    field("threadLCID", GetThreadLocale()); field("userLCID", GetUserDefaultLCID());
    field("systemLCID", GetSystemDefaultLCID());
    text(",\"getVersionExW\":{\"manifestVersionMayApply\":true");
    field("resultBits", (DWORD)vr); field("lastErrorAfter", ve);
    text(",\"structureAfter\":"); hex(version, sizeof(version)); text("}");
    HANDLE k = GetModuleHandleW(kernel32);
    typedef BOOL (WIN *WowFn)(HANDLE, WORD *, WORD *);
    WowFn wow = (WowFn)GetProcAddress(k, "IsWow64Process2");
    text(",\"isWow64Process2\":{\"available\":"); text(wow ? "true" : "false");
    if (wow) {
        WORD process = 0xa5a5, native = 0xa5a5;
        SetLastError(errorSeed); BOOL r = wow(GetCurrentProcess(), &process, &native);
        DWORD e = GetLastError(); field("resultBits", (DWORD)r); field("lastErrorAfter", e);
        field("processMachine", process); field("nativeMachine", native);
    }
    text("},\"getNLSVersionEx\":{\"available\":");
    typedef BOOL (WIN *NLSFn)(DWORD, const WCHAR *, void *);
    NLSFn nls = (NLSFn)GetProcAddress(k, "GetNLSVersionEx");
    text(nls ? "true" : "false");
    if (nls) {
        DWORD info[8]; fill(info, sizeof(info), 0); info[0] = sizeof(info);
        text(",\"locale\":\"en-US\""); field("function", 1);
        SetLastError(errorSeed); BOOL r = nls(1, enUS, info); DWORD e = GetLastError();
        field("resultBits", (DWORD)r); field("lastErrorAfter", e);
        text(",\"structureAfter\":"); hex(info, sizeof(info));
    }
    text("},\"modules\":["); module(kernel32, "kernel32.dll"); text(",");
    module(kernelbase, "kernelbase.dll"); text(","); module(ntdll, "ntdll.dll");
    text("]}");
}
void entry(void) {
    output = CreateFileW(filename, 0x40000000, 0, 0, 1, 0x80, 0); /* CREATE_NEW */
    if (output == (HANDLE)(UINTPTR)-1) ExitProcess(21);
    text("{\"schema\":\"ntsd-windows-nls-v1\",\"kind\":\"windowsAPICollectorOutput\",");
    metadata(); text(",\"cases\":[");
    WCHAR nul = 0;
    for (DWORD i = 0; i < 2; ++i) {
        prepare(2, 0xa5);
        if (!i) { before[0] = after[0] = 0xd8; before[1] = after[1] = 0xe9; }
        begin("GetStringTypeW", &nul, 2, 1, 1, -1); field("infoType", 1);
        SetLastError(errorSeed);
        int r = GetStringTypeW(1, &nul, 1, (WORD *)after);
        DWORD e = GetLastError(); result(r, e, 2);
    }
    for (DWORD i = 0; i < 2; ++i) {
        prepare(20, i ? 0xa5 : 0);
        begin("GetCPInfo", 0, 0, 0, 20, -1); field("codePage", 1252);
        SetLastError(errorSeed); int r = GetCPInfo(1252, after);
        DWORD e = GetLastError(); result(r, e, 20);
    }
    for (DWORD i = 0; i < 256; ++i) input[i] = (BYTE)i;
    for (DWORD flags = 0; flags < 2; ++flags) for (DWORD i = 0; i < 2; ++i) {
        BYTE seed = i ? 0xa5 : 0;
        prepare(sizeof(converted), seed); copy(converted, before, sizeof(converted));
        DWORD parent = begin("MultiByteToWideChar", input, 256, 256, 512, -1);
        field("codePage", 1252); field("flags", flags);
        SetLastError(errorSeed);
        int r = MultiByteToWideChar(1252, flags, (const char *)input, 256, converted, 512);
        DWORD e = GetLastError(); copy(after, converted, sizeof(converted));
        result(r, e, sizeof(converted));
        if (r > 0 && r <= 512) {
            classify(converted, r, (int)parent, seed);
            mapping(converted, r, (int)parent, seed, 0x100);
            mapping(converted, r, (int)parent, seed, 0x200);
            reverse(converted, r, (int)parent, seed);
        }
    }
    text("]"); field("caseCount", cases); text(",\"complete\":true}\n");
    BOOL flushed = FlushFileBuffers(output); BOOL closed = CloseHandle(output);
    ExitProcess(flushed && closed ? 0 : 23);
}
