;;;; t/api-doc-links-foundation-test.lisp

(in-package #:cl-boundary-kit/test)

(it "readme-examples-index-covers-the-example-files"
  (let* ((documented (readme-example-paths))
         (actual (mapcar (lambda (path)
                           (concatenate 'string "examples/" (file-namestring path)))
                         (example-file-paths))))
    (expect (null (set-difference actual documented :test #'string=)) :to-be-truthy)
    (expect (null (set-difference documented actual :test #'string=)) :to-be-truthy)))

(it "readme-testing-section-documents-the-canonical-linux-test-command"
  (let ((command (first-readme-fenced-code-block "## Testing" "## Compatibility" "sh")))
    (expect (string= "nix run .#test" command) :to-be-truthy)))

(it "public-subsystems-have-dedicated-regression-suites"
  (let* ((readme (repository-file-string "README.md"))
         (testing-section (markdown-section readme "## Testing" "## Compatibility"))
         (contributing (repository-file-string "CONTRIBUTING.md"))
         (asd (repository-file-string "cl-boundary-kit.asd"))
         (package (string-upcase (repository-file-string "src/package.lisp")))
         (suites (public-subsystem-regression-suites)))
    (assert-contains-all readme '("Tests included for every exported subsystem"))
    (assert-contains-all contributing
                         '("Every exported subsystem should have at least one regression test."))
    (assert-contains-all testing-section
                         '("filesystem, environment, clock, random, process, network, logging, recording,"
                           "boundary composition behavior"))
    (dolist (suite suites)
      (let* ((heading (getf suite :readme-heading))
             (exports (getf suite :exports))
             (test-file (getf suite :test-file))
             (test-system-component (pathname-name test-file))
             (test-source (repository-file-string test-file)))
        (assert-contains-all readme (list heading))
        (assert-contains-all package exports)
        (expect (repository-file-exists-p test-file) :to-be-truthy)
        (assert-contains-all test-source '("(it "))
        (assert-contains-all asd (list (format nil "\"~A\"" test-system-component)))))))

(it "asdf-system-definitions-publish-oss-metadata"
  (let ((asd (repository-file-string "cl-boundary-kit.asd")))
    (expect (not (null (search ":long-description" asd))) :to-be-truthy)
    (expect (not (null (search ":maintainer" asd))) :to-be-truthy)
    (expect (not (null (search ":homepage" asd))) :to-be-truthy)
    (expect (not (null (search ":bug-tracker" asd))) :to-be-truthy)
    (expect (not (null (search ":source-control" asd))) :to-be-truthy)))

(it "release-version-documents-stay-consistent-across-asd-and-policy-docs"
  (let* ((versions (asd-version-strings))
         (release-version (first versions))
         (release-series (supported-release-series release-version))
         (changelog (repository-file-string "CHANGELOG.md"))
         (readme (repository-file-string "README.md"))
         (security (repository-file-string "SECURITY.md"))
         (release (repository-file-string "RELEASE.md")))
    (expect (not (null release-version)) :to-be-truthy)
    (expect (every (lambda (version) (string= release-version version)) versions) :to-be-truthy)
    (assert-contains-all changelog
                         (list (format nil "## ~A" release-version)
                               "## Unreleased"))
    (assert-contains-all readme (list (format nil "`~A`" release-series)))
    (assert-contains-all security (list (format nil "| `~A` | Yes |" release-series)))
    (assert-contains-all release (list (format nil "`~A` should keep" release-series)))))

(it "compatibility-verification-scope-stays-backed-by-executable-contracts"
  (let* ((compatibility (repository-file-string "COMPATIBILITY.md"))
         (api-tests (api-test-suite-string))
         (example-tests (repository-file-string "t/examples-runtime-test.lisp"))
         (example-helpers (repository-file-string "t/examples-test-helpers.lisp"))
         (installation-snippet (first-readme-fenced-code-block "## Installation" "## Quick Start" "lisp"))
         (testing-repl-snippet (first-readme-fenced-code-block "## Testing" "## Compatibility" "lisp")))
    (assert-contains-all compatibility
                         '("Provides a pinned Nix test path through `nix run .#test`"
                           "Emits pinned Nix apps and checks for `x86_64-linux` and `aarch64-darwin`"
                           "Exercises the supported host flake check set through `nix flake check`"
                           "Does not require Quicklisp when using the Nix flake"
                           "Supports direct `sbcl --script run-tests.lisp` execution"
                           "Does not claim compatibility for hosts outside the emitted flake systems"
                           "README installation, quick-start, and test commands"
                           "`asdf:load-system :cl-boundary-kit/test` and `(cl-boundary-kit/test:run-tests)` from a fresh SBCL"
                           "successful completion"
                           "exit status 0"
                           "checked-in `examples/*.lisp` files against a fresh"
                           "Treats the exported symbol list in `README.md` `## API Overview`"))
    (assert-contains-all (first-readme-fenced-code-block "## Testing" "## Compatibility" "sh")
                         '("nix run .#test"))
    (assert-contains-none (string-downcase installation-snippet)
                          '("quicklisp"
                            "ql:"))
    (assert-contains-all testing-repl-snippet
                         '("(asdf:load-system :cl-boundary-kit/test)"
                           "(cl-boundary-kit/test:run-tests)"))
    (assert-contains-all api-tests
                         '("readme-installation-and-quick-start-flow-is-executable"
                           "readme-testing-section-repl-snippet-is-executable"
                           "readme-testing-section-repl-snippet-uses-documented-test-runner"
                           "public-api-is-exported-intentionally"
                           "readme-examples-index-covers-the-example-files"))
    (assert-contains-all example-helpers '("run-example-in-fresh-sbcl"))
    (assert-contains-all example-tests '("documented-examples-have-output-checks"))))

(it "release-evidence-and-compatibility-scope-stay-aligned"
  (let* ((release (repository-file-string "RELEASE.md"))
         (compatibility (repository-file-string "COMPATIBILITY.md"))
         (api-tests (api-test-suite-string))
         (example-helpers (repository-file-string "t/examples-test-helpers.lisp")))
    (assert-contains-all release
                         '("the checkout installation flow"
                           "the documented REPL test-runner path"
                           "the checked-in examples"
                           "cookbook snippets and documentation contracts"))
    (assert-contains-all compatibility
                         '("checkout install flow"
                           "`asdf:load-system :cl-boundary-kit/test` and `(cl-boundary-kit/test:run-tests)` from a fresh SBCL"
                           "checked-in `examples/*.lisp` files against a fresh"
                           "cookbook snippets and documentation contracts"))
    (assert-contains-all api-tests
                         '("readme-installation-snippet-loads-system-from-a-checkout"
                           "readme-testing-section-repl-snippet-uses-documented-test-runner"
                           "cookbook-compose-boundaries-snippet-is-executable"
                           "cookbook-recorded-boundary-snippet-is-executable"
                           "cookbook-unsupported-operation-snippet-is-executable"
                           "readme-api-overview-covers-the-exported-surface"
                           "public-subsystems-have-dedicated-regression-suites"))
    (assert-contains-all example-helpers '("run-example-in-fresh-sbcl"))))
