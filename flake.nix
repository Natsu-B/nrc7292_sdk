{
  description = "Nix flake for building Newracom NRC7292 standalone SDK";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    nixpkgs-arm-embedded = {
      url = "github:NixOS/nixpkgs/nixos-19.03";
      flake = false;
    };
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, nixpkgs-arm-embedded, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        armPkgs = import nixpkgs-arm-embedded { inherit system; };

        # The SDK ships prebuilt modem objects that do not link with current
        # binutils. Use the older GNU Arm Embedded toolchain family it expects.
        armToolchain = armPkgs.gcc-arm-embedded;

        commonNativeBuildInputs = with pkgs; [
          gnumake
          bash
          coreutils
          findutils
          gnused
          gnugrep
          gawk
          which
          python3
          perl
          git
          file
          xxd

          armToolchain
        ];

        buildNrc7292App =
          {
            appName ? "hello_world",
            sdkTarget ? "nrc7292.sdk.release",
          }:
          pkgs.stdenvNoCC.mkDerivation {
            pname = "nrc7292-${appName}";
            version = "local";

            src = ./.;

            nativeBuildInputs = commonNativeBuildInputs;

            # SDK側がターゲット名やAPP_NAMEをMakefile変数で見る前提。
            # ブランチによって target 名が違う場合は sdkTarget を変える。
            buildPhase = ''
              runHook preBuild

              cd package/standalone

              echo "Using toolchain:"
              command -v arm-none-eabi-gcc || true
              arm-none-eabi-gcc --version || true

              echo "Selecting NRC7292 SDK target: ${sdkTarget}"
              make select target=${sdkTarget}

              echo "Building app: ${appName}"
              make APP_NAME=${appName} -j"$NIX_BUILD_CORES"

              runHook postBuild
            '';

            installPhase = ''
              runHook preInstall

              mkdir -p "$out"

              echo "Collecting build artifacts..."
              find out \
                -type f \
                \( -name '*.elf' \
                   -o -name '*.bin' \
                   -o -name '*.hex' \
                   -o -name '*.map' \
                   -o -name '*.lst' \
                   -o -name '*.img' \
                   -o -name '*.dat' \
                \) \
                -print \
                -exec cp --parents '{}' "$out/" \;

              runHook postInstall
            '';

            dontFixup = true;
          };

        buildSdkScript = pkgs.writeShellApplication {
          name = "build-nrc7292-sdk";
          runtimeInputs = commonNativeBuildInputs;
          text = ''
            set -euo pipefail

            APP_NAME="''${APP_NAME:-hello_world}"
            SDK_TARGET="''${SDK_TARGET:-nrc7292.sdk.release}"

            cd package/standalone

            echo "Selecting target: $SDK_TARGET"
            make select target="$SDK_TARGET"

            echo "Building app: $APP_NAME"
            make APP_NAME="$APP_NAME" -j"$(nproc)"
          '';
        };
      in
      {
        packages = {
          default = buildNrc7292App {
            appName = "hello_world";
          };

          hello_world = buildNrc7292App {
            appName = "hello_world";
          };

          sample_arducam = buildNrc7292App {
            appName = "sample_arducam";
          };

          sample_tcp_client = buildNrc7292App {
            appName = "sample_tcp_client";
          };
        };

        apps.default = {
          type = "app";
          program = "${buildSdkScript}/bin/build-nrc7292-sdk";
        };

        devShells.default = pkgs.mkShell {
          packages = commonNativeBuildInputs ++ [
            buildSdkScript
          ];

          shellHook = ''
            echo "NRC7292 standalone SDK shell"
            echo
            echo "Examples:"
            echo "  build-nrc7292-sdk"
            echo "  APP_NAME=sample_arducam build-nrc7292-sdk"
            echo "  SDK_TARGET=nrc7292.sdk.release APP_NAME=hello_world build-nrc7292-sdk"
            echo
            echo "Toolchain:"
            command -v arm-none-eabi-gcc || true
            arm-none-eabi-gcc --version | head -n 1 || true
          '';
        };
      });
}
