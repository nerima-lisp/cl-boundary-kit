{
  description = "Boundary-oriented testing utilities for Common Lisp";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    cl-weave = {
      url = "github:takeokunn/cl-weave/v0.8.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    cl-prolog = {
      url = "github:takeokunn/cl-prolog/v0.6.0";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.cl-weave.follows = "cl-weave";
    };
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      cl-weave,
      cl-prolog,
      ...
    }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-darwin"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
      sourceRegistry = "${cl-weave}//:${cl-prolog}//:${self}//";
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        rec {
          cl-boundary-kit = pkgs.sbcl.buildASDFSystem {
            pname = "cl-boundary-kit";
            version = "0.4.0";
            src = self;
            systems = [ "cl-boundary-kit" ];
          };
          default = cl-boundary-kit;
        }
      );

      checks = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          runCheck =
            {
              name,
              coverage ? false,
            }:
            pkgs.runCommand name
              {
                nativeBuildInputs = [ pkgs.sbcl ];
                CL_SOURCE_REGISTRY = sourceRegistry;
              }
              ''
                export HOME="$TMPDIR/home"
                mkdir -p "$HOME" "$out"
                export CL_BOUNDARY_KIT_REPORT="$out/report.json"
                ${
                  if coverage then
                    ''
                      export CL_BOUNDARY_KIT_COVERAGE=1
                      export CL_BOUNDARY_KIT_COVERAGE_DATA="$out/coverage.dat"
                      export CL_BOUNDARY_KIT_COVERAGE_REPORT="$out/coverage-html/"
                    ''
                  else
                    ""
                }
                if ! sbcl --script ${self}/nix/ci-runner.lisp; then
                  cat "$CL_BOUNDARY_KIT_REPORT"
                  exit 1
                fi
                ${
                  if coverage then
                    ''
                      ${pkgs.perl}/bin/perl ${self}/nix/check-coverage.pl \
                        "$out/coverage-html/cover-index.html" 80 \
                        | tee "$out/coverage-summary.txt"
                    ''
                  else
                    ""
                }
              '';
        in
        rec {
          checkout-tests =
            pkgs.runCommand "cl-boundary-kit-checkout-tests"
              {
                nativeBuildInputs = [ pkgs.sbcl ];
                CL_SOURCE_REGISTRY = sourceRegistry;
              }
              ''
                export HOME="$TMPDIR/home"
                mkdir -p "$HOME" "$out"
                sbcl --script ${self}/run-tests.lisp
                touch "$out/passed"
              '';
          machine-report = runCheck { name = "cl-boundary-kit-machine-report"; };
          coverage = runCheck {
            name = "cl-boundary-kit-coverage";
            coverage = true;
          };
          default = checkout-tests;
        }
      );

      apps = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          test = pkgs.writeShellApplication {
            name = "cl-boundary-kit-test";
            runtimeInputs = [ pkgs.sbcl ];
            text = ''
              export CL_SOURCE_REGISTRY="${sourceRegistry}"
              exec sbcl --script ${self}/run-tests.lisp
            '';
          };
        in
        {
          default = {
            type = "app";
            program = "${test}/bin/cl-boundary-kit-test";
          };
          test = {
            type = "app";
            program = "${test}/bin/cl-boundary-kit-test";
          };
        }
      );

      devShells = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.mkShell {
            packages = [
              pkgs.sbcl
            ];
            CL_SOURCE_REGISTRY = sourceRegistry;
          };
        }
      );
    };
}
