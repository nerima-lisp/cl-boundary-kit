{
  description = "Boundary-oriented testing utilities for Common Lisp";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # cl-weave is the deepest sibling, so it owns the single paredit-cli (and
    # therefore the single rust-overlay) node that every other sibling follows.
    cl-weave = {
      url = "github:nerima-lisp/cl-weave/v1.0.1";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    cl-prolog = {
      url = "github:nerima-lisp/cl-prolog/v1.1.0";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.cl-weave.follows = "cl-weave";
      inputs.paredit-cli.follows = "cl-weave/paredit-cli";
    };

    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      cl-weave,
      cl-prolog,
      treefmt-nix,
      ...
    }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-darwin"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
      # Each entry is a checkout root whose .asd sits at the top level, so these
      # are deliberately non-recursive: a `//' entry makes every SBCL process
      # that inherits CL_SOURCE_REGISTRY re-walk all three trees in full before
      # resolving a system it would have found immediately. The checks start one
      # process per examples/*.lisp file, so that scan is paid ~40 times per run.
      # run-tests.lisp builds its own registry the same way.
      sourceRegistry = "${cl-weave}:${cl-prolog}:${self}";
      testTimeoutSeconds = "300";

      # Single source of truth for a package version: the `:version` form in its
      # .asd. A release only ever edits the .asd file and every Nix package
      # (default + docs) follows automatically. Nix regexes are whole-string
      # anchored and `.` never spans newlines, so the version is extracted
      # line-by-line rather than with one multi-line match.
      asdVersion =
        asd:
        let
          lines = nixpkgs.lib.splitString "\n" (builtins.readFile asd);
          versionLine = builtins.head (
            builtins.filter (line: builtins.match "[[:space:]]*:version \"[^\"]*\"" line != null) lines
          );
        in
        builtins.head (builtins.match "[[:space:]]*:version \"([^\"]*)\"" versionLine);

      version = asdVersion ./cl-boundary-kit.asd;
      clWeaveVersion = asdVersion "${cl-weave}/cl-weave.asd";
      clPrologVersion = asdVersion "${cl-prolog}/cl-prolog.asd";

      # treefmt drives `nix fmt` and the `checks.<system>.formatting` gate.
      # Scope is Nix only: nixfmt (RFC-style) is a zero-footgun, low-diff
      # formatter, whereas YAML formatters mangle the GitHub Actions `on:` key
      # and Markdown reformatting would churn the whole docs tree — which the
      # api-doc-* tests read line by line.
      treefmtEval = forAllSystems (
        system:
        treefmt-nix.lib.evalModule nixpkgs.legacyPackages.${system} {
          projectRootFile = "flake.nix";
          programs.nixfmt.enable = true;
        }
      );

      mkDocs =
        pkgs:
        pkgs.stdenvNoCC.mkDerivation {
          pname = "cl-boundary-kit-docs";
          inherit version;
          src = pkgs.lib.fileset.toSource {
            root = ./docs;
            fileset = pkgs.lib.fileset.unions [
              ./docs/mkdocs.yml
              ./docs/src
            ];
          };
          nativeBuildInputs = [ pkgs.python3Packages.mkdocs-material ];
          # Build fully offline: Material for MkDocs bundles all of its assets,
          # so no network access is required inside the Nix sandbox. --strict
          # promotes broken links and unlisted pages to build failures.
          buildPhase = ''
            runHook preBuild
            mkdocs build --strict --config-file mkdocs.yml --site-dir "$out"
            runHook postBuild
          '';
          dontInstall = true;
          meta = {
            description = "Rendered MkDocs (Material) documentation for cl-boundary-kit";
            homepage = "https://github.com/nerima-lisp/cl-boundary-kit";
            license = pkgs.lib.licenses.mit;
          };
        };
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        rec {
          cl-weave-runtime = pkgs.sbcl.buildASDFSystem {
            pname = "cl-weave";
            version = clWeaveVersion;
            src = cl-weave;
            systems = [ "cl-weave" ];
          };
          cl-prolog-runtime = pkgs.sbcl.buildASDFSystem {
            pname = "cl-prolog";
            version = clPrologVersion;
            src = cl-prolog;
            systems = [
              "cl-prolog"
              "cl-prolog/weave"
            ];
            lispLibs = [ cl-weave-runtime ];
          };
          cl-boundary-kit = pkgs.sbcl.buildASDFSystem {
            pname = "cl-boundary-kit";
            inherit version;
            src = self;
            systems = [ "cl-boundary-kit" ];
          };
          cl-boundary-kit-test = pkgs.sbcl.buildASDFSystem {
            pname = "cl-boundary-kit-test";
            inherit version;
            src = self;
            systems = [
              "cl-boundary-kit"
              "cl-boundary-kit/test"
            ];
            lispLibs = [
              cl-weave-runtime
              cl-prolog-runtime
            ];
          };
          test-sbcl = pkgs.sbcl.withPackages (_: [ cl-boundary-kit-test ]);
          docs = mkDocs pkgs;
          default = cl-boundary-kit;
        }
      );

      checks = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          testSbcl = self.packages.${system}.test-sbcl;
          runCheck =
            {
              name,
              coverage ? false,
            }:
            pkgs.runCommand name
              ({
                nativeBuildInputs = [
                  pkgs.coreutils
                  (if coverage then pkgs.sbcl else testSbcl)
                ];
              }
              // pkgs.lib.optionalAttrs coverage {
                CL_SOURCE_REGISTRY = sourceRegistry;
              })
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
                      export CL_BOUNDARY_KIT_COVERAGE_MANIFEST="$out/coverage-manifest.txt"
                    ''
                  else
                    ""
                }
                if ! timeout --foreground -k 10s ${testTimeoutSeconds}s sbcl --script ${self}/nix/ci-runner.lisp; then
                  cat "$CL_BOUNDARY_KIT_REPORT"
                  exit 1
                fi
                ${
                  if coverage then
                    ''
                      ${pkgs.perl}/bin/perl ${self}/nix/check-coverage.pl \
                        "$out/coverage-html/cover-index.html" 100 "$out/coverage-manifest.txt" \
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
                nativeBuildInputs = [
                  pkgs.coreutils
                  pkgs.sbcl
                ];
                CL_SOURCE_REGISTRY = sourceRegistry;
              }
              ''
                export HOME="$TMPDIR/home"
                mkdir -p "$HOME" "$out"
                timeout --foreground -k 10s ${testTimeoutSeconds}s sbcl --script ${self}/run-tests.lisp
                touch "$out/passed"
              '';
          machine-report = runCheck { name = "cl-boundary-kit-machine-report"; };
          coverage = runCheck {
            name = "cl-boundary-kit-coverage";
            coverage = true;
          };

          # Fails `nix flake check` when any tracked file is unformatted,
          # turning the formatter into an enforced CI gate rather than a
          # convention people remember to run.
          formatting = treefmtEval.${system}.config.build.check self;

          # The docs package builds with `mkdocs --strict`, so a broken link or
          # a page missing from the nav fails the build. Without this check the
          # site is only ever built by the publish workflow, which runs after a
          # merge to main — so such a break surfaces as a failed deploy instead
          # of as a failed pull request.
          docs = self.packages.${system}.docs;

          default = checkout-tests;
        }
      );

      # `nix fmt` entry point.
      formatter = forAllSystems (system: treefmtEval.${system}.config.build.wrapper);

      apps = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          testSbcl = self.packages.${system}.test-sbcl;
          test = pkgs.writeShellApplication {
            name = "cl-boundary-kit-test";
            runtimeInputs = [
              pkgs.coreutils
              testSbcl
            ];
            text = ''
              report_dir="$(mktemp -d)"
              trap 'rm -rf "$report_dir"' EXIT
              export CL_BOUNDARY_KIT_REPORT="$report_dir/report.json"
              timeout --foreground -k 10s ${testTimeoutSeconds}s sbcl --script ${self}/nix/ci-runner.lisp
              cat "$CL_BOUNDARY_KIT_REPORT"
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
