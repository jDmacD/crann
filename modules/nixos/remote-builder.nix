# Distributed Nix builds, NixOS-class module. Two independently-enableable
# roles that the same host can hold at once:
#
#   crann.remote-builder        — dispatch builds to remote machines
#                                  (nix.buildMachines / nix.distributedBuilds)
#   crann.remote-builder.server — accept builds from trusted client machines
#                                  (a dedicated "builder" user, trusted-users)
#
# The client role has a homeManager-class sibling (modules/home/remote-builder.nix)
# for standalone (non-NixOS) home-manager consumers, sharing the machine option
# shape from modules/_lib/remote-builder-machine.nix. The server role is
# NixOS-only — creating a system user and accepting SSH logins isn't something
# home-manager can do.
#
# Ported from blueprint's builder-arm.nix / builder-x86.nix / builder-user.nix
# — three near-duplicate files (one per architecture, plus the server-side
# user) that hardcoded one build machine each and a single baked-in
# authorized key. Consolidated here into one machines list and one
# authorizedKeys option so a host can point at as many builders as it needs
# without a new file per machine.
#
# The blueprint version never fully worked: nix.buildMachines has a
# `publicHostKey` field specifically so the root-owned, non-interactive
# nix-daemon SSH connection can verify the remote host key without a
# pre-populated known_hosts file — blueprint's machines left it unset, so the
# first connection had nothing to verify against and the build silently fell
# back to local. `publicHostKey` is surfaced here per-machine
# (`base64 -w0 /etc/ssh/ssh_host_ed25519_key.pub` on the build machine) —
# leave it null only if you've verified root's known_hosts already has an
# entry for the machine.
#
# Secret management is deliberately not this module's concern — same as
# crann.k3s. `sshKey` on each machine takes a plain path to the client's SSH
# private key; wire it to `config.sops.secrets."builder_ed25519".path`,
# agenix, or whatever the consumer already uses. `server.authorizedKeys`
# takes the corresponding public keys directly (public keys aren't secret).
{ ... }:
{
  flake.modules.nixos.remote-builder =
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
          description = "Remote build machines this host dispatches Nix builds to.";
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

        server = {
          enable = lib.mkEnableOption "accepting remote Nix builds from trusted client machines";

          user = lib.mkOption {
            type = lib.types.str;
            default = "builder";
            description = ''
              Name of the local user/group that trusted client machines log
              in as to dispatch builds. Must match `sshUser` on the client's
              `crann.remote-builder.machines` entry for this host.
            '';
          };

          authorizedKeys = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            example = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI... root@surface" ];
            description = ''
              Public keys of client machines allowed to log in as
              `server.user` to dispatch remote builds here. Public keys
              aren't secret, so — unlike `sshKey` — these are plain strings.
            '';
          };
        };
      };

      config = lib.mkMerge [
        (lib.mkIf cfg.enable {
          nix.distributedBuilds = true;
          nix.settings.builders-use-substitutes = cfg.useSubstitutes;
          nix.buildMachines = map (m: {
            inherit (m)
              hostName
              system
              sshUser
              sshKey
              publicHostKey
              protocol
              maxJobs
              speedFactor
              supportedFeatures
              mandatoryFeatures
              ;
          }) cfg.machines;
        })
        (lib.mkIf cfg.server.enable {
          users.users.${cfg.server.user} = {
            isNormalUser = true;
            createHome = false;
            ignoreShellProgramCheck = true;
            group = cfg.server.user;
            openssh.authorizedKeys.keys = cfg.server.authorizedKeys;
          };
          users.groups.${cfg.server.user} = { };
          nix.settings.trusted-users = [ cfg.server.user ];
        })
      ];
    };
}
