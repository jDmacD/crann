# Permanent test host — a single NixOS system that exercises BOTH crann's
# nixos-class modules and its homeManager-class modules (the latter via the
# home-manager NixOS module). Running the home modules through the integrated
# `useGlobalPkgs` path is deliberate: that's the case crann's portability rules
# are written for.
#
#   nix eval  .#nixosConfigurations.test.config.programs.steam.enable
#   nix eval  .#nixosConfigurations.test.config.home-manager.users.test.programs.niri.enable
#   nix build .#nixosConfigurations.test.config.system.build.toplevel
#
# The bootloader / fileSystems / user / stateVersion below are throwaway stubs
# so a bare nixosSystem evaluates; unfree is allowed here (in the host, never in
# a feature module) because Steam is unfree.
{ inputs, config, ... }:
{
  flake.nixosConfigurations.test = inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    specialArgs = { inherit inputs; };
    modules = [
      config.flake.modules.nixos.steam
      inputs.home-manager.nixosModules.home-manager
      {
        # --- system-level (nixos) modules under test ---
        crann.steam.enable = true;

        # --- home-manager integration ---
        home-manager = {
          useGlobalPkgs = true;
          useUserPackages = true;
          extraSpecialArgs = { inherit inputs; };
          users.test = {
            imports = [
              config.flake.modules.homeManager.niri
              config.flake.modules.homeManager.noctalia
            ];
            home.stateVersion = "26.05";

            crann.niri.extraSettings = {
              workspaces = {
                "all" = { };
              };
            };
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
