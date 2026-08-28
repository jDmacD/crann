{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/79386e0686b21452da450490c7ac464ecf067cf1";

    flake-parts.url = "github:hercules-ci/flake-parts?rev=9d0d87172c374f89da73c1cfe6d81ae62feac1f1";
    import-tree.url = "github:vic/import-tree?rev=4ebb10ae17d5f1ad366e7aef5b92cb8eecf24f69";

    multiverse.url = "github:fzakaria/nixpkgs-multiverse?rev=9e5495d75374cd16ad3b5470bb6810288086698c";

    treefmt-nix = {
      url = "github:numtide/treefmt-nix?rev=ae7910970dddc408fe6ab1c8e4b277bb21d72dc0";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager?rev=99c9ec63390f1d8c14d95d9e8b17cc29cfbd4e11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    niri = {
      # url = "github:sodiboo/niri-flake?rev=21777ada91b8b0d91a61c78294467eed232db936";
      url = "github:epireyn/niri-flake?rev=378a718a5c812a2562a30de0a4f14829c627dcf2";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    noctalia = {
      url = "github:noctalia-dev/noctalia?rev=7fd9f7bfa9604022b9de311b30a3da0c2c4415de";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    stylix = {
      url = "github:nix-community/stylix?rev=a9e5a76a1b75b137f266e4f445e1eaba82e9783e";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    llm-agents = {
      url = "github:numtide/llm-agents.nix?rev=1c66a00ce5a9a98e7bfc94647cfbd49e1b8d30cd";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    optnix = {
      url = "sourcehut:~watersucks/optnix?rev=d70527982f00bd40d3f49dedfa55cd2bfcceb38c";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    claude-obsidian = {
      url = "github:AgriciDaniel/claude-obsidian?rev=ad67087cad22ad84cc3288f915588ae42c0c2b44";
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
