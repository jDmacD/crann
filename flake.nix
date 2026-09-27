{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/307a907beb4cb8fb9d91771c278958dfcf6aa205";

    flake-parts.url = "github:hercules-ci/flake-parts?rev=31729ca8cbdb4fa927b34e5f4353e6a83f39e993";
    import-tree.url = "github:vic/import-tree?rev=eb1b52eaecc57f7c136d07ae8a93e724dfecac46";

    multiverse.url = "github:fzakaria/nixpkgs-multiverse?rev=3349cfa5aa11ec4a66044088b87b37a6f9355af0";

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
      url = "github:epireyn/niri-flake?rev=2bc4bf62da8ca29286fa795dd7d613e85b1c068e";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    noctalia = {
      url = "github:noctalia-dev/noctalia?rev=08c30392b1350b4f3d3fb77e23732560559f1638";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    stylix = {
      url = "github:nix-community/stylix?rev=abff36bfab11cbdcd0723f41c1b0921e211be6ac";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    llm-agents = {
      url = "github:numtide/llm-agents.nix?rev=efb10f28f7242f0330eb06436a672473dc91a2a9";
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
