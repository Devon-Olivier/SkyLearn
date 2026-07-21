{
  description = "A Nix-flake for basic python app development using uv";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs_unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      nixpkgs_unstable,
      flake-utils,
    }:
    # see https://github.com/numtide/flake-utils#eachdefaultsystem--system---attrs
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config = {
            allowUnfree = true;
          };
          overlays = [ ];
        };
        pkgs_unstable = import nixpkgs_unstable {
          inherit system;
          config = {
            allowUnfree = true;
          };
          overlays = [ ];
        };

        ssl_cert_file = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
      in
      {
        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            cacert
            git
            libjpeg
            openssl
            pkg-config
            python314
            ruff
            uv
            zlib
          ];

          # Ensure uv and Python see the CA bundle
          NIX_SSL_CERT_FILE = ssl_cert_file;
          REQUESTS_CA_BUNDLE = ssl_cert_file;
          UV_PYTHON_PREFERENCE = "only-system";
          # According to Gemini
          # The UV_SYSTEM_PYTHON=1 variable (which is the environment
          # equivalent of passing the --system flag) exists for
          # environments where you want to install packages globally
          # and intentionally bypass virtual environments.
          # UV_SYSTEM_PYTHON = 1;

          OPENSSL_DIR = "${pkgs.openssl.dev}";
          OPENSSL_LIB_DIR = "${pkgs.openssl.out}/lib";
          OPENSSL_INCLUDE_DIR = "${pkgs.openssl.dev}/include";
          PKG_CONFIG_PATH = "${pkgs.openssl.dev}/lib/pkgconfig";

          LD_LIBRARY_PATH = "${
            pkgs.lib.makeLibraryPath [
              pkgs.stdenv.cc.cc.lib
              pkgs.libjpeg
              pkgs.openssl
              pkgs.zlib
            ]
          }:$LD_LIBRARY_PATH";

          NIX_LD_LIBRARY_PATH = "${
            pkgs.lib.makeLibraryPath [
              pkgs.stdenv.cc.cc.lib
              pkgs.libjpeg
              pkgs.openssl
              pkgs.zlib
            ]
          }:$NIX_LD_LIBRARY_PATH";

          shellHook = ''
            unset PYTHONPATH

            # Bridge Nix -> standard SSL variable
            export SSL_CERT_FILE="$NIX_SSL_CERT_FILE"

            [ -d .venv ] || uv sync
            . .venv/bin/activate
          '';
        };
      }
    );
}
