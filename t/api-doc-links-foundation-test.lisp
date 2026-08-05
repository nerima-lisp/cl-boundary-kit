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
  (let ((command (single-document-fenced-code-block "docs/src/project/development.md"
                                                     "## Running the Test Suite" nil "sh")))
    (expect (string= "nix run .#test" command) :to-be-truthy)))

(it "public-subsystems-have-dedicated-regression-suites"
  (let* ((docs-readme (repository-file-string "docs/src/index.md"))
         (testing-doc (repository-file-string "docs/src/project/development.md"))
         (contributing (repository-file-string "docs/src/project/contributing.md"))
         (asd (repository-file-string "cl-boundary-kit.asd"))
         (package (string-upcase (repository-file-string "src/package.lisp")))
         (suites (public-subsystem-regression-suites)))
    (assert-contains-all docs-readme '("Tests included for every exported subsystem"))
    (assert-contains-all contributing
                         '("Every exported subsystem should have at least one regression test."))
    (assert-contains-all testing-doc
                         '("filesystem, environment, clock, random, process, network, logging, recording,"
                           "boundary composition behavior"))
    (dolist (suite suites)
      (let* ((doc-file (getf suite :doc-file))
             (heading (getf suite :doc-heading))
             (exports (getf suite :exports))
             (test-file (getf suite :test-file))
             (test-system-component (pathname-name test-file))
             (test-source (repository-file-string test-file)))
        (assert-contains-all (repository-file-string doc-file) (list heading))
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
         (stability-policy (repository-file-string "docs/src/reference/stability-policy.md"))
         (security (repository-file-string "docs/src/project/security.md"))
         (release (repository-file-string "docs/src/project/release-process.md")))
    (expect (not (null release-version)) :to-be-truthy)
    (expect (every (lambda (version) (string= release-version version)) versions) :to-be-truthy)
    ;; There is no CHANGELOG.md to cross-check as of the 2026-08-01 revision:
    ;; the GitHub Release description is the org's only canonical changelog,
    ;; and release.yml no longer extracts a release body from the tree. The
    ;; remaining policy documents still have to agree with the .asd :version.
    (assert-contains-all stability-policy (list (format nil "`~A`" release-series)))
    (assert-contains-all security (list (format nil "| `~A` | Yes |" release-series)))
    (assert-contains-all release (quote ("## Evidence Required Before Publishing")))))

(it "compatibility-verification-scope-stays-backed-by-executable-contracts"
  (let* ((compatibility (repository-file-string "docs/src/reference/compatibility.md"))
         (example-tests (repository-file-string "t/examples-runtime-test.lisp"))
         (example-helpers (repository-file-string "t/helpers-examples.lisp"))
         (installation-snippet (single-document-fenced-code-block
                                 "docs/src/getting-started.md" "# Getting Started" "## Nix" "lisp"))
         (testing-repl-snippet (single-document-fenced-code-block
                                 "docs/src/project/development.md" "## Running the Test Suite" nil "lisp")))
    (assert-contains-all compatibility (quote ("Provides a pinned Nix test path through `nix run .#test`" "Emits pinned Nix apps and checks for `x86_64-linux` and `aarch64-darwin`" "only `x86_64-linux` is CI-gated" "Exercises the supported host flake check set through `nix flake check`" "Does not require Quicklisp when using the Nix flake" "Supports direct `sbcl --script run-tests.lisp` execution" "Hosts outside the emitted flake systems can run the library when their implementation and dependencies satisfy the documented API requirements" "docs/src installation, quick-start, and test commands" "`asdf:load-system :cl-boundary-kit/test` and `(cl-boundary-kit/test:run-tests)` from a fresh SBCL" "successful completion" "exit status 0" "checked-in `examples/*.lisp` files against a fresh" "Treats the exported symbol list documented across the [Guide](../guide/composition.md)")))
    (assert-contains-all (single-document-fenced-code-block
                          "docs/src/project/development.md" "## Running the Test Suite" nil "sh")
                         '("nix run .#test"))
    (assert-contains-none (string-downcase installation-snippet)
                          '("quicklisp"
                            "ql:"))
    (assert-contains-all testing-repl-snippet
                         '("(asdf:load-system :cl-boundary-kit/test)"
                           "(cl-boundary-kit/test:run-tests)"))
    (assert-api-tests-defined
     '("readme-installation-and-quick-start-flow-is-executable"
       "readme-testing-section-repl-snippet-is-executable"
       "readme-testing-section-repl-snippet-uses-documented-test-runner"
       "public-api-is-exported-intentionally"
       "readme-examples-index-covers-the-example-files"))
    (assert-contains-all example-helpers '("run-example-in-fresh-sbcl"))
    (assert-contains-all example-tests '("documented-examples-have-output-checks"))))

(it "release-evidence-and-compatibility-scope-stay-aligned"
  (let* ((release (repository-file-string "docs/src/project/release-process.md"))
         (compatibility (repository-file-string "docs/src/reference/compatibility.md"))
         (example-helpers (repository-file-string "t/helpers-examples.lisp")))
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
    (assert-api-tests-defined
     '("readme-installation-snippet-loads-system-from-a-checkout"
       "readme-testing-section-repl-snippet-uses-documented-test-runner"
       "cookbook-compose-boundaries-snippet-is-executable"
       "cookbook-recorded-boundary-snippet-is-executable"
       "cookbook-unsupported-operation-snippet-is-executable"
       "readme-api-overview-covers-the-exported-surface"
       "public-subsystems-have-dedicated-regression-suites"))
    (assert-contains-all example-helpers '("run-example-in-fresh-sbcl"))))
