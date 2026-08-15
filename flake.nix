{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/0e251e24a4f24e036a084b6b4b2d2491af4167f4";

    flake-parts.url = "github:hercules-ci/flake-parts?rev=427bf4bd9435fdf21321c8cc628c24efc14c0f7a";
    import-tree.url = "github:vic/import-tree?rev=4ebb10ae17d5f1ad366e7aef5b92cb8eecf24f69";

    multiverse.url = "github:fzakaria/nixpkgs-multiverse?rev=8891b2b13e649a13e5c5a254ff8e2eafd697d75d";

    treefmt-nix = {
      url = "github:numtide/treefmt-nix?rev=ae7910970dddc408fe6ab1c8e4b277bb21d72dc0";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager?rev=83b7606dcf44abe3a94b86e8bb2b3355d22e8797";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    niri = {
      # url = "github:sodiboo/niri-flake?rev=fe2febc4d7f7da05078676c1f062d1b182a4f2ad";
      url = "github:epireyn/niri-flake?rev=fe2febc4d7f7da05078676c1f062d1b182a4f2ad";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    noctalia = {
      url = "github:noctalia-dev/noctalia?rev=b67cc05d3f5448e7b4f6e2da4b040ca789d565e8";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    stylix = {
      url = "github:nix-community/stylix?rev=1e6ccadeda179d96728b4a9f20fc9d4dcf6b6059";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    llm-agents = {
      url = "github:numtide/llm-agents.nix?rev=b4a645976fff76ef94dd60b7d4f9deaa216f40bd";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    optnix = {
      url = "sourcehut:~watersucks/optnix?rev=d70527982f00bd40d3f49dedfa55cd2bfcceb38c";
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
