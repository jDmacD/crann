{ inputs, ... }: {
  flake.homeModules.niri =
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
          # niri-stable (25.08) fails to build against nixpkgs' libdisplay-info
          # 0.3; niri-unstable dropped that dependency and builds cleanly.
          default = pkgs.niri-unstable;
          defaultText = lib.literalExpression "pkgs.niri-unstable";
          description = "The niri package to use.";
        };
        extraSettings = lib.mkOption {
          type = lib.types.attrs;
          default = { };
          description = "Extra per-host niri settings merged in.";
        };

      };
      config = {

        nixpkgs.overlays = [ inputs.niri.overlays.niri ];

        programs.niri = {
          enable = true;
          package = cfg.package;
          settings = lib.mkMerge [
            {
              binds = {
                "Mod+Shift+Slash".action.show-hotkey-overlay = { };
              };
            }
            cfg.extraSettings
          ];
        };

      };
    };
}
