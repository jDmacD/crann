# k3s-nvidia, NixOS-class module. Wires the NVIDIA container runtime into a
# k3s agent's containerd, for GPU-scheduled workloads. Layers on top of
# `crann.k3s` (asserted enabled) rather than folding into it, since GPU
# support is optional and orthogonal to running k3s at all.
#
# `hardware.nvidia-container-toolkit` already exists in nixpkgs, but only
# wires up Docker/Podman's CDI integration — k3s's bundled containerd needs
# its own runtime stanza and RuntimeClass, which is what this module adds.
#
# The nvidia-container-toolkit package here is pinned via nixpkgs-multiverse
# to 1.18.0 rather than defaulting to `pkgs.nvidia-container-toolkit`: that's
# the version validated in blueprint's original k3s-agent-gpu module (pulled
# there from a separate nixos-25.11 pin, because the toolkit moves faster
# than most consumers' nixpkgs carries a working build of it). The
# multiverse module only ever installs derivations — see its docs — so this
# stays safe under `home-manager.useGlobalPkgs`.
# `crann.k3s-nvidia.package` stays overridable for a host that wants a
# different version or its own nixpkgs' build.
{ inputs, ... }:
{
  flake.modules.nixos.k3s-nvidia =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    let
      cfg = config.crann.k3s-nvidia;
    in
    {
      imports = [ inputs.multiverse.nixosModules.default ];

      options.crann.k3s-nvidia = {
        enable = lib.mkEnableOption "the NVIDIA container runtime for k3s (GPU-scheduled agent workloads)";

        package = lib.mkOption {
          type = lib.types.package;
          default = config.multiverse.pinned.nvidia-container-toolkit;
          defaultText = lib.literalExpression "config.multiverse.pinned.nvidia-container-toolkit";
          description = ''
            The nvidia-container-toolkit package. Defaults to 1.18.0, pinned
            via nixpkgs-multiverse rather than the consumer's own nixpkgs —
            the toolkit moves faster than most nixpkgs pins carry a working
            build of it.
          '';
        };
      };

      config = lib.mkIf cfg.enable {
        assertions = [
          {
            assertion = config.crann.k3s.enable;
            message = "crann.k3s-nvidia requires crann.k3s.enable = true.";
          }
        ];

        multiverse.enable = true;
        multiverse.pins.nvidia-container-toolkit = "1.18.0";

        hardware.nvidia-container-toolkit = {
          enable = true;
          package = cfg.package;
          mount-nvidia-executables = true;
        };

        systemd.tmpfiles.rules = [
          "L+ /usr/bin/nvidia-ctk - - - - ${lib.getExe' cfg.package "nvidia-ctk"}"
        ];

        services.k3s.containerdConfigTemplate = ''
          {{ template "base" . }}

          [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.nvidia]
            privileged_without_host_devices = false
            runtime_engine = ""
            runtime_root = ""
            runtime_type = "io.containerd.runc.v2"

          [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.nvidia.options]
            BinaryName = "${lib.getOutput "tools" cfg.package}/bin/nvidia-container-runtime"
        '';

        environment.systemPackages = [
          cfg.package
          pkgs.libnvidia-container
          pkgs.runc
        ];

        environment.etc."nvidia/nvidia.yaml".text = ''
          apiVersion: node.k8s.io/v1
          handler: nvidia
          kind: RuntimeClass
          metadata:
            labels:
              app.kubernetes.io/component: gpu-operator
            name: nvidia
        '';
      };
    };
}
