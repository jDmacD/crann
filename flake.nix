{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/79386e0686b21452da450490c7ac464ecf067cf1";

    flake-parts.url = "github:hercules-ci/flake-parts?rev=31729ca8cbdb4fa927b34e5f4353e6a83f39e993";
    import-tree.url = "github:vic/import-tree?rev=eb1b52eaecc57f7c136d07ae8a93e724dfecac46";

    multiverse.url = "github:fzakaria/nixpkgs-multiverse?rev=a7fcee010cb377422f9d5754be525bdf2a6be5e2";

    treefmt-nix = {
      url = "github:numtide/treefmt-nix?rev=ae7910970dddc408fe6ab1c8e4b277bb21d72dc0";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager?rev=2c0350c759688177331b8f5242311fae8877bdb3";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    niri = {
      # url = "github:sodiboo/niri-flake?rev=21777ada91b8b0d91a61c78294467eed232db936";
      url = "github:epireyn/niri-flake?rev=ce231a4c6752fc90c2cb34dcb781511dafada204";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    noctalia = {
      url = "github:noctalia-dev/noctalia?rev=d6607b4eafbb92f6d494ebed3e296d4b741c0b58";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    stylix = {
      url = "github:nix-community/stylix?rev=5e3809851f486e7fc7e84b40f174c74b60ecc784";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    llm-agents = {
      url = "github:numtide/llm-agents.nix?rev=30e001e67438ab6ba024fa8d4f2e9be0ba7548af";
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
