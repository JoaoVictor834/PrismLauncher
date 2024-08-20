{
  description = "A custom launcher for Minecraft that allows you to easily manage multiple installations of Minecraft at once (Fork of MultiMC)";

  nixConfig = {
    extra-substituters = [ "https://cache.garnix.io" ];
    extra-trusted-public-keys = [ "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g=" ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    libnbtplusplus = {
      url = "github:PrismLauncher/libnbtplusplus";
      flake = false;
    };

    /*
      Inputs below this are optional and can be removed

      ```
      {
        inputs.prismlauncher = {
          url = "github:PrismLauncher/PrismLauncher";
          inputs = {
      	    flake-compat.follows = "";
          };
        };
      }
      ```
    */

    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      libnbtplusplus,
      ...
    }:
    let
      inherit (nixpkgs) lib;

      # While we only officially support aarch and x86_64 on Linux and MacOS,
      # we expose a reasonable amount of other systems for users who want to
      # build for most exotic platforms
      systems = lib.systems.flakeExposed;

      forAllSystems = lib.genAttrs systems;
      nixpkgsFor = forAllSystems (system: nixpkgs.legacyPackages.${system});
    in
    {
      devShells = forAllSystems (
        system:
        let
          pkgs = nixpkgsFor.${system};
        in
        {
          default = pkgs.mkShell {
            inputsFrom = [ self.packages.${system}.prismlauncher-unwrapped ];
            buildInputs = with pkgs; [
              ccache
              ninja
            ];
          };
        }
      );

      formatter = forAllSystems (system: nixpkgsFor.${system}.nixfmt-rfc-style);

      overlays.default =
        final: prev:
        let
          version = builtins.substring 0 8 self.lastModifiedDate or "dirty";
        in
        {
          prismlauncher-unwrapped = prev.callPackage ./nix/unwrapped.nix { inherit libnbtplusplus version; };

          prismlauncher = final.callPackage ./nix/wrapper.nix { };
        };

      packages = forAllSystems (
        system:
        let
          pkgs = nixpkgsFor.${system};

          prismPackages = lib.makeScope pkgs.newScope (final: self.overlays.default final pkgs);
        in
        {
          inherit (prismPackages) prismlauncher-unwrapped prismlauncher;
          default = prismPackages.prismlauncher;
        }
      );
    };
}
