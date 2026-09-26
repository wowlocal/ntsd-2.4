/* Controlled Windows DirectDraw/GDI observation, never original-game execution.
 * Public original IDirectDrawSurface ABI, x86 only. All COM objects and pixel
 * storage belong to this process. See WINDOWS_MENU_TEXT_PROBE_PLAN.md.
 */
typedef unsigned char BYTE;
typedef unsigned short WORD;
typedef unsigned int DWORD;
typedef int LONG;
typedef int BOOL;
typedef WORD WCHAR;
typedef void *HANDLE;
#define WIN __stdcall
#define API __declspec(dllimport)
API HANDLE WIN CreateFileW(const WCHAR *,DWORD,DWORD,void *,DWORD,DWORD,HANDLE);
API BOOL WIN WriteFile(HANDLE,const void *,DWORD,DWORD *,void *);
API BOOL WIN FlushFileBuffers(HANDLE);
API BOOL WIN CloseHandle(HANDLE);
API __declspec(noreturn) void WIN ExitProcess(DWORD);
API DWORD WIN GetLastError(void);
API void WIN SetLastError(DWORD);
API HANDLE WIN LoadLibraryExW(const WCHAR *,HANDLE,DWORD);
API BOOL WIN FreeLibrary(HANDLE);
API HANDLE WIN GetModuleHandleW(const WCHAR *);
API void *WIN GetProcAddress(HANDLE,const char *);
API DWORD WIN GetModuleFileNameW(HANDLE,WCHAR *,DWORD);
API HANDLE WIN GetCurrentProcess(void);
API DWORD WIN GetACP(void);
API DWORD WIN GetOEMCP(void);
_Static_assert(sizeof(void *)==4,"Original public x86 COM ABI only");

typedef struct { DWORD size,flags,height,width; LONG pitch; DWORD backCount,mipCount,alpha,reserved; void *pixels; DWORD keys[8],format[8],caps; } Desc;
typedef struct { DWORD style; void *procedure; LONG clsExtra,windowExtra; HANDLE instance,icon,cursor,brush; const WCHAR *menu,*name; } WindowClass;
_Static_assert(sizeof(Desc)==108,"DDSURFACEDESC");
_Static_assert(__builtin_offsetof(Desc,pixels)==36,"DDSURFACEDESC.lpSurface");
_Static_assert(__builtin_offsetof(Desc,format)==72,"DDSURFACEDESC.ddpfPixelFormat");
_Static_assert(sizeof(WindowClass)==40,"WNDCLASSW");
typedef LONG (WIN *One)(HANDLE);
typedef LONG (WIN *Two)(HANDLE,void *);
typedef LONG (WIN *Coop)(HANDLE,HANDLE,DWORD);
typedef LONG (WIN *Surface)(HANDLE,Desc *,HANDLE *,void *);
typedef LONG (WIN *Blt)(HANDLE,void *,HANDLE,void *,DWORD,void *);
typedef LONG (WIN *Lock)(HANDLE,void *,Desc *,DWORD,HANDLE);
typedef LONG (WIN *DDCreate)(void *,HANDLE *,void *);
typedef WORD (WIN *Register)(WindowClass *);
typedef HANDLE (WIN *Window)(DWORD,const WCHAR *,const WCHAR *,DWORD,int,int,int,int,HANDLE,HANDLE,HANDLE,void *);
typedef BOOL (WIN *Unregister)(const WCHAR *,HANDLE);
typedef HANDLE (WIN *Current)(HANDLE,DWORD);
typedef int (WIN *Object)(HANDLE,int,void *);
typedef int (WIN *Face)(HANDLE,int,WCHAR *);
typedef int (WIN *Caps)(HANDLE,int);
typedef int (WIN *Set)(HANDLE,DWORD);
typedef BOOL (WIN *Extent)(HANDLE,const char *,int,void *);
typedef BOOL (WIN *TextOut)(HANDLE,int,int,const char *,int);
typedef BOOL (WIN *Wow)(HANDLE,WORD *,WORD *);

static Register registerClass;
static Window createWindow;
static One destroyWindow;
static Unregister unregisterClass;
static DDCreate directDrawCreate;
static Current currentObject;
static Object getObject;
static Face textFace;
static Caps deviceCaps;
static Two textMetrics;
static One charset,textAlign,mapMode,bkMode,textColor,bkColor;
static Two viewportOrg,windowOrg,viewportExt,windowExt;
static Set setBkMode,setTextColor;
static Extent textExtent;
static TextOut textOut;
static void *windowProcedure;
static HANDLE output;
static BYTE pixelCopy[794*550*4];
static const DWORD errorSeed=0x6e747364;
static const WCHAR outputName[]=L"menu-text.json",kernelName[]=L"kernel32.dll";
static const WCHAR userName[]=L"user32.dll",gdiName[]=L"gdi32.dll",ddrawName[]=L"ddraw.dll";
static const WCHAR className[]=L"NTSD Menu Text Observer";
#include "windows_menu_text_inputs.h"

static void fill(void *p,DWORD n,BYTE v){BYTE *b=p;for(DWORD i=0;i<n;++i)b[i]=v;}
static void bytes(const void *p,DWORD n){const BYTE *b=p;while(n){DWORD w=0;if(!WriteFile(output,b,n,&w,0)||!w||w>n)ExitProcess(22);b+=w;n-=w;}}
static void text(const char *s){DWORD n=0;while(s[n])++n;bytes(s,n);}
static void number(DWORD n){char b[10];DWORD i=10;do{b[--i]=(char)('0'+n%10);n/=10;}while(n);bytes(b+i,10-i);}
static void field(const char *s,DWORD n){text(",\"");text(s);text("\":");number(n);}
static void hex(const void *p,DWORD n){const BYTE *b=p;static const char digits[]="0123456789abcdef";char out[128];text("\"");for(DWORD i=0;i<n;){DWORD count=n-i;if(count>64)count=64;for(DWORD j=0;j<count;++j){out[2*j]=digits[b[i+j]>>4];out[2*j+1]=digits[b[i+j]&15];}bytes(out,count*2);i+=count;}text("\"");}
static void blob(const char *s,const void *p,DWORD n){text(",\"");text(s);text("\":");hex(p,n);}
static void reply(const char *s,DWORD result){DWORD error=GetLastError();text(",\"");text(s);text("\":{\"resultBits\":");number(result);field("lastErrorAfter",error);text("}");}
static void *method(HANDLE o,DWORD slot){return (*(void ***)o)[slot];}
static void module(HANDLE h,const char *name){WCHAR path[1024];fill(path,sizeof(path),0xa5);SetLastError(errorSeed);DWORD n=h?GetModuleFileNameW(h,path,1024):0;DWORD e=GetLastError();text("{\"name\":\"");text(name);text("\"");field("loaded",h!=0);field("pathCharacters",n);field("lastErrorAfter",e);blob("pathUTF16LE",path,n<=1024?n*2:sizeof(path));text("}");}
static void environment(HANDLE u,HANDLE g,HANDLE d){HANDLE k=GetModuleHandleW(kernelName);Wow wow=(Wow)GetProcAddress(k,"IsWow64Process2");text("\"environment\":{\"compiledMachine\":332,\"pointerBits\":32");field("acp",GetACP());field("oemcp",GetOEMCP());text(",\"isWow64Process2\":{\"available\":");text(wow?"true":"false");if(wow){WORD p=0xa5a5,n=0xa5a5;SetLastError(errorSeed);DWORD r=wow(GetCurrentProcess(),&p,&n),e=GetLastError();field("resultBits",r);field("lastErrorAfter",e);field("processMachine",p);field("nativeMachine",n);}text("},\"modules\":[");module(k,"kernel32.dll");text(",");module(u,"user32.dll");text(",");module(g,"gdi32.dll");text(",");module(d,"ddraw.dll");text("]}");}

/* Copy only successful owned Lock storage, while locked. Serialize after Unlock.
 * Negative pitch is retained; output rows follow logical top-to-bottom order.
 * Failures in Unlock stop later drawing so no drawing occurs on a known lock.
 */
static BOOL snapshot(HANDLE surface,const char *label){
    Desc desc;fill(&desc,sizeof(desc),0xa5);desc.size=sizeof(desc);
    text(",\"");text(label);text("\":{\"lockFlags\":17");blob("descriptorBefore",&desc,sizeof(desc));
    SetLastError(errorSeed);LONG r=((Lock)method(surface,25))(surface,0,&desc,0x11,0);reply("lock",r);blob("descriptorAfter",&desc,sizeof(desc));
    BOOL valid=0;DWORD count=0,rowBytes=0;
    if(r==0){
        DWORD bpp=desc.format[3];
        BOOL format=(desc.format[1]&0x40)&&!(desc.format[1]&0x4)&&(bpp==8||bpp==16||bpp==24||bpp==32);
        if(format)rowBytes=(794*bpp+7)/8;
        LONG pitch=desc.pitch;
        valid=desc.size==108&&(desc.flags&0x180e)==0x180e&&desc.width==794&&desc.height==550&&desc.format[0]==32&&format&&desc.pixels&&pitch!=(-2147483647-1)&&pitch<=32768&&pitch>=-32768&&(DWORD)(pitch<0?-pitch:pitch)>=rowBytes;
        if(valid){
            count=rowBytes*550;
            const BYTE *source=desc.pixels;
            for(DWORD y=0;y<550;++y)for(DWORD x=0;x<rowBytes;++x)pixelCopy[y*rowBytes+x]=source[(LONG)y*pitch+(LONG)x];
        }
        SetLastError(errorSeed);LONG unlocked=((Two)method(surface,32))(surface,desc.pixels);reply("unlock",unlocked);
        text(",\"storageAccepted\":");text(valid?"true":"false");
        if(valid){field("rowBytes",rowBytes);field("rows",550);blob("pixelsTopLeft",pixelCopy,count);}
        text("}");return unlocked==0;
    }
    text(",\"storageAccepted\":false}");return 1;
}
static void queryOne(HANDLE dc,const char *name,One fn){SetLastError(errorSeed);reply(name,fn(dc));}
static void queryPair(HANDLE dc,const char *name,Two fn){LONG pair[2];fill(pair,sizeof(pair),0xa5);text(",\"");text(name);text("\":{\"before\":");hex(pair,sizeof(pair));SetLastError(errorSeed);reply("query",fn(dc,pair));blob("after",pair,sizeof(pair));text("}");}
static void font(HANDLE dc){
    SetLastError(errorSeed);HANDLE selected=currentObject(dc,6);DWORD e=GetLastError();field("selectedFont",(DWORD)selected);field("selectedFontError",e);
    if(selected){BYTE logical[92];fill(logical,sizeof(logical),0xa5);blob("logFontBefore",logical,sizeof(logical));SetLastError(errorSeed);reply("getObject",getObject(selected,sizeof(logical),logical));blob("logFontAfter",logical,sizeof(logical));}
    BYTE metrics[60];fill(metrics,sizeof(metrics),0xa5);blob("textMetricBefore",metrics,sizeof(metrics));SetLastError(errorSeed);reply("getTextMetrics",textMetrics(dc,metrics));blob("textMetricAfter",metrics,sizeof(metrics));
    WCHAR face[256];fill(face,sizeof(face),0xa5);SetLastError(errorSeed);reply("getTextFace",textFace(dc,256,face));blob("textFaceUTF16LE",face,sizeof(face));
    queryOne(dc,"charset",charset);queryOne(dc,"textAlign",textAlign);queryOne(dc,"mapMode",mapMode);queryOne(dc,"bkMode",bkMode);queryOne(dc,"textColor",textColor);queryOne(dc,"bkColor",bkColor);
    queryPair(dc,"viewportOrg",viewportOrg);queryPair(dc,"windowOrg",windowOrg);queryPair(dc,"viewportExt",viewportExt);queryPair(dc,"windowExt",windowExt);
    const int keys[]={2,8,10,12,14,38,88,90,104,117,118};text(",\"deviceCaps\":[");for(DWORD i=0;i<sizeof(keys)/sizeof(keys[0]);++i){if(i)text(",");text("{\"index\":");number(keys[i]);SetLastError(errorSeed);reply("query",deviceCaps(dc,keys[i]));text("}");}text("]");
}
static BOOL line(HANDLE surface,DWORD index){
    if(index)text(",");text("{\"index\":");number(index);field("x",inputX[index]);field("y",inputY[index]);field("length",inputLength[index]);blob("bytes",inputText[index],inputLength[index]);
    HANDLE dc=0;SetLastError(errorSeed);LONG acquired=((Two)method(surface,17))(surface,&dc);reply("getDC",acquired);field("dc",(DWORD)dc);
    BOOL released=1;
    if(acquired>=0&&dc){
        font(dc);LONG extent[2];fill(extent,sizeof(extent),0xa5);blob("extentBefore",extent,sizeof(extent));SetLastError(errorSeed);reply("getTextExtent",textExtent(dc,inputText[index],inputLength[index],extent));blob("extentAfter",extent,sizeof(extent));
        SetLastError(errorSeed);reply("setBkMode",setBkMode(dc,1));SetLastError(errorSeed);reply("setTextColor",setTextColor(dc,0xd07750));SetLastError(errorSeed);reply("textOut",textOut(dc,inputX[index],inputY[index],inputText[index],inputLength[index]));
        SetLastError(errorSeed);LONG r=((Two)method(surface,26))(surface,dc);reply("releaseDC",r);released=r==0;
    }else if(acquired>=0){text(",\"boundary\":\"nonnegative-getdc-with-null-handle\"");released=0;}
    text("}");return released;
}
static void observe(HANDLE window){
    HANDLE draw=0,primary=0,back=0;BOOL primaryOwned=0,backOwned=0;SetLastError(errorSeed);LONG r=directDrawCreate(0,&draw,0);reply("directDrawCreate",r);field("draw",(DWORD)draw);
    if(r!=0||!draw)return;
    SetLastError(errorSeed);r=((Coop)method(draw,20))(draw,window,8);reply("setCooperativeLevel",r);
    if(r<0)goto cleanup;
    Desc desc;fill(&desc,sizeof(desc),0);desc.size=108;desc.flags=1;desc.caps=0x200;blob("primaryDescriptor",&desc,sizeof(desc));
    SetLastError(errorSeed);r=((Surface)method(draw,6))(draw,&desc,&primary,0);reply("createPrimary",r);field("primary",(DWORD)primary);
    if(r!=0||!primary)goto cleanup;primaryOwned=1;
    desc.flags=7;desc.width=794;desc.height=550;desc.caps=0x40;blob("backDescriptor",&desc,sizeof(desc));
    SetLastError(errorSeed);r=((Surface)method(draw,6))(draw,&desc,&back,0);reply("createBack",r);field("back",(DWORD)back);
    if(r!=0||!back)goto cleanup;backOwned=1;
    DWORD format[8];fill(format,sizeof(format),0xa5);format[0]=32;blob("pixelFormatBefore",format,sizeof(format));SetLastError(errorSeed);reply("getPixelFormat",((Two)method(back,21))(back,format));blob("pixelFormatAfter",format,sizeof(format));
    DWORD fx[25];fill(fx,sizeof(fx),0);fx[0]=100;fx[20]=0x10206c;blob("fillEffects",fx,sizeof(fx));
    LONG rect[]={0,0,794,550};SetLastError(errorSeed);r=((Blt)method(back,5))(back,rect,0,0,0x1000400,fx);reply("fill",r);
    if(r!=0)goto cleanup;
    if(!snapshot(back,"beforeText"))goto cleanup;
    text(",\"lines\":[");BOOL ready=1;for(DWORD i=0;i<3&&ready;++i)ready=line(back,i);text("]");
    if(ready)snapshot(back,"afterText");
cleanup:
    if(backOwned){SetLastError(errorSeed);reply("releaseBack",((One)method(back,2))(back));}
    if(primaryOwned){SetLastError(errorSeed);reply("releasePrimary",((One)method(primary,2))(primary));}
    SetLastError(errorSeed);reply("releaseDraw",((One)method(draw,2))(draw));
}
#define RESOLVE(module,variable,type,name) variable=module?(type)GetProcAddress(module,name):0;ready=ready&&(variable!=0)
void entry(void){
    output=CreateFileW(outputName,0x40000000,0,0,1,0x80,0);if(output==(HANDLE)-1)ExitProcess(21);
    SetLastError(errorSeed);HANDLE u=LoadLibraryExW(userName,0,0x800);DWORD ue=GetLastError();SetLastError(errorSeed);HANDLE g=LoadLibraryExW(gdiName,0,0x800);DWORD ge=GetLastError();SetLastError(errorSeed);HANDLE d=LoadLibraryExW(ddrawName,0,0x800);DWORD de=GetLastError();BOOL ready=1;
    RESOLVE(u,registerClass,Register,"RegisterClassW");RESOLVE(u,createWindow,Window,"CreateWindowExW");RESOLVE(u,destroyWindow,One,"DestroyWindow");RESOLVE(u,unregisterClass,Unregister,"UnregisterClassW");RESOLVE(u,windowProcedure,void *,"DefWindowProcW");RESOLVE(d,directDrawCreate,DDCreate,"DirectDrawCreate");
    RESOLVE(g,currentObject,Current,"GetCurrentObject");RESOLVE(g,getObject,Object,"GetObjectW");RESOLVE(g,textMetrics,Two,"GetTextMetricsW");RESOLVE(g,textFace,Face,"GetTextFaceW");RESOLVE(g,deviceCaps,Caps,"GetDeviceCaps");
    RESOLVE(g,charset,One,"GetTextCharset");RESOLVE(g,textAlign,One,"GetTextAlign");RESOLVE(g,mapMode,One,"GetMapMode");RESOLVE(g,bkMode,One,"GetBkMode");RESOLVE(g,textColor,One,"GetTextColor");RESOLVE(g,bkColor,One,"GetBkColor");
    RESOLVE(g,viewportOrg,Two,"GetViewportOrgEx");RESOLVE(g,windowOrg,Two,"GetWindowOrgEx");RESOLVE(g,viewportExt,Two,"GetViewportExtEx");RESOLVE(g,windowExt,Two,"GetWindowExtEx");
    RESOLVE(g,setBkMode,Set,"SetBkMode");RESOLVE(g,setTextColor,Set,"SetTextColor");RESOLVE(g,textExtent,Extent,"GetTextExtentPoint32A");RESOLVE(g,textOut,TextOut,"TextOutA");
    text("{\"schema\":\"ntsd-windows-menu-text-v1\",\"gameExecuted\":false,\"fullMenu\":false,\"snapshotsAreWriteMasks\":false,");environment(u,g,d);field("lastErrorSeed",errorSeed);field("user32LoadError",ue);field("gdi32LoadError",ge);field("ddrawLoadError",de);text(",\"functionsReady\":");text(ready?"true":"false");
    if(ready){
        HANDLE instance=GetModuleHandleW(0);WindowClass cls;fill(&cls,sizeof(cls),0);cls.style=3;cls.procedure=windowProcedure;cls.instance=instance;cls.name=className;
        SetLastError(errorSeed);WORD atom=registerClass(&cls);reply("registerClass",atom);
        if(atom){SetLastError(errorSeed);HANDLE window=createWindow(0,className,className,0x10cb0000,0x80000000,5,794,550,0,0,instance,0);DWORD e=GetLastError();field("window",(DWORD)window);field("createWindowError",e);
            if(window){observe(window);SetLastError(errorSeed);reply("destroyWindow",destroyWindow(window));}
            SetLastError(errorSeed);reply("unregisterClass",unregisterClass(className,instance));
        }
    }
    if(d){SetLastError(errorSeed);reply("freeDdraw",FreeLibrary(d));}if(g){SetLastError(errorSeed);reply("freeGdi",FreeLibrary(g));}if(u){SetLastError(errorSeed);reply("freeUser",FreeLibrary(u));}
    text(",\"complete\":true}\n");BOOL f=FlushFileBuffers(output),c=CloseHandle(output);ExitProcess(f&&c?0:23);
}
