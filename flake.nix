{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/79386e0686b21452da450490c7ac464ecf067cf1";

    flake-parts.url = "github:hercules-ci/flake-parts?rev=427bf4bd9435fdf21321c8cc628c24efc14c0f7a";
    import-tree.url = "github:vic/import-tree?rev=4ebb10ae17d5f1ad366e7aef5b92cb8eecf24f69";

    multiverse.url = "github:fzakaria/nixpkgs-multiverse?rev=12dbab7efc581bd661e4f2d7e20ad28afb7cbb9c";

    treefmt-nix = {
      url = "github:numtide/treefmt-nix?rev=ae7910970dddc408fe6ab1c8e4b277bb21d72dc0";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager?rev=c53d643b3737e2fcd04e6cb3b3580ef50b2087a0";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    niri = {
      # url = "github:sodiboo/niri-flake?rev=21777ada91b8b0d91a61c78294467eed232db936";
      url = "github:epireyn/niri-flake?rev=840c81603e4c9e2befc984c2afc7f1f1e0b7a11c";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    noctalia = {
      url = "github:noctalia-dev/noctalia?rev=b67cc05d3f5448e7b4f6e2da4b040ca789d565e8";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    stylix = {
      url = "github:nix-community/stylix?rev=a9e5a76a1b75b137f266e4f445e1eaba82e9783e";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    llm-agents = {
      url = "github:numtide/llm-agents.nix?rev=5aad5f64e621fc35fed0fddcc2b6e17ab662cf78";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    optnix = {
      url = "sourcehut:~watersucks/optnix?rev=d70527982f00bd40d3f49dedfa55cd2bfcceb38c";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    claude-obsidian = {
      url = "github:AgriciDaniel/claude-obsidian?rev=1c1bc49c03a685ee8f5d09c99efe52b42d6673f5";
      flake = false;
    };
  };

  outputs = inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } (inputs.import-tree ./modules);

  nixConfig = {
    extra-substituters = [
      "https://noctalia.cachix.org"
      "https://cache.numtide.com"
      "https://jdmacd.cachix.org"
    ];
    extra-trusted-public-keys = [
      "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="
      "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
      "jdmacd.cachix.org-1:0DcSfXShBIng2EbPW44fxoXjXowKhZZWrbYqcozFhfM="
    ];
  };
}
