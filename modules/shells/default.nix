# Default `nix develop` shell for working on crann itself.
{ ... }:
{
  perSystem =
    { config, pkgs, ... }:
    let
      # Example inline script: `writeShellApplication` wraps a script with its
      # runtimeInputs on PATH and shellchecks it at build time. This one just
      # exercises jinja2-cli on a template built with `writeText` — swap the
      # body out for whatever one-off dev tooling the shell actually needs.
      new-homemanager = pkgs.writeShellApplication {
        name = "new-homemanager";
        # `treefmt` needs to be on this script's own PATH — being in the
        # devShell's packages list doesn't carry over to a wrapped script.
        runtimeInputs = [
          pkgs.jinja2-cli
          pkgs.git
          config.treefmt.build.wrapper
        ];
        text = ''
          name=$1
          jinja2 -D type="homeManager" -D name="$name" modules/templates/_module.nix -o "modules/home/$name.nix"
          git add "modules/home/$name.nix"
          treefmt "modules/home/$name.nix"
          git add "modules/home/$name.nix"
        '';
      };
      new-nixos = pkgs.writeShellApplication {
        name = "new-nixos";
        # `treefmt` needs to be on this script's own PATH — being in the
        # devShell's packages list doesn't carry over to a wrapped script.
        runtimeInputs = [
          pkgs.jinja2-cli
          pkgs.git
          config.treefmt.build.wrapper
        ];
        text = ''
          name=$1
          jinja2 -D type="nixos" -D name="$name" modules/templates/_module.nix -o "modules/nixos/$name.nix"
          git add "modules/nixos/$name.nix"
          treefmt "modules/nixos/$name.nix"
          git add "modules/nixos/$name.nix"
        '';
      };
      # Builds the test host outputs (see modules/hosts/test.nix) and pushes
      # the results to the jdmacd Cachix cache. Run from picard for the
      # initial push, and by CI (see .github/workflows/check.yml) to keep it
      # updated on every change.
      push-cachix = pkgs.writeShellApplication {
        name = "push-cachix";
        runtimeInputs = [ pkgs.cachix ];
        text = ''
          nix build .#nixosConfigurations.test.config.system.build.toplevel --no-link --print-out-paths | cachix push jdmacd
          nix build .#homeConfigurations.test-home.activationPackage --no-link --print-out-paths | cachix push jdmacd
        '';
      };
    in
    {
      devShells.default = pkgs.mkShell {
        packages = [
          # Same wrapper `nix fmt` uses, so `treefmt` in the shell matches CI.
          config.treefmt.build.wrapper
          pkgs.jinja2-cli
          new-homemanager
          new-nixos
          push-cachix
        ];
      };
    };
}
