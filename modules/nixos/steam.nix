# Steam, migrated from blueprint. NixOS-class module: enables the Steam
# program (with Remote Play / dedicated-server / LAN-transfer firewall holes),
# a gamescope session, and gamemode.
#
# Note: `programs.steam` pulls unfree packages. Per crann's portability rules
# this module does NOT set `nixpkgs.config.allowUnfree` — the consuming host
# must allow unfree itself.
#
# See CLAUDE.md for the conventions this follows.
{ ... }:
{
  flake.modules.nixos.steam =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    let
      cfg = config.crann.steam;
    in
    {
      options.crann.steam = {

        enable = lib.mkEnableOption "Steam, gamescope session, and gamemode";

        package = lib.mkOption {
          type = lib.types.package;
          default = pkgs.steam;
          defaultText = lib.literalExpression "pkgs.steam";
          description = "The Steam package to use.";
        };

        gamescope = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Register a gamescope session for Steam Big Picture.";
          };
          args = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [
              "--mangoapp"
              "--hdr-enabled"
            ];
            description = "Arguments passed to the gamescope session.";
          };
        };

        gamemode.enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Enable Feral GameMode.";
        };
      };

      config = lib.mkIf cfg.enable {

        programs.steam = {
          enable = true;
          package = cfg.package;
          remotePlay.openFirewall = true; # Open ports in the firewall for Steam Remote Play
          dedicatedServer.openFirewall = true; # Open ports in the firewall for Source Dedicated Server
          localNetworkGameTransfers.openFirewall = true; # Open ports in the firewall for Steam Local Network Game Transfers
          gamescopeSession = {
            enable = cfg.gamescope.enable;
            args = cfg.gamescope.args;
          };
        };

        programs.gamemode.enable = cfg.gamemode.enable;
      };
    };
}
