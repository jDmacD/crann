# Permanent test host — a single NixOS system that exercises crann's
# nixos-class modules and the integrated (useGlobalPkgs) home-manager path, plus
# a standalone homeConfigurations.test-home that exercises the homeManager-class
# modules on their own. The integrated path is deliberate: that's the case
# crann's portability rules are written for.
#
#   nix eval  .#nixosConfigurations.test.config.programs.steam.enable
#   nix eval  .#nixosConfigurations.test.config.programs.niri.enable
#   nix eval  .#nixosConfigurations.test.config.home-manager.users.test.programs.niri.settings.binds --json
#   nix build .#nixosConfigurations.test.config.system.build.toplevel
#   nix build .#homeConfigurations.test-home.activationPackage
#
# The bootloader / fileSystems / user / stateVersion below are throwaway stubs
# so a bare nixosSystem evaluates; unfree is allowed here (in the host, never in
# a feature module) because Steam is unfree.
{ inputs, config, ... }:
{
  # Standalone home-manager, exercising the homeManager-class niri module (the
  # entry point for non-NixOS home-manager). On NixOS the nixos module owns the
  # niri home config instead — see the note in the system config below.
  flake.homeConfigurations.test-home = inputs.home-manager.lib.homeManagerConfiguration {
    pkgs = inputs.nixpkgs.legacyPackages.x86_64-linux;
    extraSpecialArgs = { inherit inputs; };
    modules = [
      config.flake.modules.homeManager.niri
      {
        home.username = "test";
        home.homeDirectory = "/home/test";
        home.stateVersion = "26.05";
      }
    ];
  };

  flake.nixosConfigurations.test = inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    specialArgs = { inherit inputs; };
    modules = [
      config.flake.modules.nixos.steam
      config.flake.modules.nixos.niri
      config.flake.modules.nixos.noctalia
      inputs.home-manager.nixosModules.home-manager
      {
        # --- system-level (nixos) modules under test ---
        crann.steam.enable = true;

        # niri's system layer. This ALSO configures niri for home-manager users
        # (it injects the settings options + crann's defaults via
        # home-manager.sharedModules), so the test user below does NOT import
        # flake.modules.homeManager.niri — doing both would double-declare
        # programs.niri.*. The standalone home module is exercised separately by
        # flake.homeConfigurations.test-home.
        crann.niri.extraSettings = {
          workspaces = {
            "all" = { };
          };
        };

        # --- home-manager integration ---
        home-manager = {
          useGlobalPkgs = true;
          useUserPackages = true;
          extraSpecialArgs = { inherit inputs; };
          users.test = {
            imports = [
              config.flake.modules.homeManager.noctalia
            ];
            home.stateVersion = "26.05";
          };
        };

        # --- throwaway host stubs so the system evaluates ---
        nixpkgs.config.allowUnfree = true;
        # Required by home-manager's xdg.portal under the NixOS module +
        # useUserPackages (niri pulls in a portal); asserted otherwise.
        environment.pathsToLink = [
          "/share/applications"
          "/share/xdg-desktop-portal"
        ];
        users.users.test = {
          isNormalUser = true;
          home = "/home/test";
        };
        boot.loader.grub.enable = false;
        fileSystems."/" = {
          device = "none";
          fsType = "tmpfs";
        };
        system.stateVersion = "26.05";
      }
    ];
  };
}
