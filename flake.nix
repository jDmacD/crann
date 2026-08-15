{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/0e251e24a4f24e036a084b6b4b2d2491af4167f4";

    flake-parts.url = "github:hercules-ci/flake-parts?rev=427bf4bd9435fdf21321c8cc628c24efc14c0f7a";
    import-tree.url = "github:vic/import-tree?rev=4ebb10ae17d5f1ad366e7aef5b92cb8eecf24f69";

    wrapper-modules.url = "github:BirdeeHub/nix-wrapper-modules?rev=6e7f66fa2cdf4d63162580b438f7fcf87c28a46f";

    treefmt-nix = {
      url = "github:numtide/treefmt-nix?rev=ae7910970dddc408fe6ab1c8e4b277bb21d72dc0";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager?rev=83b7606dcf44abe3a94b86e8bb2b3355d22e8797";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    niri = {
      # url = "github:sodiboo/niri-flake";
      url = "github:epireyn/niri-flake?rev=03d3e0da7ac9a74f6d25b2d101d03c3a204590f4";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    noctalia = {
      url = "github:noctalia-dev/noctalia?rev=5175780faf9a72e55e0cec072e3b2a747c7406ba";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    stylix = {
      url = "github:nix-community/stylix?rev=1e6ccadeda179d96728b4a9f20fc9d4dcf6b6059";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    llm-agents = {
      url = "github:numtide/llm-agents.nix?rev=31cb8a71dc362627fae92f9a8a13819f34a36d92";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } (inputs.import-tree ./modules);

  nixConfig = {
    extra-substituters = [
      "https://noctalia.cachix.org"
      "https://cache.numtide.com"
    ];
    extra-trusted-public-keys = [
      "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="
      "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
    ];
  };
}
