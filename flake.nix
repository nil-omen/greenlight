# Offline-First Flake
#
# If your network is flaky or down, use:
#   nix develop --offline
#
# To load from another directory (before direnv triggers):
#   nix develop ~/projects/greenlight --offline
#   # or
#   nix develop path:~/projects/greenlight --offline
#
# This skips the freshness check and uses the cached flake.lock inputs directly.
# The inputs below are pinned to direct GitHub URLs (not indirect registry names)
# to avoid querying the global flake registry at install.determinate.systems.
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
            jq # just to play with json responses
            (go-migrate.overrideAttrs { tags = [ "postgres" "pgx" "pgx5" ]; }) # Database migrations
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
