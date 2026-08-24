# Noctalia shell, migrated from blueprint. Barebones for now — settings and
# wallpaper handling are being refactored for noctalia 5.
# See CLAUDE.md for the conventions this follows.
{ inputs, ... }:
{
  flake.modules.homeManager.noctalia =
    {
      lib,
      config,
      ...
    }:
    let
      cfg = config.crann.noctalia;
    in
    {
      imports = [
        inputs.noctalia.homeModules.default
      ];

      # home-manager gained its own modules/programs/noctalia.nix upstream, which
      # declares the same `programs.noctalia.*` options as noctalia's flake module
      # above — two declarations of one option namespace is a hard eval error
      # ("already declared in ..."), not a merge. Disable home-manager's copy and
      # keep noctalia's: theirs is versioned with the shell itself, and its
      # `package` default is the flake's pinned revision, whereas home-manager's
      # is `mkPackageOption pkgs "noctalia"` — i.e. whatever nixpkgs happens to
      # carry, which is not what this module's `settings` are written against.
      # Path is relative to home-manager's own module root, not this file.
      disabledModules = [ "programs/noctalia.nix" ];

      options.crann.noctalia = {

        enable = lib.mkEnableOption "the noctalia shell";

        extraSettings = lib.mkOption {
          type = lib.types.attrsOf lib.types.anything;
          default = { };
          description = "noctalia-shell settings.";
        };

      };

      config = lib.mkIf cfg.enable {

        programs.noctalia = {
          enable = true;
          settings = lib.mkMerge [
            {
              # noctalia 5 ships a screenshot widget but leaves it out of the default bar
              # layout, so it has to be named explicitly — nothing is auto-added when
              # wlr-screencopy is present (niri exposes zwlr_screencopy_manager_v1 v3
              # here, so the widget's availability gate passes). Named bar tables merge
              # key-by-key over noctalia's defaults, but a list replaces the default
              # list wholesale: this is the stock `start` with "screenshot" inserted
              # next to the other action buttons.
              bar.default.start = [
                "launcher"
                "wallpaper"
                "screenshot"
                "workspaces"
              ];
            }
            cfg.extraSettings
          ];
        };

      };
    };
}
