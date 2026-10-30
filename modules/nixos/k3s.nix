# k3s, NixOS-class module. A single k3s node — server (control-plane) or
# agent (worker) — selected via `crann.k3s.role`, with the firewall holes,
# join-token secret, and Ceph/Rook storage prerequisites both roles need.
#
# Ported from two fleets that had each grown a near-duplicate copy of this:
# one selected the role from a hardcoded hostname, the other hardcoded a
# fixed agent role and server address. Neither belongs in a reusable module,
# so both became `crann.k3s.role` / `crann.k3s.serverAddr`, set per host.
# Server-only tuning (disabling traefik/flannel/kube-proxy for a Cilium CNI,
# extra --tls-san names, etc.) is likewise not baked in — it goes in
# `crann.k3s.extraFlags` on the server host.
#
# Secret management is deliberately not this module's concern — crann does
# not assume sops (or any other secret manager) is what a consumer uses.
# `crann.k3s.tokenFile` takes a plain path to the cluster join token; wire it
# to `config.sops.secrets."k3s/token".path`, agenix, or whatever the consumer
# already has.
#
# The k3s package comes from nixpkgs-multiverse, pinned to `crann.k3s.version`
# (default 1.35.9+k3s1, matching `k3s --version` on the fleet), rather than
# `pkgs.k3s`/`pkgs.k3s_1_35`: a consumer's own nixpkgs pin frequently lacks
# the minor version line a running cluster needs. The multiverse attribute is
# derived from the version (`k3s_1_35` for 1.35.x), so a host moves k3s by
# changing `version` alone, still through multiverse. `crann.k3s.package`
# stays overridable for a host that wants its own nixpkgs' build.
#
# k3s's own `eviction-hard` sets only the two disk thresholds, which drops
# kubelet's default `memory.available<100Mi`; `crann.k3s.evictionHard`
# restores it (see the option for why it is a CLI flag).
{ inputs, ... }:
{
  flake.modules.nixos.k3s =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    let
      cfg = config.crann.k3s;
      # "1.35.9+k3s1" -> "k3s_1_35", the nixpkgs attribute for that minor line.
      attr = "k3s_" + lib.replaceStrings [ "." ] [ "_" ] (lib.versions.majorMinor cfg.version);
      # `%%` because the flags end up in ExecStart, where `%` is a systemd specifier.
      evictionFlag = lib.optional (cfg.evictionHard != { }) (
        "--kubelet-arg=eviction-hard="
        + lib.concatStringsSep "," (
          lib.mapAttrsToList (k: v: "${k}<${lib.replaceStrings [ "%" ] [ "%%" ] v}") cfg.evictionHard
        )
      );
    in
    {
      imports = [ inputs.multiverse.nixosModules.default ];

      options.crann.k3s = {
        enable = lib.mkEnableOption "the k3s Kubernetes distribution";

        version = lib.mkOption {
          type = lib.types.str;
          default = "1.35.9+k3s1";
          example = "1.35.8+k3s1";
          description = ''
            The k3s version to pin through nixpkgs-multiverse. Must be a version
            multiverse's index has for the matching `k3s_<major>_<minor>`
            attribute.
          '';
        };

        package = lib.mkOption {
          type = lib.types.package;
          default = config.multiverse.pinned.${attr};
          defaultText = lib.literalExpression "config.multiverse.pinned.k3s_<major>_<minor> (from crann.k3s.version)";
          description = ''
            The k3s package to use. Defaults to `version`, pinned via
            nixpkgs-multiverse rather than the consumer's own nixpkgs.
          '';
        };

        role = lib.mkOption {
          type = lib.types.enum [
            "server"
            "agent"
          ];
          default = "server";
          description = "Whether this node is a k3s server (control-plane) or agent (worker).";
        };

        serverAddr = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          example = "https://tpi01.lan:6443";
          description = "The k3s server URL agents join. Required when role is \"agent\"; ignored for servers.";
        };

        tokenFile = lib.mkOption {
          type = lib.types.nullOr lib.types.path;
          default = null;
          example = lib.literalExpression ''config.sops.secrets."k3s/token".path'';
          description = ''
            Path to the cluster join token shared by every node. Sourced
            from whatever secret manager the consumer already uses — this
            module has no opinion on it.
          '';
        };

        extraFlags = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          example = [
            "--disable=traefik"
            "--flannel-backend=none"
            "--tls-san foo.lan"
          ];
          description = "Extra flags appended after the base --node-name and eviction flags.";
        };

        evictionHard = lib.mkOption {
          type = lib.types.attrsOf lib.types.str;
          default = {
            "memory.available" = "100Mi";
            "imagefs.available" = "5%";
            "nodefs.available" = "5%";
          };
          description = ''
            kubelet's hard eviction thresholds, passed as
            `--kubelet-arg=eviction-hard=...`. k3s sets only the two disk
            thresholds, which drops kubelet's default `memory.available<100Mi`;
            the default restores it and repeats k3s's disk thresholds, since the
            flag replaces the whole map. A CLI flag rather than kubelet config,
            because k3s writes its defaults to a kubelet.conf.d drop-in that
            would override it. Set to `{ }` to leave k3s's defaults alone.
          '';
        };

        ceph.enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Bind-mount /lib/modules and enable nbd — required for Ceph/Rook storage on this node.";
        };
      };

      config = lib.mkIf cfg.enable (
        lib.mkMerge [
          {
            assertions = [
              {
                assertion = cfg.role == "agent" -> cfg.serverAddr != null;
                message = "crann.k3s: serverAddr must be set when role is \"agent\".";
              }
              {
                assertion = cfg.tokenFile != null;
                message = "crann.k3s: tokenFile must be set to the cluster join token's path.";
              }
            ];

            multiverse.enable = true;
            multiverse.pins.${attr} = cfg.version;

            networking.firewall.enable = false;
            networking.firewall.checkReversePath = false;
            networking.firewall.allowedTCPPorts = [
              6443 # k3s API server
              10250 # metrics port
              4240 # cilium health
              443
              80
            ];
            networking.firewall.allowedUDPPorts = [
              8472 # flannel/cilium vxlan (inter-node networking)
            ];

            services.k3s = {
              enable = true;
              package = cfg.package;
              role = cfg.role;
              tokenFile = cfg.tokenFile;
              serverAddr = lib.mkIf (cfg.role == "agent") cfg.serverAddr;
              extraFlags = toString (
                [ "--node-name ${config.networking.hostName}" ] ++ evictionFlag ++ cfg.extraFlags
              );
            };
          }
          (lib.mkIf cfg.ceph.enable {
            fileSystems."/lib/modules" = {
              device = "/run/booted-system/kernel-modules/lib/modules";
              fsType = "none";
              options = [ "bind" ];
              depends = [ "/run/booted-system/kernel-modules/lib/modules" ];
            };
            programs.nbd.enable = true;
            environment.systemPackages = [ pkgs.lvm2 ];
          })
        ]
      );
    };
}
