// SDL3 for the engine's NTSDSDLHost. The include path comes from NTSD_SDL_PREFIX
// (engine/Package.swift), the library path from the game's app (native/Package.swift).
// Macros Swift cannot import are re-exported as constants.
#include <SDL3/SDL.h>

static const SDL_InitFlags NTSD_SDL_INIT = SDL_INIT_VIDEO | SDL_INIT_AUDIO | SDL_INIT_GAMEPAD;
static const SDL_WindowFlags NTSD_SDL_WINDOW_HIDDEN = SDL_WINDOW_HIDDEN;
static const SDL_WindowFlags NTSD_SDL_WINDOW_FULLSCREEN = SDL_WINDOW_FULLSCREEN;
static const SDL_WindowFlags NTSD_SDL_WINDOW_RESIZABLE = SDL_WINDOW_RESIZABLE;
static const SDL_WindowFlags NTSD_SDL_WINDOW_MAXIMIZED = SDL_WINDOW_MAXIMIZED;
static const SDL_WindowFlags NTSD_SDL_WINDOW_HIGH_PIXEL_DENSITY = SDL_WINDOW_HIGH_PIXEL_DENSITY;
static const int NTSD_SDL_WINDOWPOS_CENTERED = SDL_WINDOWPOS_CENTERED;
static const SDL_AudioDeviceID NTSD_SDL_DEFAULT_PLAYBACK = SDL_AUDIO_DEVICE_DEFAULT_PLAYBACK;
static const SDL_AudioFormat NTSD_SDL_AUDIO_F32 = SDL_AUDIO_F32;
static const SDL_MouseButtonFlags NTSD_SDL_BUTTON_LMASK = SDL_BUTTON_LMASK;
static const SDL_MouseButtonFlags NTSD_SDL_BUTTON_RMASK = SDL_BUTTON_RMASK;
static const SDL_Keymod NTSD_SDL_KMOD_SHIFT = SDL_KMOD_SHIFT;
static const SDL_Keymod NTSD_SDL_KMOD_CTRL = SDL_KMOD_CTRL;
static const SDL_Keymod NTSD_SDL_KMOD_ALT = SDL_KMOD_ALT;
static const SDL_Keymod NTSD_SDL_KMOD_CAPS = SDL_KMOD_CAPS;
static const SDL_Keycode NTSD_SDL_SCANCODE_MASK = SDLK_SCANCODE_MASK;
static const SDL_MessageBoxFlags NTSD_SDL_MESSAGEBOX_ERROR = SDL_MESSAGEBOX_ERROR;
static const SDL_MessageBoxFlags NTSD_SDL_MESSAGEBOX_WARNING = SDL_MESSAGEBOX_WARNING;
static const SDL_MessageBoxButtonFlags NTSD_SDL_MESSAGEBOX_BUTTON_RETURNKEY_DEFAULT = SDL_MESSAGEBOX_BUTTON_RETURNKEY_DEFAULT;
