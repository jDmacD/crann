{ inputs, config, ... }: {
  flake.homeConfigurations.test = inputs.home-manager.lib.homeManagerConfiguration {
    pkgs = inputs.nixpkgs.legacyPackages.x86_64-linux;
    extraSpecialArgs = { inherit inputs; };
    modules = [
      config.flake.modules.homeManager.niri
      {
        home.username = "test";
        home.homeDirectory = "/home/test";
        home.stateVersion = "24.05";

        crann.niri.extraSettings = {
          workspaces = {
            "all" = { };
          };
        };
      }
    ];
  };
}
