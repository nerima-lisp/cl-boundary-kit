{
  description = "Boundary-oriented testing utilities for Common Lisp";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # cl-weave is the deepest sibling, so it owns the single paredit-cli (and
    # therefore the single rust-overlay) node that every other sibling follows.
    cl-weave = {
      url = "github:nerima-lisp/cl-weave/v1.0.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    cl-prolog = {
      url = "github:nerima-lisp/cl-prolog/v1.0.1";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.cl-weave.follows = "cl-weave";
      inputs.paredit-cli.follows = "cl-weave/paredit-cli";
    };

    cl-log-kit = {
      url = "github:nerima-lisp/cl-log-kit/v1.0.0";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.cl-weave.follows = "cl-weave";
      inputs.cl-json-kit.follows = "cl-json-kit";
      inputs.paredit-cli.follows = "cl-weave/paredit-cli";
    };

    # NOTE: cl-process-kit depends on cl-boundary-kit by design — cl-process-kit
    # builds its injectable clock/sleeper hooks on this system's boundary
    # abstractions (see DEPENDENCY_POLICY.md). That back-reference is
    # deliberate, not a cycle to be broken, so its cl-boundary-kit and
    # cl-log-kit inputs are left alone: pointing them at this flake's own nodes
    # is what would turn the intentional back-reference into a real cycle.
    cl-process-kit = {
      url = "github:nerima-lisp/cl-process-kit/v1.0.1";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.cl-weave.follows = "cl-weave";
    };

    cl-json-kit = {
      url = "github:nerima-lisp/cl-json-kit/v1.0.0";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.cl-weave.follows = "cl-weave";
      inputs.treefmt-nix.follows = "treefmt-nix";
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
      cl-log-kit,
      cl-process-kit,
      cl-json-kit,
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
      # that inherits CL_SOURCE_REGISTRY re-walk all six trees in full before
      # resolving a system it would have found immediately. The checks start one
      # process per examples/*.lisp file, so that scan is paid ~40 times per run.
      # run-tests.lisp builds its own registry the same way.
      sourceRegistry = "${cl-weave}:${cl-prolog}:${cl-log-kit}:${cl-process-kit}:${cl-json-kit}:${self}";

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
          # cl-boundary-kit.asd declares :depends-on (:asdf :cl-log-kit), so the
          # dependency has to reach buildASDFSystem through lispLibs. Declaring
          # cl-log-kit as a flake input is not enough on its own: that only feeds
          # the CL_SOURCE_REGISTRY used by checks/devShells, and without this the
          # package build fails with `Component :CL-LOG-KIT not found`.
          clLogKit = pkgs.sbcl.buildASDFSystem {
            pname = "cl-log-kit";
            version = asdVersion "${cl-log-kit}/cl-log-kit.asd";
            src = cl-log-kit;
            systems = [ "cl-log-kit" ];
          };
        in
        rec {
          cl-boundary-kit = pkgs.sbcl.buildASDFSystem {
            pname = "cl-boundary-kit";
            inherit version;
            src = self;
            systems = [ "cl-boundary-kit" ];
            lispLibs = [ clLogKit ];
          };
          docs = mkDocs pkgs;
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
