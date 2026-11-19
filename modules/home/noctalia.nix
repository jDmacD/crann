# Noctalia shell, migrated from blueprint.
#
# With `desktop.enable`, every host runs one shared desktop with per-host
# overrides, using Noctalia's own file layering rather than merging attrsets in
# Nix. Noctalia merges every ~/.config/noctalia/*.toml alphabetically (tables
# key by key, a list replaces the earlier list), then the GUI's
# ~/.local/state/noctalia/settings.toml on top:
#
#   config.toml   programs.noctalia.settings: this module + stylix (theme, font)
#   desktop.toml  the shared desktop, captured from the GUI (_lib/noctalia/)
#   host.toml     crann.noctalia.hostSettings: outputs, folders, devices
#   settings.toml live GUI tweaks until they're captured
#
# `noctalia-capture` diffs the GUI layer against the declared files and writes
# the host-independent part into desktop.toml (_lib/noctalia/capture.py).
#
# See CLAUDE.md for the conventions this follows.
{ inputs, ... }:
{
  flake.modules.homeManager.noctalia =
    {
      lib,
      config,
      pkgs,
      ...
    }:
    let
      cfg = config.crann.noctalia;
      tomlFormat = pkgs.formats.toml { };
      noctalia = config.programs.noctalia.package;

      # The same check noctalia's own module runs on config.toml.
      validated =
        name: src:
        pkgs.runCommand "noctalia-${name}" { } ''
          ${lib.getExe noctalia} config validate ${src}
          cp ${src} $out
        '';

      capture = pkgs.writeShellApplication {
        name = "noctalia-capture";
        runtimeInputs = [ pkgs.python3 ];
        text = ''
          export NOCTALIA_BIN=${lib.getExe noctalia}
          export REMARSHAL_BIN=${lib.getExe' pkgs.remarshal "remarshal"}
          exec python3 -I ${../_lib/noctalia/capture.py} "$@"
        '';
      };
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

        desktop = {
          enable = lib.mkEnableOption "the shared Noctalia desktop (desktop.toml and host.toml layers, noctalia-capture)";

          settingsFile = lib.mkOption {
            type = lib.types.path;
            default = ../_lib/noctalia/desktop.toml;
            description = ''
              The shared desktop layer, installed as ~/.config/noctalia/desktop.toml.
              Defaults to crann's own; fill it with
              `noctalia-capture --write <crann checkout>/modules/_lib/noctalia/desktop.toml`.
            '';
          };
        };

        hostSettings = lib.mkOption {
          type = tomlFormat.type;
          default = { };
          description = ''
            This host's layer, installed as ~/.config/noctalia/host.toml and
            merged over desktop.toml (needs `desktop.enable`): per-monitor
            wallpaper folders and bars (match outputs by description substring,
            e.g. "P2419H", not by connector), devices, and any plugin setting
            that has to differ on this host.
          '';
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

        xdg.configFile = lib.mkIf cfg.desktop.enable {
          "noctalia/desktop.toml".source = validated "desktop.toml" cfg.desktop.settingsFile;
          "noctalia/host.toml" = lib.mkIf (cfg.hostSettings != { }) {
            source = validated "host.toml" (tomlFormat.generate "host.toml" cfg.hostSettings);
          };
        };

        home.packages = lib.mkIf cfg.desktop.enable [
          capture
          # Runtime tools of the knyrps/nix-search launcher provider (`/nix <query>`),
          # enabled in desktop.toml: it indexes with nix-search-tv and filters with fzf.
          pkgs.nix-search-tv
          pkgs.fzf
        ];

      };
    };
}
