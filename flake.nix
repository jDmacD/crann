{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/6cebe93d25f5e7de873ae4be07bdb81e110ac51d";

    flake-parts.url = "github:hercules-ci/flake-parts?rev=31729ca8cbdb4fa927b34e5f4353e6a83f39e993";
    import-tree.url = "github:vic/import-tree?rev=eb1b52eaecc57f7c136d07ae8a93e724dfecac46";

    multiverse.url = "github:fzakaria/nixpkgs-multiverse?rev=fba6691c6c064212a8683ba81708076c7f8f683c";

    treefmt-nix = {
      url = "github:numtide/treefmt-nix?rev=ae7910970dddc408fe6ab1c8e4b277bb21d72dc0";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager?rev=7b4c5ec4bedaf1e062bbc1bcaeddbc6bd242aa1b";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    niri = {
      # url = "github:sodiboo/niri-flake?rev=21777ada91b8b0d91a61c78294467eed232db936";
      url = "github:epireyn/niri-flake?rev=9bb9b4b84ed60d2cb038ef4fcda9bf5af79cf7e9";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    noctalia = {
      url = "github:noctalia-dev/noctalia?rev=9536ce32f4989fda29714d514de019ce7c896f21";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    stylix = {
      url = "github:nix-community/stylix?rev=abff36bfab11cbdcd0723f41c1b0921e211be6ac";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    llm-agents = {
      url = "github:numtide/llm-agents.nix?rev=2e9c743bc337136b0714f27dae05d575ad81f0ee";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    optnix = {
      url = "sourcehut:~watersucks/optnix?rev=d70527982f00bd40d3f49dedfa55cd2bfcceb38c";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    claude-obsidian = {
      url = "github:AgriciDaniel/claude-obsidian?rev=32ac5a02c4e082e4a5628ca810776375e134708e";
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
