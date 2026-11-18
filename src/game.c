// Wolfenstein: The New Order settings for Recomp-Framework (see framework/runtime/game.h).
#include "game.h"

const RtGame rt_game = {
    .name = "Wolfenstein: The New Order",
    .exe = "WolfNewOrder_x64.exe",
    .win_dir = "C:\\Program Files (x86)\\Steam\\steamapps\\common\\Wolfenstein.The.New.Order",
    .data_name = "wolfnew-recomp",
    .log_name = "WolfNewOrder-recomp",
    .env_prefix = "WOLF",
    .steam_folder = "Wolfenstein.The.New.Order",
    .steam_app_id = 201810,
    .relaunch_prefix = "WolfNewOrder",
    .extra_args = NULL,
    .cloud_save_dir = NULL,
    .cloud_prefix = NULL,
    .computer_name = "MAC",
    .pick_folder_msg = NULL,
    // the DRM-free copy made at build time by tools/unwrap_steamstub.py and bundled into the app
    // (the Steam folder's exe has its code encrypted by SteamStub)
    .image = "WolfNewOrder_x64.exe",
    // id Tech 5 loads glVertexAttrib*ARB (core in 4.1) only when this extension is listed
    .gl_extensions = "GL_ARB_vertex_program",
};
