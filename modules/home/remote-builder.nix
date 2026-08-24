# Distributed Nix builds, homeManager-class module — the client role only
# (dispatch builds to remote machines), for a standalone (non-NixOS)
# home-manager consumer. It writes `~/.config/nix/machines` and
# `nix.settings.builders`/`builders-use-substitutes` via home-manager's own
# `nix.buildMachines`/`nix.settings` (imported by every home-manager config;
# see modules/misc/nix/{default,remote-build}.nix upstream).
#
# There is no server role here (unlike the nixos-class sibling,
# modules/nixos/remote-builder.nix) — accepting builds means a system user
# plus `nix.settings.trusted-users`, which home-manager can't manage.
#
# Shares its machine option shape with the nixos-class module via
# modules/_lib/remote-builder-machine.nix. One real difference from that
# sibling: when running under the multi-user Nix daemon (home-manager
# integrated into a NixOS/darwin system, `useGlobalPkgs = true`), the daemon
# only honors settings like `builders` from a user's nix.conf if that user is
# listed in the *system's* `nix.settings.trusted-users` — otherwise this
# module's config is silently ignored for daemon-mediated builds. It takes
# effect unconditionally only for a genuinely standalone, single-user Nix
# install (no daemon), or for a trusted user.
{ ... }:
{
  flake.modules.homeManager.remote-builder =
    {
      lib,
      config,
      ...
    }:
    let
      cfg = config.crann.remote-builder;

      machineSubmodule = import ../_lib/remote-builder-machine.nix { inherit lib; };
    in
    {
      options.crann.remote-builder = {
        enable = lib.mkEnableOption "dispatching Nix builds to remote build machines";

        machines = lib.mkOption {
          type = lib.types.listOf machineSubmodule;
          default = [ ];
          description = "Remote build machines this user dispatches Nix builds to.";
        };

        useSubstitutes = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = ''
            Whether build machines are allowed to use their own substituters
            to obtain build dependencies, rather than always fetching them
            from this host. Useful when a builder has a faster/closer
            connection to the binary cache than this host does.
          '';
        };
      };

      config = lib.mkIf cfg.enable {
        nix.distributedBuilds = true;
        nix.settings.builders-use-substitutes = cfg.useSubstitutes;
        nix.buildMachines = map (m: {
          inherit (m)
            hostName
            sshUser
            sshKey
            publicHostKey
            protocol
            maxJobs
            speedFactor
            supportedFeatures
            mandatoryFeatures
            ;
          systems = [ m.system ];
        }) cfg.machines;
      };
    };
}
