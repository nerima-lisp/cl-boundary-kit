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

    # cl-boundary-kit's own real-boundary backend for host process
    # interaction, adopted directly (no adapter layer) rather than
    # hand-rolled per-boundary implementations.
    cl-host-kit = {
      url = "github:nerima-lisp/cl-host-kit/v0.2.1";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # crane for Common Lisp/ASDF: builds cl-weave-runtime, cl-prolog-runtime,
    # and cl-boundary-kit itself as lispDerivations instead of hand-rolled
    # pkgs.sbcl.buildASDFSystem calls.
    cl-nix-forge = {
      url = "github:nerima-lisp/cl-nix-forge/v0.4.0";
      inputs.nixpkgs.follows = "nixpkgs";
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
      cl-host-kit,
      cl-nix-forge,
      treefmt-nix,
      ...
    }:
    let
      # CI builds and tests only x86_64-linux, so that is the sole declared
      # system: the flake never advertises a platform it does not verify.
      # aarch64-darwin was dropped on 2026-08-01. Its only verification was a
      # local `nix flake check` on a development machine, and a run nobody can
      # tell was skipped is not a gate. aarch64-linux and x86_64-darwin were
      # already undeclared for the same reason.
      #
      # Consequence, accepted deliberately: every per-system output -- packages,
      # checks, apps AND devShells -- is generated from this one list, so
      # `nix develop` and `nix build` no longer work on macOS. Development
      # happens on Linux. See PACKAGE_STANDARD.md, section "systems".
      systems = [
        "x86_64-linux"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
      # Tests load from this checkout, while Nix supplies precompiled dependency
      # systems. Including sibling sources here makes ASDF rebuild them during
      # test startup and can deadlock SBCL's compiler on Darwin.
      sourceRegistry = "${self}";

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
      clHostKitVersion = asdVersion "${cl-host-kit}/cl-host-kit.asd";

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
          cl = cl-nix-forge.lib.${system};
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
          # cl-boundary-kit's own real-boundary backend (env/host-info/args/
          # system), adopted directly as an ASDF dependency rather than a
          # hand-rolled per-boundary implementation. Built the same way as
          # cl-weave-runtime/cl-prolog-runtime above, not via
          # cl.lispDerivation: it is a precompiled dependency deps-sbcl/
          # test-sbcl load, not a checkout ci-runner.lisp compiles fresh, so
          # the ASDF_OUTPUT_TRANSLATIONS concern documented on
          # CL-BOUNDARY-KIT below does not apply.
          cl-host-kit-runtime = pkgs.sbcl.buildASDFSystem {
            pname = "cl-host-kit";
            version = clHostKitVersion;
            src = cl-host-kit;
            systems = [ "cl-host-kit" ];
          };
          # Built via cl-nix-forge's lispDerivation rather than
          # pkgs.sbcl.buildASDFSystem. TEST-SBCL/DEPS-SBCL below stay on
          # buildASDFSystem/withPackages: cl.lispWithSystems bakes
          # ASDF_OUTPUT_TRANSLATIONS="/:/" (fasls beside sources) into its
          # wrapper unconditionally, which fails with permission denied when
          # these checks compile the read-only ${self} checkout fresh for
          # coverage instrumentation.
          cl-boundary-kit = cl.lispDerivation {
            lispSystem = "cl-boundary-kit";
            inherit version;
            src = self;
            lispLibs = [ cl-host-kit-runtime ];
          };
          # TEST-SBCL and DEPS-SBCL are identical: every check and app loads
          # CL-BOUNDARY-KIT's own sources fresh from the checkout (via
          # ci-runner.lisp/run-tests.lisp) rather than through a pre-built
          # cl-boundary-kit package, so both only need CL-WEAVE and CL-PROLOG
          # available without recompiling them from source under
          # CL_SOURCE_REGISTRY. A prior version of TEST-SBCL additionally
          # bundled a pre-built CL-BOUNDARY-KIT (to dodge compiling test
          # definitions here, which can deadlock SBCL's compile worker on
          # Darwin) -- but that bundled copy's own CL_SOURCE_REGISTRY entry
          # sorted ahead of the checkout's, so the README doc tests' spawned
          # child SBCL process resolved CL-BOUNDARY-KIT/TEST-BASE against
          # that read-only, never-compiled copy and failed with permission
          # denied trying to write its fasls there.
          deps-sbcl = pkgs.sbcl.withPackages (_: [
            cl-weave-runtime
            cl-prolog-runtime
            cl-host-kit-runtime
          ]);
          test-sbcl = deps-sbcl;
          docs = mkDocs pkgs;
          default = cl-boundary-kit;
        }
      );

      checks = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          testSbcl = self.packages.${system}.test-sbcl;
          depsSbcl = self.packages.${system}.deps-sbcl;
          runCheck =
            {
              name,
              coverage ? false,
            }:
            pkgs.runCommand name
              ({
                nativeBuildInputs = [
                  pkgs.coreutils
                  (if coverage then depsSbcl else testSbcl)
                ];
              })
              ''
                export HOME="$TMPDIR/home"
                mkdir -p "$HOME" "$out"
                export CL_SOURCE_REGISTRY="${sourceRegistry}''${CL_SOURCE_REGISTRY:+:$CL_SOURCE_REGISTRY}"
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
                if ! timeout --preserve-status -k 30 300 sbcl --script ${self}/nix/ci-runner.lisp; then
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
                  depsSbcl
                ];
              }
              ''
                export HOME="$TMPDIR/home"
                mkdir -p "$HOME" "$out"
                export CL_SOURCE_REGISTRY="${sourceRegistry}''${CL_SOURCE_REGISTRY:+:$CL_SOURCE_REGISTRY}"
                timeout --preserve-status -k 30 300 sbcl --script ${self}/run-tests.lisp
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
              export HOME="$report_dir/home"
              mkdir -p "$HOME"
              export CL_SOURCE_REGISTRY="${sourceRegistry}''${CL_SOURCE_REGISTRY:+:$CL_SOURCE_REGISTRY}"
              export CL_BOUNDARY_KIT_REPORT="$report_dir/report.json"
              timeout --preserve-status -k 30 300 sbcl --script ${self}/nix/ci-runner.lisp
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
