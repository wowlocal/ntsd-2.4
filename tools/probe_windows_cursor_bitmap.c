/* Bounded LF2_CURSOR Windows loader observation; not original game execution.
 * Maps reference.exe as resources only. Reads only the DIBSECTION storage
 * belonging to this collector's freshly loaded bitmap after descriptor checks.
 * Observed bytes are NOT write masks or guaranteed initial values.
 * See WINDOWS_CURSOR_BITMAP_PROBE_PLAN.md. No CRT or Windows SDK required.
 */
typedef unsigned char BYTE;
typedef unsigned short WORD;
typedef unsigned int DWORD;
typedef int LONG;
typedef int BOOL;
typedef WORD WCHAR;
typedef void *HANDLE;
typedef __UINTPTR_TYPE__ UINTPTR;
#define API __declspec(dllimport)
#define WIN __stdcall
API HANDLE WIN CreateFileW(const WCHAR *, DWORD, DWORD, void *, DWORD, DWORD, HANDLE);
API BOOL WIN WriteFile(HANDLE, const void *, DWORD, DWORD *, void *);
API BOOL WIN FlushFileBuffers(HANDLE);
API BOOL WIN CloseHandle(HANDLE);
API __declspec(noreturn) void WIN ExitProcess(DWORD);
API DWORD WIN GetLastError(void);
API void WIN SetLastError(DWORD);
API HANDLE WIN LoadLibraryExW(const WCHAR *, HANDLE, DWORD);
API BOOL WIN FreeLibrary(HANDLE);
API HANDLE WIN GetModuleHandleW(const WCHAR *);
API void *WIN GetProcAddress(HANDLE, const char *);
API DWORD WIN GetModuleFileNameW(HANDLE, WCHAR *, DWORD);
API HANDLE WIN GetCurrentProcess(void);
API HANDLE WIN FindResourceA(HANDLE, const char *, const char *);
API HANDLE WIN LoadResource(HANDLE, HANDLE);
API void *WIN LockResource(HANDLE);
API DWORD WIN SizeofResource(HANDLE, HANDLE);
API DWORD WIN GetACP(void);
API DWORD WIN GetOEMCP(void);

typedef struct { LONG type, width, height, stride; WORD planes, bpp; void *bits; } Bitmap;
typedef struct {
    DWORD size; LONG width, height; WORD planes, bpp;
    DWORD compression, imageBytes; LONG xppm, yppm; DWORD used, important;
} BitmapHeader;
typedef struct { Bitmap bm; BitmapHeader header; DWORD masks[3]; HANDLE section; DWORD offset; } DibSection;
_Static_assert(sizeof(BitmapHeader) == 40, "BITMAPINFOHEADER ABI");
_Static_assert(sizeof(Bitmap) == (sizeof(void *) == 4 ? 24 : 32), "BITMAP ABI");
_Static_assert(sizeof(DibSection) == (sizeof(void *) == 4 ? 84 : 104), "DIBSECTION ABI");
typedef HANDLE (WIN *LoadImageFn)(HANDLE, const char *, DWORD, int, int, DWORD);
typedef int (WIN *GetObjectFn)(HANDLE, int, void *);
typedef HANDLE (WIN *CreateDCFn)(HANDLE);
typedef HANDLE (WIN *SelectFn)(HANDLE, HANDLE);
typedef DWORD (WIN *PaletteFn)(HANDLE, DWORD, DWORD, void *);
typedef BOOL (WIN *DeleteFn)(HANDLE);
typedef int (WIN *CapsFn)(HANDLE, int);
typedef BOOL (WIN *WowFn)(HANDLE, WORD *, WORD *);
static LoadImageFn loadImage;
static GetObjectFn getObject;
static CreateDCFn createDC;
static SelectFn selectObject;
static PaletteFn palette;
static DeleteFn deleteDC, deleteObject;
static CapsFn caps;
static HANDLE output;
static const DWORD errorSeed = 0x6e747364;
static const WCHAR fileName[] = {'c','u','r','s','o','r','.','j','s','o','n',0};
static const WCHAR referenceName[] = {'.','\\','r','e','f','e','r','e','n','c','e','.','e','x','e',0};
static const WCHAR kernelName[] = {'k','e','r','n','e','l','3','2','.','d','l','l',0};
static const WCHAR userName[] = {'u','s','e','r','3','2','.','d','l','l',0};
static const WCHAR gdiName[] = {'g','d','i','3','2','.','d','l','l',0};

static void fill(void *p, DWORD n, BYTE value) { BYTE *b=p; for(DWORD i=0;i<n;++i)b[i]=value; }
static void bytes(const void *p, DWORD n) {
    const BYTE *b=p;
    while(n) { DWORD written=0; if(!WriteFile(output,b,n,&written,0)||!written||written>n)ExitProcess(22); b+=written;n-=written; }
}
static void text(const char *s) { DWORD n=0;while(s[n])++n;bytes(s,n); }
static void number(DWORD n) { char b[10];DWORD i=10;do{b[--i]=(char)('0'+n%10);n/=10;}while(n);bytes(b+i,10-i); }
static void field(const char *name,DWORD value) { text(",\"");text(name);text("\":");number(value); }
static void hex(const void *p,DWORD n) {
    const BYTE *b=p;static const char d[]="0123456789abcdef";char out[128];text("\"");
    for(DWORD i=0;i<n;) { DWORD count=n-i;if(count>64)count=64;for(DWORD j=0;j<count;++j){out[2*j]=d[b[i+j]>>4];out[2*j+1]=d[b[i+j]&15];}bytes(out,count*2);i+=count; }text("\"");
}
static void pointer(const char *name,HANDLE value) { text(",\"");text(name);text("\":");hex(&value,sizeof(value)); }
static void reply(const char *name,DWORD value,DWORD error) { text(",\"");text(name);text("\":{\"resultBits\":");number(value);field("lastErrorAfter",error);text("}"); }
static void module(HANDLE handle,const char *name) {
    WCHAR path[1024];fill(path,sizeof(path),0xa5);SetLastError(errorSeed);
    DWORD count=handle?GetModuleFileNameW(handle,path,1024):0;DWORD error=GetLastError();
    text("{\"name\":\"");text(name);text("\"");field("loaded",handle!=0);field("pathCharacters",count);field("lastErrorAfter",error);
    text(",\"pathUTF16LE\":");hex(path,count<=1024?count*2:sizeof(path));text("}");
}
static void environment(HANDLE user,HANDLE gdi) {
    HANDLE kernel=GetModuleHandleW(kernelName);WowFn wow=(WowFn)GetProcAddress(kernel,"IsWow64Process2");
    text("\"environment\":{\"compiledMachine\":");
#if defined(_M_IX86)
    number(0x14c);
#elif defined(_M_ARM64)
    number(0xaa64);
#else
#error Supported collector machines: x86 and ARM64
#endif
    field("pointerBits",sizeof(void*)*8);field("acp",GetACP());field("oemcp",GetOEMCP());
    text(",\"isWow64Process2\":{\"available\":");text(wow?"true":"false");
    if(wow){WORD process=0xa5a5,native=0xa5a5;SetLastError(errorSeed);BOOL r=wow(GetCurrentProcess(),&process,&native);DWORD e=GetLastError();field("resultBits",r);field("lastErrorAfter",e);field("processMachine",process);field("nativeMachine",native);}text("}");
    text(",\"modules\":[");module(kernel,"kernel32.dll");text(",");module(user,"user32.dll");text(",");module(gdi,"gdi32.dll");text("]}");
}
static void attempt(HANDLE source,DWORD index) {
    if(index)text(",");text("{\"index\":");number(index);field("loadImageType",0);field("loadImageFlags",0x2000);field("requestedWidth",0);field("requestedHeight",0);
    SetLastError(errorSeed);HANDLE bitmap=loadImage(source,"LF2_CURSOR",0,0,0,0x2000);DWORD e=GetLastError();pointer("bitmap",bitmap);field("loadImageError",e);
    if(!bitmap){text(",\"observation\":\"load-failed\"}");return;}
    DibSection ds;fill(&ds,sizeof(ds),0xa5);text(",\"descriptorBefore\":");hex(&ds,sizeof(ds));
    SetLastError(errorSeed);int got=getObject(bitmap,sizeof(ds),&ds);e=GetLastError();reply("getObject",got,e);text(",\"descriptorAfter\":");hex(&ds,sizeof(ds));
    BOOL valid=got==(int)sizeof(ds)&&ds.bm.width==11&&ds.bm.height==19&&ds.bm.planes==1&&ds.bm.bpp==8&&ds.bm.stride>=11&&ds.bm.stride<=4096&&ds.bm.bits&&ds.header.size==40&&ds.header.width==11&&(ds.header.height==19||ds.header.height==-19)&&ds.header.planes==1&&ds.header.bpp==8&&ds.header.compression==0;
    text(",\"descriptorAccepted\":");text(valid?"true":"false");
    if(valid){
        DWORD n=(DWORD)ds.bm.stride*19;field("storageBytes",n);text(",\"storageBeforePalette\":");hex(ds.bm.bits,n);
        SetLastError(errorSeed);HANDLE dc=createDC(0);e=GetLastError();pointer("memoryDC",dc);field("createDCError",e);
        if(dc){
            text(",\"deviceCaps\":[");const int keys[]={2,12,14,38,88,90};for(DWORD j=0;j<6;++j){if(j)text(",");SetLastError(errorSeed);int value=caps(dc,keys[j]);e=GetLastError();text("{\"index\":");number(keys[j]);field("resultBits",value);field("lastErrorAfter",e);text("}");}text("]");
            SetLastError(errorSeed);HANDLE previous=selectObject(dc,bitmap);e=GetLastError();pointer("previousObject",previous);field("selectError",e);
            if(previous&&previous!=(HANDLE)(UINTPTR)-1){
                BYTE colors[1024];fill(colors,sizeof(colors),0xa5);text(",\"paletteBefore\":");hex(colors,sizeof(colors));
                SetLastError(errorSeed);DWORD count=palette(dc,0,256,colors);e=GetLastError();reply("getPalette",count,e);text(",\"paletteAfter\":");hex(colors,sizeof(colors));
                SetLastError(errorSeed);HANDLE restored=selectObject(dc,previous);e=GetLastError();pointer("restoreResult",restored);field("restoreError",e);
            }
            SetLastError(errorSeed);BOOL r=deleteDC(dc);e=GetLastError();reply("deleteDC",r,e);
        }
        text(",\"storageAfterPalette\":");hex(ds.bm.bits,n);
    }
    SetLastError(errorSeed);BOOL deleted=deleteObject(bitmap);e=GetLastError();reply("deleteObject",deleted,e);text("}");
}
void entry(void) {
    output=CreateFileW(fileName,0x40000000,0,0,1,0x80,0);if(output==(HANDLE)(UINTPTR)-1)ExitProcess(21);
    SetLastError(errorSeed);HANDLE user=LoadLibraryExW(userName,0,0x800);DWORD ue=GetLastError();
    SetLastError(errorSeed);HANDLE gdi=LoadLibraryExW(gdiName,0,0x800);DWORD ge=GetLastError();
    loadImage=user?(LoadImageFn)GetProcAddress(user,"LoadImageA"):0;
    getObject=gdi?(GetObjectFn)GetProcAddress(gdi,"GetObjectW"):0;
    createDC=gdi?(CreateDCFn)GetProcAddress(gdi,"CreateCompatibleDC"):0;
    selectObject=gdi?(SelectFn)GetProcAddress(gdi,"SelectObject"):0;
    palette=gdi?(PaletteFn)GetProcAddress(gdi,"GetDIBColorTable"):0;
    deleteDC=gdi?(DeleteFn)GetProcAddress(gdi,"DeleteDC"):0;
    deleteObject=gdi?(DeleteFn)GetProcAddress(gdi,"DeleteObject"):0;
    caps=gdi?(CapsFn)GetProcAddress(gdi,"GetDeviceCaps"):0;
    BOOL ready=loadImage&&getObject&&createDC&&selectObject&&palette&&deleteDC&&deleteObject&&caps;
    text("{\"schema\":\"ntsd-windows-cursor-bitmap-v1\",\"kind\":\"windowsAPICollectorOutput\",\"storageSnapshotsAreWriteMasks\":false,\"gameExecuted\":false,\"resourceName\":\"LF2_CURSOR\",");
    environment(user,gdi);field("lastErrorSeed",errorSeed);field("systemModuleFlags",0x800);field("user32LoadError",ue);field("gdi32LoadError",ge);text(",\"functionsReady\":");text(ready?"true":"false");
    SetLastError(errorSeed);HANDLE source=LoadLibraryExW(referenceName,0,0x60);DWORD e=GetLastError();text(",\"resource\":{\"moduleFlags\":96");pointer("module",source);field("moduleError",e);
    BOOL resourceReady=0;
    if(source){
        SetLastError(errorSeed);HANDLE found=FindResourceA(source,"LF2_CURSOR",(const char*)(UINTPTR)2);e=GetLastError();pointer("found",found);field("findError",e);
        if(found){SetLastError(errorSeed);DWORD n=SizeofResource(source,found);e=GetLastError();field("bytes",n);field("sizeError",e);
            if(n&&n<=65536){SetLastError(errorSeed);HANDLE data=LoadResource(source,found);e=GetLastError();pointer("data",data);field("loadError",e);
                if(data){SetLastError(errorSeed);void *raw=LockResource(data);e=GetLastError();pointer("locked",raw);field("lockError",e);if(raw){text(",\"raw\":");hex(raw,n);resourceReady=1;}}
            }
        }
    }
    text("},\"attempts\":[");if(ready&&resourceReady)for(DWORD i=0;i<3;++i)attempt(source,i);text("]");
    if(source){SetLastError(errorSeed);BOOL r=FreeLibrary(source);e=GetLastError();reply("freeResourceModule",r,e);}
    if(gdi){SetLastError(errorSeed);BOOL r=FreeLibrary(gdi);e=GetLastError();reply("freeGdiModule",r,e);}
    if(user){SetLastError(errorSeed);BOOL r=FreeLibrary(user);e=GetLastError();reply("freeUserModule",r,e);}
    text(",\"complete\":true}\n");BOOL flushed=FlushFileBuffers(output);BOOL closed=CloseHandle(output);ExitProcess(flushed&&closed?0:23);
}
