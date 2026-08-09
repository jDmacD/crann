# Kubernetes client tooling, home-manager class.
#
# Mostly a package bag, so it is exposed as one overridable `packages` list
# plus an additive `extraPackages`, rather than a per-tool enable for each
# binary. The default list is the set common to crann's consumers;
# local-cluster tooling (k3d and friends) belongs in `extraPackages` on the
# hosts that actually want it.
{ ... }:
{
  flake.modules.homeManager.kubernetes =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    let
      cfg = config.crann.kubernetes;
    in
    {

      options.crann.kubernetes = {
        enable = lib.mkEnableOption "kubernetes";

        packages = lib.mkOption {
          type = lib.types.listOf lib.types.package;
          default = with pkgs; [
            kubectl
            kustomize
            kubernetes-helm
            kubecm
            kubeswitch
            kubectl-cnpg
            cilium-cli
            hubble
            argocd
          ];
          defaultText = lib.literalExpression "[ kubectl kustomize kubernetes-helm kubecm kubeswitch kubectl-cnpg cilium-cli hubble argocd ]";
          description = "The kubernetes client tools to install. Replaces crann's default set.";
        };

        extraPackages = lib.mkOption {
          type = lib.types.listOf lib.types.package;
          default = [ ];
          example = lib.literalExpression "[ pkgs.k3d ]";
          description = "Extra packages installed alongside `packages`.";
        };

        k9s = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Whether to install and configure k9s.";
          };
          extraSettings = lib.mkOption {
            type = lib.types.attrsOf lib.types.anything;
            default = { };
            description = "Extra k9s settings merged over crann's defaults.";
          };
        };
      };

      config = lib.mkIf cfg.enable {

        home.packages = cfg.packages ++ cfg.extraPackages;

        programs.k9s = lib.mkIf cfg.k9s.enable {
          enable = true;
          settings = cfg.k9s.extraSettings;
        };
      };
    };
}
