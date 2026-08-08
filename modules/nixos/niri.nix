# niri, NixOS-class module — the system layer for niri on a NixOS host.
#
# This wraps niri-flake's own `nixosModules.niri`, which provides everything
# the home-manager module cannot: `xdg.portal.enable` + the gnome portal
# (required by nix-flatpak's assertion and by screencast), the display-manager
# session entry, polkit + a polkit agent, gnome-keyring, dconf, graphics, and
# the niri binary cache.
#
# niri-flake's nixos module also auto-injects its home config module
# (`homeModules.config` — the `programs.niri.settings`/`package` options) into
# every home-manager user via `home-manager.sharedModules`. That is the
# intended NixOS + home-manager flow: you configure `programs.niri.settings`
# per user rather than importing the standalone home module. On top of that
# injection we add crann's default settings (+ `crann.niri.extraSettings`), so
# home-manager users on the host get crann's binds without importing anything.
#
# Because this is the injection path, a consumer using this module must NOT
# also import `flake.modules.homeManager.niri` for the same user — that module
# imports niri's home module and would double-declare `programs.niri.*`. Use
# the home module only for standalone (non-NixOS) home-manager.
{ inputs, ... }:
{
  flake.modules.nixos.niri =
    {
      pkgs,
      lib,
      config,
      options,
      ...
    }:
    let
      cfg = config.crann.niri;
      defaultSettings = import ../_lib/niri-settings.nix;
    in
    {
      imports = [
        inputs.niri.nixosModules.niri
      ];

      options.crann.niri = {

        enable = lib.mkEnableOption "the niri NixOS system layer (portal, session, polkit, keyring)" // {
          default = true;
        };

        package = lib.mkOption {
          type = lib.types.package;
          # niri-unstable, matching the home module: niri-stable (25.08) fails to
          # build against nixpkgs' libdisplay-info 0.3. Pulled from the input so
          # this module never touches the consumer's nixpkgs.*.
          default = inputs.niri.packages.${pkgs.stdenv.hostPlatform.system}.niri-unstable;
          defaultText = lib.literalExpression "inputs.niri.packages.\${system}.niri-unstable";
          description = "The niri package to use (system-level).";
        };

        extraSettings = lib.mkOption {
          type = lib.types.attrs;
          default = { };
          description = "Extra niri settings merged into the defaults injected for home-manager users.";
        };

      };

      config = lib.mkIf cfg.enable (
        lib.mkMerge [
          {
            programs.niri = {
              enable = true;
              package = cfg.package;
            };
          }
          # Inject crann's default niri config into home-manager users. Only when
          # the host actually uses the home-manager NixOS module — otherwise the
          # `home-manager.*` options don't exist and this would error.
          (lib.optionalAttrs (options ? home-manager) {
            home-manager.sharedModules = [
              {
                programs.niri.settings = lib.mkMerge [
                  defaultSettings
                  cfg.extraSettings
                ];
              }
            ];
          })
        ]
      );
    };
}
