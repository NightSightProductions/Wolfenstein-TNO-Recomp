# Port notes

## Supported release (Steam, app 201810)

| File | SHA-256 |
|---|---|
| WolfNewOrder_x64.exe (SteamStub-wrapped, as shipped) | 9e413197e097ba41e85f0de47ddd3918f7656c432f8431f5f15e4b7eeb7c371c |
| superscriptx64.dll | e8d1b5f6cb6dffeb992e146d1bd5d953bf07812bbad7644468a61240f895cf70 |
| bink2w64.dll | 07915cf09c53bdec299854d05dba1435e15a5640c71f1ac48b0cd5512046e8f1 |

## Findings

- **SteamStub DRM.** The entry point (0x220e2f0) is in `.bind`; `.text` has entropy 8.00, so it's encrypted.
  The translator needs the decrypted `.text` and the original entry point.
  Unwrapped by `tools/unwrap_steamstub.py` at build time: SteamStub **v3.0 x64** (signature 0xC0DEC0DE, 0xD0-byte
  header before the stub entry point), AES-256-CBC `.text` with 16 stolen bytes. OEP = 0xac8938 (MSVC CRT start).
  Unwrapped SHA-256: bd70efffbd47ebbf93232838af0d89d63ff8432c13757516701556edeaca3f2b.
- **OpenGL, not Vulkan.** id Tech 5: wgl + `wglGetProcAddress`. The only hard check is `glVersion < 3.0`; the
  version comes from cvars. The context is made at 0x14046dab7 with `WGL_CONTEXT_PROFILE_MASK_ARB = 2`
  (**compatibility** profile). It imports fixed-function calls (`glShadeModel`, `glAlphaFunc`, `glColor4f`).
  Plan: wgl → CGL 4.1 core (native macOS GL, Metal-backed), plus a shim for the compat-only behaviour:
  default VAO, no-op/emulated fixed-function calls. Fallback: Mesa Zink on KosmicKrisp (GL 4.6 compat).
  The runtime needs a new `opengl32`/`wgl` layer (the framework only has GL for mac32).
- **CUDA.** `cudart64_40_17.dll` and the `.nvFatBi` section are used for GPU transcoding of virtual textures. Stub
  `cudart` so the device query reports no CUDA, and the engine falls back to CPU transcode.
- Other imports beyond DOOM's set: WSOCK32 (ordinals), PSAPI, IPHLPAPI, dbghelp, DINPUT8, XINPUT1_3, GDI32
  pixel-format/gamma, `ole32`, and the old steam_api flat exports (`SteamUser()` etc.).

## Status (2026-11-17)

- Translation: EXE 47,487 functions, superscriptx64 705, bink2w64 651, with no unsupported instructions on any
  live path. Links into `build/boot` (72 MB arm64).
- Boots through the CRT, file system and cvars, creates the Win32 window, and stops at renderer init:
  `FATAL ERROR: wglChoosePixelFormatARB not available` (no GL layer yet).

### Framework changes (in framework/, uncommitted)
- `tools/pe.py`, `tools/recomp64.py`: every executable section is code. The EXE links a small SSE math library
  in a second section, `text` at 0x141fb8000.
- `tools/recomp64.py`, `runtime/cpu.h`: MMX support (mm0-7 in CPU state, `MM64` lanes). Bink's hand-written
  IDCT/colour kernels use it. Verified by `tests/mmx_fuzz.py` (50 forms, bit-exact vs x86 under Rosetta).
- `tools/recomp64.py`: register caching rewrote `FPUSH(c,`/`FPOP(c)` as `PUSHL`/`POPL` (plain text replace).
- `runtime/kernel32.c`: ANSI CRT init functions (GetEnvironmentStrings, GetStartupInfoA, GetStringTypeA,
  LCMapStringA, GetLocaleInfoA, GetVersion, SetHandleCount) and CompareStringW. WideCharToMultiByte dropped
  embedded NULs, so the VS2010 CRT's environment conversion failed (R6009).

### Game-specific
- `src/native_wolf.c`: `fmodf` at 0x140ac4640 (x87 `fprem` loop) → libm.

### OpenGL layer (framework/runtime/opengl.m, tools/gen_gl.py -> runtime/gl_thunks.h)
- wgl contexts are CGL 4.1 core contexts in one share group. The game asks for 3.2 compatibility.
- The default framebuffer is an FBO over three IOSurface textures (sRGB); SwapBuffers draws the finished one into
  the window's CAMetalLayer with a Metal pass. FBO 0, GL_BACK and the default VAO are translated in every entry
  point that names them.
- GL_EXTENSIONS: the host's list plus what 4.1 core subsumes, and GL_ARB_vertex_program. The engine loads
  glVertexAttrib*ARB only when that extension is listed; the ARB assembly-program half is logging stubs.
- Legacy ALPHA/LUMINANCE/INTENSITY textures become R/RG with swizzles (font atlases, Bink Y/U/V planes).
- Debugging: RT_GL_CHECK=1 (glGetError after every call), RT_GL_SHADERS=dir, RT_GL_SCREENSHOT=n
  (+ RT_GL_SCREENSHOT_FILE), RT_FPS=1.

### Status (2026-11-17, later)
- Intro videos, title screen and main menu render at 60 fps (3420x2223 native or emulated fullscreen modes),
  with music and sound, keyboard/mouse and controllers.
- Fixed on the way:
  - wsock32 ordinals 10-12 were inet_addr/inet_ntoa/ioctlsocket in the wrong order: the menu's local socket stayed
    blocking and froze the game.
  - XAudio2: an engine released and created again stayed stopped (silence after the intro videos).
  - XAPO effects (AudioReverb/VolumeMeter) as pass-through objects; xinput1_3 aliases; RtlPcToFileHeader (MSVC
    x64 C++ throw); ISteamRemoteStorage (no cloud; the game doesn't use Steam Cloud); non-UTF-8 window titles; CUDA registration stubs (game);
    dbghelp, GDI, EnumDisplayDevicesA, RegQueryInfoKeyA, HeapWalk.
- Tracing: RT_NET_TRACE=1 (sockets), RT_AUDIO_TRACE=1 (voices and output level).

### Fixed after the first play-test
- Missing walls / pop-in: occlusion queries are created on the main thread's context and issued on the renderer's;
  query names are now shared across contexts (Windows drivers do this).
- imul r/m8 / r/m16 CF/OF (found by tests/insn_fuzz.py; the rest of its differences are NaN-sign and rcp/rsqrt
  precision, harmless).
- XAudio2 submix routing (volume sliders), see the framework commit.

### Since then
- Steam Play: NightSight Recomp (NSR, framework/tools/nsr.py) launches the app from the game's own Steam entry,
  with the overlay and NotProton plugins. Steam for Mac can't start a non-NotProton tool with launch options
  (`env VAR=... <tool>` fails, OS Error 260), so a game's settings go in NSR's games.conf (`nsr.py set-env`).
  `make steam-play` registers the app. Verified: online through the Steam client, stats load, overlay libraries
  are passed in.
- Fullscreen resolution changes between modes of the same aspect: SetWindowPos now reports the new rect at once
  (Cocoa sends no resize when the Mac window keeps its size).
- The app is "Wolfenstein The New Order.app", shown as "Wolfenstein: The New Order".
- XAudio2: multiple sends per voice with per-destination matrices; effect chains; the AudioReverb effect
  (runtime/xreverb.c, tested offline for decay time, HF damping, stability); the game's own XAPOs run as on Windows
  (mgXAPOCompressor / CompressorApply, mgXAPOLimiter on the master, mgXAPOSampleCounter). The game's reverb is a
  mono submix at stage 100; level presets reach it (reverb output up to 0.9 in play).

- Adaptive vsync: WGL_EXT_swap_control_tear is listed and a negative swap interval presents a late frame at once
  instead of waiting for the next refresh. The game picks it by default (swap interval -1).
- The per-frame CPU wait before presenting was left in on purpose: id Tech 5 caps itself at 60 fps (still exactly
  60.0 with vsync off), and frames take about 5 ms CPU + 5 ms GPU including the wait, so a presenter thread would
  add threading risk for no measurable gain. Revisit if heavy scenes drop below 60.

- Installer (setup/macos, adapted from DOOM-Recomp's): builds the game from the user's copy with scripts/build.sh,
  installs "Wolfenstein The New Order.app", optional desktop shortcut and NSR registration (uninstall removes only
  this game's NSR entry). `setup/macos/build_installer.sh` makes Wolfenstein-TNO-Recomp-macOS.dmg (source only, no
  game files). Verified: a clean copy of the tracked files builds and runs in about 5 minutes.
- DOOM-Recomp builds and runs (60 fps, Vulkan) on the current framework.

### Not done yet
- Longer play-test: saves and loads, later chapters, in-engine videos; achievements unlocking.
- Windowed mode, alt-tab and other monitors (lightly tested).
- A README screenshot; switching the README's "Playing on macOS" to the installer once a release DMG is published.
  (GOG: not planned.)
