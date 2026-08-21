# Shared option shape for a remote-builder entry, used by both the
# homeManager and nixos `crann.remote-builder` modules.
#
# This is NOT a flake-parts module — the `/_` prefix keeps import-tree from
# auto-importing it (see CLAUDE.md). It's crann's own submodule schema, not a
# re-export of either backend's `nix.buildMachines` type — the two backends
# actually differ (NixOS's takes a singular `system`; home-manager's only
# takes a `systems` list), so each module's `config` block adapts this shared
# shape to whichever one it's writing.
{ lib }:
lib.types.submodule {
  options = {
    hostName = lib.mkOption {
      type = lib.types.str;
      example = "worf.jtec.xyz";
      description = "The hostname of the build machine.";
    };

    system = lib.mkOption {
      type = lib.types.str;
      example = "aarch64-linux";
      description = "The system type this build machine can execute derivations on.";
    };

    sshUser = lib.mkOption {
      type = lib.types.str;
      default = "builder";
      description = ''
        The username to log in as on the remote host. Must be included in
        that host's `nix.settings.trusted-users` — see
        `crann.remote-builder.server` (nixos-class) for the matching
        server-side role.
      '';
    };

    sshKey = lib.mkOption {
      type = lib.types.path;
      example = lib.literalExpression ''config.sops.secrets."builder_ed25519".path'';
      description = ''
        Path to the SSH private key used to authenticate to this build
        machine. Sourced from whatever secret manager the consumer already
        uses — this module has no opinion on it.
      '';
    };

    publicHostKey = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "c3NoLWVkMjU1MTkgQUFBQUMzTn...";
      description = ''
        Base64-encoded public host key of this build machine
        (`base64 -w0 /etc/ssh/ssh_host_ed25519_key.pub` on that machine), so
        the non-interactive SSH connection can verify it without a
        pre-populated known_hosts entry. Leaving this null and relying on the
        ambient known_hosts file is the usual reason distributed builds
        silently fall back to local.
      '';
    };

    protocol = lib.mkOption {
      type = lib.types.enum [
        "ssh"
        "ssh-ng"
      ];
      default = "ssh-ng";
      description = "The protocol used for communicating with the build machine.";
    };

    maxJobs = lib.mkOption {
      type = lib.types.int;
      default = 1;
      description = "The number of concurrent jobs this build machine supports.";
    };

    speedFactor = lib.mkOption {
      type = lib.types.int;
      default = 1;
      description = "Relative speed of this builder compared to others. Higher is faster.";
    };

    supportedFeatures = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [
        "kvm"
        "big-parallel"
      ];
      description = "Features this builder supports.";
    };

    mandatoryFeatures = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Features mandatory for this builder.";
    };
  };
}
