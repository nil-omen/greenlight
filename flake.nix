{
  description = "Greenlight Go Development Environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs { inherit system; };
      in
      {
        devShells.default = pkgs.mkShell {
          name = "greenlight-shell";

          nativeBuildInputs = with pkgs; [
            air # Live reload
            hey # HTTP load generator
            gnumake
            just # Task runner (Alternative to gnumake)
            go
            gcc
            gopls # LSP
            delve # Debugger
            pkg-config # Helper to find C libraries
            upx # Binary compression tool
            # golangci-lint
          ];

          buildInputs = with pkgs; [
            # Libraries go here (openssl, etc.)
          ];

          # Environment Variables
          shellHook = ''
            export CGO_ENABLED=1
            echo "❄️  Development environment loaded!"
          '';
        };
      }
    );
}
