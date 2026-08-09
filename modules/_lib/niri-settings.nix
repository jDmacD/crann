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
    default-column-width = {
      proportion = 0.50;
    };
    preset-column-widths = [
      { proportion = 1. / 3.; }
      { proportion = 1. / 2.; }
      { proportion = 2. / 3.; }
      # { fixed = 1920; }
    ];
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
    # The following binds move the focused window in and out of a column.
    # If the window is alone, they will consume it into the nearby column to the side.
    # If the window is already in a column, they will expel it out.
    # Mod+BracketLeft  { consume-or-expel-window-left; }
    "Mod+BracketLeft".action.consume-or-expel-window-left = { };
    # Mod+BracketRight { consume-or-expel-window-right; }
    "Mod+BracketRight".action.consume-or-expel-window-right = { };
    # Consume one window from the right to the bottom of the focused column.
    # Mod+Comma  { consume-window-into-column; }
    "Mod+Comma".action.consume-window-into-column = { };
    # Expel the bottom window from the focused column to the right.
    # Mod+Period { expel-window-from-column; }
    "Mod+Period".action.expel-window-from-column = { };
    # Cycle through widths set in preset-column-widths.
    # Mod+R { switch-preset-column-width; }
    "Mod+R".action.switch-preset-column-width = { };
    # Cycling through the presets in reverse order is also possible.
    # Mod+Shift+R { switch-preset-column-width-back; }
    "Mod+Shift+R".action.switch-preset-column-width-back = { };
    # Mod+Ctrl+Shift+R { switch-preset-window-height; }
    "Mod+Ctrl+Shift+R".action.switch-preset-window-height = { };
    # Mod+Ctrl+R { reset-window-height; }
    "Mod+Ctrl+R".action.reset-window-height = { };
    # Mod+F { maximize-column; }
    "Mod+F".action.maximize-column = { };
    # Mod+Shift+F { fullscreen-window; }
    "Mod+Shift+F".action.fullscreen-window = { };

    # While maximize-column leaves gaps and borders around the window,
    # maximize-window-to-edges doesn't: the window expands to the edges of the screen.
    # This bind corresponds to normal window maximizing,
    # e.g. by double-clicking on the titlebar.
    # Mod+M { maximize-window-to-edges; }
    "Mod+M".action.maximize-window-to-edges = { };

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
