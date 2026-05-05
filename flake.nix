{
  description = "Home Manager module for declarative FreeTube configuration with profile/subscription support";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager }:
    let
      freetube = import ./modules/freetube.nix;
    in
    {
      homeManagerModules.freetube = freetube;
      homeManagerModules.default  = freetube;
    };
}
