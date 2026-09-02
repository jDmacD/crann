{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/79386e0686b21452da450490c7ac464ecf067cf1";

    flake-parts.url = "github:hercules-ci/flake-parts?rev=9d0d87172c374f89da73c1cfe6d81ae62feac1f1";
    import-tree.url = "github:vic/import-tree?rev=e9177dd0d600162a6410ea6019c796cff7a636c3";

    multiverse.url = "github:fzakaria/nixpkgs-multiverse?rev=4e42650d06172b925d85b134fb924ae6d109cf60";

    treefmt-nix = {
      url = "github:numtide/treefmt-nix?rev=ae7910970dddc408fe6ab1c8e4b277bb21d72dc0";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager?rev=b8350fcdf54ccf553e46408053b1ac5b7038c18b";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    niri = {
      # url = "github:sodiboo/niri-flake?rev=21777ada91b8b0d91a61c78294467eed232db936";
      url = "github:epireyn/niri-flake?rev=fba9f478332b6e37a537d536a4fa51ed5941bfe6";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    noctalia = {
      url = "github:noctalia-dev/noctalia?rev=29dab93fdf9091f83f9eec20a20e72e11fc4e6c4";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    stylix = {
      url = "github:nix-community/stylix?rev=5e3809851f486e7fc7e84b40f174c74b60ecc784";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    llm-agents = {
      url = "github:numtide/llm-agents.nix?rev=b7e6d6d4cb01ee1bc704db8e11629adec7e2509c";
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
