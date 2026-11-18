# Wolfenstein: The New Order on Recomp-Framework (framework/, a git submodule): static recompilation to native arm64 macOS.
#   make gen gen-dll gen-bink   translate WolfNewOrder_x64.exe, superscriptx64.dll and bink2w64.dll
#   make -j8 boot               build the runtime + translated game
#   make app                    "build/Wolfenstein The New Order.app"
#   make steam-play             register the app with NightSight Recomp (NSR), the Steam Play tool (needs NotProton)
#                               APP_PATH="/Applications/Wolfenstein The New Order.app" if the app was moved
#
# orig.exe must be the DRM-free (unwrapped) executable: the Steam release's .text is encrypted by SteamStub
# and cannot be translated as shipped. See README.md, "How It Works".
FW        = framework
PYTHON    = .venv/bin/python
BUILD     = build
GAME_EXE ?= orig.exe
APP_NAME  = Wolfenstein
# the bundle's file name (no colon: Finder would show it as "/") and the name shown in the menu bar and Dock
APP_FILE  = Wolfenstein The New Order
APP_DISPLAY = Wolfenstein: The New Order
BUNDLE_ID = com.local.wolfneworder-recomp
APP_CATEGORY = public.app-category.action-games
# OpenGL game (no Vulkan driver); the unwrapped exe goes into Resources as rt_game.image (src/game.c)
APP_FLAGS = --no-vulkan --resource build/WolfNewOrder_x64.unwrapped.exe=WolfNewOrder_x64.exe
GAME_SRC  = src/game.c src/native_wolf.c src/imports_wolf.c
NATIVE    = tools/native.txt
PATCHES   = tools/patches.txt
EXTRA_LIBS_FORCE = $(BUILD)/libsuperscriptx64.a $(BUILD)/libbink2w64.a

include $(FW)/recomp.mk

# superscriptx64.dll (the script VM)
SUPERSCRIPT_DLL ?= orig_superscript.dll
$(eval $(call MODULE_RULES,superscriptx64,$(SUPERSCRIPT_DLL),gen_superscript,,))
# RAD Bink 2: shares superscriptx64's preferred base, so translate it rebased (as DOOM-Recomp does)
BINK_DLL ?= orig_bink.dll
$(eval $(call MODULE_RULES,bink2w64,$(BINK_DLL),gen_bink,--rebase 182000000 --no-abi-trim,-DRT_TSO=0))

gen-dll: gen-superscriptx64
gen-bink: gen-bink2w64
.PHONY: gen-dll gen-bink

# Steam Play: Play on the game's own Steam entry starts the app (framework/tools/nsr.py)
APP_PATH ?= $(CURDIR)/$(BUILD)/$(APP_FILE).app
steam-play:
	python3 $(FW)/tools/nsr.py install
	python3 $(FW)/tools/nsr.py add --appid 201810 --app "$(APP_PATH)" --pass-paths --exe 'WolfNewOrder_x64.exe' \
	    --name "Wolfenstein: The New Order"
.PHONY: steam-play
