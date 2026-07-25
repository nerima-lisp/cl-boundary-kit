;;;; t/api-test-helpers-doc-search.lisp
;;;;
;;;; Shared document-search test-case data and the macros that expand it into
;;;; individual test cases, split out of api-test-helpers-markdown.lisp.

(in-package #:cl-boundary-kit/test)

(eval-when (:compile-toplevel :load-toplevel :execute)
  (defparameter *document-search-shared-cases*
    '((code-of-conduct-exists-and-documents-reporting
       :file "CODE_OF_CONDUCT.md"
       :exists t
       :contains ("# Code of Conduct"
                  "## Reporting"
                  "SECURITY.md"
                  "SUPPORT.md"
                  "normal usage question"
                  "vulnerability"))
      (support-document-exists-and-defines-routing
       :file "SUPPORT.md"
       :exists t
       :contains ("# Support"
                  "## What To Use"
                  "SECURITY.md"
                  "CODE_OF_CONDUCT.md"
                  "README.md"
                  "COMPATIBILITY.md"
                  "CHANGELOG.md"
                  "GOVERNANCE.md"
                  "COOKBOOK.md"
                  "FAQ.md"
                  "harassment"
                  "deprecated, removed, or changed in a breaking way"
                  "migration guidance"))
      (governance-document-exists-and-defines-contract-surface
       :file "GOVERNANCE.md"
       :exists t
       :contains ("# Governance"
                  "## Maintainer Role"
                  "## Decision Process"
                  "README.md"
                  "COMPATIBILITY.md"
                  "examples/*.lisp"
                  "checked-in examples"
                  "CHANGELOG.md"))
      (architecture-document-exists-and-defines-layering
       :file "ARCHITECTURE.md"
       :exists t
       :contains ("# Architecture"
                  "## Layering Model"
                  "src/protocols.lisp"
                  "src/core.lisp"
                  "src/testing.lisp"
                  "examples/*.lisp"
                  "t/api-test.lisp"
                  "t/api-doc-claims-test.lisp"
                  "t/api-doc-links-test.lisp"
                  "t/api-executable-docs-test.lisp"
                  "README.md"
                  "GOVERNANCE.md"))
      (cookbook-document-exists-and-defines-supported-patterns
       :file "COOKBOOK.md"
       :exists t
       :contains ("# Cookbook"
                  "## Compose Boundaries At The Application Edge"
                  "## Assert On Recorded Boundary Calls"
                  "## Handle Unsupported Operations Explicitly"
                  "make-boundary-context"
                  "assert-recorded-call"
                  "assert-recorded-call-count"
                  "assert-recorded-call-sequence"
                  "unsupported-boundary-operation"))
      (faq-document-exists-and-defines-decision-points
       :file "FAQ.md"
       :exists t
       :contains ("# FAQ"
                  "## When Should I Use This Library?"
                  "## How Do I Choose Between A Recording Boundary And A Test Boundary?"
                  "## How Do I Preserve Explicit `nil` Values?"
                  "## Why Do Unsupported Operations Signal Instead Of Falling Back?"
                  "## What If Behavior Differs Across Lisp Implementations Or Platforms?"
                  "## How Will Deprecations Or Breaking Changes Be Communicated?"
                  "COOKBOOK.md"
                  "COMPATIBILITY.md"
                  "CHANGELOG.md"
                  "SUPPORT.md"
                  "CONTRIBUTING.md"
                  "GOVERNANCE.md"
                  "SECURITY.md"))
      (faq-documents-the-stable-public-surface-contract
       :file "FAQ.md"
       :contains ("## What Counts As The Stable Public Surface?"
                  "contract is defined by:"
                  "exported symbols documented in `README.md`"
                  "checked-in examples and cookbook snippets"
                  "COMPATIBILITY.md"
                  "CONTRIBUTING.md"
                  "GOVERNANCE.md"
                  "executable verification"
                  "not treat it as a compatibility promise"))
      (release-document-exists-and-defines-evidence-based-checklist
       :file "RELEASE.md"
       :exists t
       :contains ("# Release Process"
                  "## Release Checklist"
                  "CHANGELOG.md"
                  "ROADMAP.md"
                  "README.md"
                  "COOKBOOK.md"
                  "COMPATIBILITY.md"
                  "`sbcl --script run-tests.lisp`"
                  "t/api-test.lisp"
                  "t/api-doc-claims-test.lisp"
                  "t/api-doc-links-test.lisp"
                  "t/api-executable-docs-test.lisp"
                  "t/examples-test.lisp"
                  "SECURITY.md"
                  "deprecations or removals"
                  "migration guidance"))
      (compatibility-document-exists-and-defines-verification-scope
       :file "COMPATIBILITY.md"
       :exists t
       :contains ("# Compatibility"
                  "## Verification Scope"
                  "`sbcl --script run-tests.lisp`"
                  "`asdf:load-system :cl-boundary-kit/test` and `(cl-boundary-kit/test:run-tests)`"
                  "`0 failures`"
                  "documented REPL runner"
                  "stable verification path"
                  "Other Common Lisp implementations may work"
                  "SUPPORT.md"
                  "SECURITY.md"
                  "## Change Policy"))
      (security-policy-documents-supported-versions-and-reporting-process
       :file "SECURITY.md"
       :exists t
       :contains ("## Supported Versions"
                  "| `0.5.x` | Yes |"
                  "private report"
                  "5 business days"
                  "## Disclosure Expectations"))
      (license-file-exists-and-uses-mit-license
       :file "LICENSE"
       :exists t
       :contains ("MIT License"
                  "Permission is hereby granted, free of charge"))
      (roadmap-documents-verification-driven-adoption-constraints
       :file "ROADMAP.md"
       :exists t
       :contains ("## Status Semantics"
                  "directional, not release commitments"
                  "CHANGELOG.md"
                  "documented REPL test-runner contract"
                  "executable verification"
                  "`COOKBOOK.md`"
                  "implementation compatibility claims only after they are exercised"))
      (roadmap-changelog-and-release-documents-separate-facts-from-direction
       :file "ROADMAP.md"
       :contains ("directional, not release commitments"
                  "Public changes that are already shipped or concretely queued for the next"))))

  (defparameter *document-search-foundation-extra-cases*
    '((changelog-exists-and-has-minimal-release-structure
       :file "CHANGELOG.md"
       :exists t
       :contains ("# Changelog"
                  "## Unreleased"
                  "ROADMAP.md"
                  "This section tracks intentional public changes that may ship in the next"
                  "Long-term ideas, non-committed exploration, and deferred work belong"
                  "Deprecations, removals, and intentionally breaking behavior changes"
                  "migration guidance"
                  "## 0.1.0"))
      (changelog-tracks-current-unreleased-public-testing-helper-work
       :file "CHANGELOG.md"
       :contains ("`assert-recorded-call-count`"
                  "`assert-recorded-call-sequence`"
                  "`:exact-length nil`"
                  "`:result nil`"
                  "`boundary-call-plist`"
                  "`README.md`"
                  "`COOKBOOK.md`")
       :absent ("No unreleased changes yet."))))

  (defparameter *readme-document-search-shared-cases*
    '((readme-repository-layout-documents-the-changelog
       :section ("## Repository Layout" "## Testing")
       :contains ("`COMPATIBILITY.md`"
                  "`CHANGELOG.md`"
                  "release history"))
      (readme-repository-layout-documents-the-canonical-test-entrypoint-and-license
       :section ("## Repository Layout" "## Testing")
       :contains ("`run-tests.lisp`"
                  "canonical checkout test runner"
                  "`COOKBOOK.md`"
                  "pattern-oriented usage guide"
                  "`FAQ.md`"
                  "user-facing decision points"
                  "`ARCHITECTURE.md`"
                  "layering model and design constraints"
                  "`CODE_OF_CONDUCT.md`"
                  "contributor behavior and reporting expectations"
                  "`SUPPORT.md`"
                  "request routing and maintenance boundary"
                  "`RELEASE.md`"
                  "maintainer release checklist"
                  "`LICENSE`"
                  "MIT license terms"))
      (readme-links-the-governance-documents
       :section ("## Contributing" "## Cookbook")
       :contains ("CONTRIBUTING.md"))
      (readme-contributing-and-governance-sections-document-contract-maintenance
       :section ("## Contributing" "## Cookbook")
       :contains ("supported public contract"
                  "executable tests"
                  "relevant examples"
                  "README.md"
                  "CHANGELOG.md"
                  "migration guidance"))
      (readme-links-the-release-process-document
       :section ("## Release Process" "## License")
       :contains ("RELEASE.md"
                  "executable verification"))
      (readme-compatibility-section-links-the-compatibility-document
       :section ("## Compatibility" "## Stability Policy")
       :contains ("COMPATIBILITY.md"
                  "executable verification"
                  "unverified Common Lisp implementations or platforms"))
      (readme-faq-and-support-sections-document-routing-expectations
       :section ("## FAQ" "## Architecture")
       :contains ("FAQ.md"
                  "implementation/platform-specific behavior"
                  "support or security"
                  "SUPPORT.md"
                  "private security route"
                  "exact exported API"
                  "minimal"
                  "Common Lisp implementation/platform"))
      (readme-security-section-routes-sensitive-reports-correctly
       :section ("## Security" "## Roadmap")
       :contains ("SECURITY.md"
                  "private security route"
                  "supported"
                  "versions"
                  "Do not post exploit details, secrets"
                  "private report path"))
      (readme-roadmap-section-separates-direction-from-release-facts
       :section ("## Roadmap" "## Changelog")
       :contains ("ROADMAP.md"
                  "directional, non-committed work"
                  "CHANGELOG.md"
                  "should not be inferred from roadmap text"))))

  (defmacro document-search-shared-cases ()
    `',*document-search-shared-cases*)

  (defmacro document-search-foundation-cases ()
    `',(append *document-search-foundation-extra-cases*
               *document-search-shared-cases*)))

(defun expand-document-search-test-cases (forms env macro-name)
  (loop for form in forms append
        (cond
          ((and (consp form) (eq :cases (first form)))
           (let ((expanded (macroexpand-1 (second form) env)))
             (unless (and (consp expanded) (eq 'quote (first expanded)))
               (error "~A expected :CASES to expand to a quoted list, got ~S"
                      macro-name expanded))
             (expand-document-search-test-cases (second expanded) env macro-name)))
          (t (list form)))))

(defmacro readme-document-search-shared-cases ()
  `',*readme-document-search-shared-cases*)

(defmacro define-readme-document-search-tests (&environment env &rest cases)
  `(define-document-search-tests
     ,@(loop for case in (expand-document-search-test-cases cases env
                                                            'DEFINE-README-DOCUMENT-SEARCH-TESTS)
             collect
             (destructuring-bind (test-name &rest options) case
               `(,test-name :file "README.md" ,@options)))))

(defmacro define-document-search-tests (&environment env &rest cases)
  `(progn
     ,@(loop for case in (expand-document-search-test-cases cases env
                                                            'DEFINE-DOCUMENT-SEARCH-TESTS)
             collect
             (destructuring-bind (test-name &key file section haystack exists contains absent) case
               (let ((document (gensym "DOCUMENT"))
                     (text (gensym "TEXT")))
                 `(it ,(string-downcase (string test-name))
                    ,@(when exists
                        `((expect (repository-file-exists-p ,file) :to-be-truthy)))
                    (let* ((,document ,(cond
                                         (haystack haystack)
                                         (file `(repository-file-string ,file))
                                         (t (error "DEFINE-DOCUMENT-SEARCH-TESTS requires either :FILE or :HAYSTACK in ~S"
                                                   test-name))))
                           (,text ,(if section
                                       (destructuring-bind (start-heading end-heading) section
                                         `(markdown-section ,document ,start-heading ,end-heading))
                                       document)))
                      ,@(when contains
                          `((assert-contains-all ,text ',contains)))
                      ,@(when absent
                          `((assert-contains-none ,text ',absent))))))))))

(defun single-document-fenced-code-block (pathname start-heading end-heading language)
  (let ((blocks (document-fenced-code-blocks pathname start-heading end-heading language)))
    (unless (= 1 (length blocks))
      (error "Expected exactly one ~A code block in ~A between ~S and ~S, got ~D"
             language pathname start-heading end-heading (length blocks)))
    (first blocks)))

(defun first-readme-fenced-code-block (start-heading end-heading language)
  (single-document-fenced-code-block "README.md" start-heading end-heading language))

(defun nth-document-fenced-code-block (pathname start-heading end-heading language index)
  (let ((blocks (document-fenced-code-blocks pathname start-heading end-heading language)))
    (or (nth index blocks)
        (error "Expected a ~A code block at index ~D in ~A between ~S and ~S, got ~D block(s)"
               language index pathname start-heading end-heading (length blocks)))))

(defun fenced-code-blocks-from-file (pathname start-heading end-heading language)
  (let* ((document (repository-file-string pathname))
         (section (markdown-section document start-heading end-heading)))
    (markdown-fenced-code-blocks section language)))
