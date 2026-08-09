# noctalia, NixOS-class module. noctalia itself is a home-manager program (see
# modules/home/noctalia.nix); this module only contributes the system-level
# noctalia binary cache substituter, so a NixOS consumer that imports it pulls
# noctalia from cachix instead of building it (or copying from a remote
# builder). Mirrors the niri cache handling in modules/nixos/niri.nix.
#
# Note this is a NixOS `nix.settings` contribution: it configures the built
# system's nix daemon, so it applies to rebuilds after activation. To have the
# cache used during the *first* build (before this system is active), a consumer
# also wants it in their flake's top-level `nixConfig` — see CLAUDE.md.
{ ... }:
{
  flake.modules.nixos.noctalia =
    {
      lib,
      config,
      ...
    }:
    let
      cfg = config.crann.noctalia;
    in
    {
      options.crann.noctalia.cache.enable = lib.mkEnableOption "the noctalia binary cache substituter";

      config = lib.mkIf cfg.cache.enable {
        nix.settings = {
          substituters = [ "https://noctalia.cachix.org" ];
          trusted-public-keys = [
            "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="
          ];
        };
      };
    };
}
