{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/1945d8502d2ce810a8306d410dedafb4c20971b5";

    flake-parts.url = "github:hercules-ci/flake-parts?rev=024633cd702b10285db5cb19b40ad48d2399ba60";
    import-tree.url = "github:vic/import-tree?rev=eb1b52eaecc57f7c136d07ae8a93e724dfecac46";

    multiverse.url = "github:fzakaria/nixpkgs-multiverse?rev=5aaa057e9eac1d3bc971d2f5a3d750d6c63b2874";

    treefmt-nix = {
      url = "github:numtide/treefmt-nix?rev=ae7910970dddc408fe6ab1c8e4b277bb21d72dc0";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager?rev=c216bf5a1f173b0481bd5c8c489ebe5595ecc68c";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    niri = {
      # url = "github:sodiboo/niri-flake?rev=21777ada91b8b0d91a61c78294467eed232db936";
      url = "github:epireyn/niri-flake?rev=ec2063483ea6d98c71d0e7467b5c065f3ba1ecb8";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    noctalia = {
      url = "github:noctalia-dev/noctalia?rev=40a82f21ab5f135f4324b1862f7b7732af581856";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    stylix = {
      url = "github:nix-community/stylix?rev=2856c4c6a845b9bec98828ef197abe176e4806bb";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    llm-agents = {
      url = "github:numtide/llm-agents.nix?rev=ea188d2f072e0ec8d5b71245e228803672801a22";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    optnix = {
      url = "sourcehut:~watersucks/optnix?rev=d70527982f00bd40d3f49dedfa55cd2bfcceb38c";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    bun2nix = {
      url = "github:nix-community/bun2nix?rev=0f2a1f0b6f42cebe3b149bf62d38754c5e0e9729";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-parts.follows = "flake-parts";
      inputs.treefmt-nix.follows = "treefmt-nix";
    };
    claude-obsidian = {
      url = "github:AgriciDaniel/claude-obsidian?rev=2e545563172f97f02ecaaaab376ceea1246a0583";
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
