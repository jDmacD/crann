{ inputs, ... }: {
  flake.modules.homeManager.niri =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    let
      cfg = config.crann.niri;
    in
    {
      imports = [
        inputs.niri.homeModules.niri
      ];

      options.crann.niri = {

        package = lib.mkOption {
          type = lib.types.package;
          # Pull niri straight from the niri-flake input rather than via an
          # overlay, so this module is portable to any consumer (standalone HM,
          # useGlobalPkgs, flake-parts, plain flake) without touching their
          # nixpkgs.*. niri-unstable is used because niri-stable (25.08) fails
          # to build against nixpkgs' libdisplay-info 0.3.
          default = inputs.niri.packages.${pkgs.stdenv.hostPlatform.system}.niri-unstable;
          defaultText = lib.literalExpression "inputs.niri.packages.\${system}.niri-unstable";
          description = "The niri package to use.";
        };
        extraSettings = lib.mkOption {
          type = lib.types.attrs;
          default = { };
          description = "Extra per-host niri settings merged in.";
        };

        xdgPortal.enable = lib.mkEnableOption "the GTK and GNOME xdg-desktop-portal setup for niri" // {
          default = true;
        };

      };
      config = {

        xdg.portal = lib.mkIf cfg.xdgPortal.enable {
          enable = true;
          extraPortals = with pkgs; [
            xdg-desktop-portal-gtk
            xdg-desktop-portal-gnome
          ];
        };

        programs.niri = {
          enable = true;
          package = cfg.package;
          settings = lib.mkMerge [
            {
              prefer-no-csd = true;
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
            cfg.extraSettings
          ];
        };

      };
    };
}
