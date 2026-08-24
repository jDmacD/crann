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
# The k3s package is pinned via nixpkgs-multiverse to 1.35.6+k3s1 — the
# `k3s_1_35` attribute, matching `k3s --version` on the fleet's actual nodes
# (verified against picard.lan's `kubectl get nodes`) — rather than
# `pkgs.k3s`/`pkgs.k3s_1_35`, since a consumer's own nixpkgs pin frequently
# lacks the minor version line a running cluster needs (this is exactly what
# forced nix-pi's original module to reach into a second nixpkgs input for
# `k3s_1_35`). `crann.k3s.package` stays overridable for a host that wants a
# different line or its own nixpkgs' build.
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
    in
    {
      imports = [ inputs.multiverse.nixosModules.default ];

      options.crann.k3s = {
        enable = lib.mkEnableOption "the k3s Kubernetes distribution";

        package = lib.mkOption {
          type = lib.types.package;
          default = config.multiverse.pinned.k3s_1_35;
          defaultText = lib.literalExpression "config.multiverse.pinned.k3s_1_35";
          description = ''
            The k3s package to use. Defaults to 1.35.6+k3s1, pinned via
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
          description = "Extra flags appended after the base --node-name flag.";
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
            multiverse.pins.k3s_1_35 = "1.35.6+k3s1";

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
              extraFlags = toString ([ "--node-name ${config.networking.hostName}" ] ++ cfg.extraFlags);
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
