# Default niri settings shared by the homeManager and nixos niri modules.
#
# This is NOT a flake-parts module — the `/_` prefix keeps import-tree from
# auto-importing it (see CLAUDE.md). It's a plain attrset of niri settings,
# imported relatively by modules/home/niri.nix (standalone HM) and injected
# into home-manager users by modules/nixos/niri.nix (NixOS path). Keeping the
# binds/layout/window-rules in one place stops the two entry points drifting.
{
  prefer-no-csd = true;
  input = {
    keyboard = {
      xkb = {
        layout = "ie";
      };
    };
  };
  layout = {
    always-center-single-column = true;
    default-column-width = {
      proportion = 0.50;
    };
  };
  window-rules = [
    {
      matches = [
        { app-id = "quake"; }
      ];
      open-focused = true;
      open-floating = true;
    }
  ];
  binds = {
    "Mod+Tab".action.spawn = [
      "noctalia"
      "msg"
      "panel-toggle"
      "launcher"
    ];
    "Mod+Shift+Slash".action.show-hotkey-overlay = { };
    "Mod+Shift+E".action.quit = { };
    "Mod+Escape".action.spawn = [
      "foot"
      "--app-id"
      "quake"
    ];

    "Mod+Left".action.focus-column-left = { };
    "Mod+Right".action.focus-column-right = { };
    "Mod+Up".action.focus-workspace-up = { };
    "Mod+Down".action.focus-workspace-down = { };

    "Mod+Ctrl+Left".action.move-column-left = { };
    "Mod+Ctrl+Right".action.move-column-right = { };

    "Mod+Ctrl+Page_Down".action.move-column-to-workspace-down = { };
    "Mod+Ctrl+Page_Up".action.move-column-to-workspace-up = { };

    "Mod+Shift+Ctrl+Left".action.move-column-to-monitor-left = { };
    "Mod+Shift+Ctrl+Down".action.move-column-to-monitor-down = { };
    "Mod+Shift+Ctrl+Up".action.move-column-to-monitor-up = { };
    "Mod+Shift+Ctrl+Right".action.move-column-to-monitor-right = { };

    "Mod+Ctrl+Down".action.move-window-down = { };
    "Mod+Ctrl+Up".action.move-window-up = { };

    "Mod+F".action.maximize-window-to-edges = { };
    "Mod+X".action.close-window = { };
    "Mod+W".action.toggle-column-tabbed-display = { };
    "Mod+1".action.focus-workspace = 1;
    "Mod+2".action.focus-workspace = 2;
    "Mod+3".action.focus-workspace = 3;
    "Mod+4".action.focus-workspace = 4;
    "Mod+5".action.focus-workspace = 5;
    "Mod+6".action.focus-workspace = 6;
    "Mod+7".action.focus-workspace = 7;
    "Mod+8".action.focus-workspace = 8;
    "Mod+9".action.focus-workspace = 9;
  };
}
