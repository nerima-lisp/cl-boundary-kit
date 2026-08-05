;;;; t/helpers-api-doc-search.lisp
;;;;
;;;; Shared document-search test-case data and the macros that expand it into
;;;; individual test cases, split out of helpers-api-markdown.lisp.

(in-package #:cl-boundary-kit/test)

(eval-when (:compile-toplevel :load-toplevel :execute)
  (defparameter *document-search-shared-cases*
    '((code-of-conduct-exists-and-documents-reporting
       :file "docs/src/project/code-of-conduct.md"
       :exists t
       :contains ("# Code of Conduct"
                  "## Reporting"
                  "security.md"
                  "support.md"
                  "normal usage question"
                  "vulnerability"))
      (support-document-exists-and-defines-routing :file "docs/src/project/support.md" :exists t :contains ("# Support" "## What To Use" "security.md" "code-of-conduct.md" "README.md" "compatibility.md" "GitHub releases page" "governance.md" "cookbook.md" "faq.md" "harassment" "verification guidance" "current documented API"))
      (governance-document-exists-and-defines-contract-surface :file "docs/src/project/governance.md" :exists t :contains ("# Governance" "## Maintainer Role" "## Decision Process" "README.md" "compatibility.md" "examples/*.lisp" "checked-in examples" "verification notes"))
      (architecture-document-exists-and-defines-layering
       :file "docs/src/reference/architecture.md"
       :exists t
       :contains ("# Architecture"
                  "## Layering Model"
                  "src/protocols.lisp"
                  "src/core.lisp"
                  "src/testing.lisp"
                  "examples/*.lisp"
                  "t/api-test.lisp"
                  "t/api-doc-*-test.lisp"
                  "t/api-executable-docs-*-test.lisp"
                  "README.md"
                  "governance.md"))
      (cookbook-document-exists-and-defines-supported-patterns
       :file "docs/src/guide/cookbook.md"
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
      (faq-document-exists-and-defines-decision-points :file "docs/src/guide/faq.md" :exists t :contains ("# FAQ" "## When Should I Use This Library?" "## How Do I Choose Between A Recording Boundary And A Test Boundary?" "## How Do I Preserve Explicit `nil` Values?" "## Why Do Unsupported Operations Signal Instead Of Falling Back?" "## What If Behavior Differs Across Lisp Implementations Or Platforms?" "## What Defines The Current Public API?" "cookbook.md" "compatibility.md" "support.md" "contributing.md" "governance.md" "security.md"))
      (faq-documents-the-stable-public-surface-contract :file "docs/src/guide/faq.md" :contains ("## What Defines The Current Public API?" "current public API is defined by:" "exported symbols documented across the [Guide](composition.md) pages" "checked-in examples and cookbook snippets" "compatibility.md" "contributing.md" "governance.md" "executable verification" "not treat it as documented API behavior"))
      (release-document-exists-and-defines-evidence-based-checklist :file "docs/src/project/release-process.md" :exists t :contains ("# Release Evidence" "## Release Checklist" "GitHub Release description" "roadmap.md" "README.md" "cookbook.md" "compatibility.md" "`sbcl --script run-tests.lisp`" "t/api-test.lisp" "t/api-doc-*-test.lisp" "t/api-executable-docs-*-test.lisp" "t/examples-test.lisp" "security.md" "## Evidence Required Before Publishing" "checked-in verification"))
      (compatibility-document-exists-and-defines-verification-scope :file "docs/src/reference/compatibility.md" :exists t :contains ("# Verification" "## Checked Workflows" "`sbcl --script run-tests.lisp`" "`asdf:load-system :cl-boundary-kit/test` and `(cl-boundary-kit/test:run-tests)`" "`0 failures`" "documented REPL runner" "stable verification path" "Hosts outside the emitted flake systems" "support.md" "security.md" "100% coverage"))
      (security-policy-documents-supported-versions-and-reporting-process
       :file "docs/src/project/security.md"
       :exists t
       ;; The supported-version row itself is deliberately not asserted here:
       ;; RELEASE-VERSION-DOCUMENTS-STAY-CONSISTENT-ACROSS-ASD-AND-POLICY-DOCS
       ;; derives it from cl-boundary-kit.asd's :version, so repeating the
       ;; literal would only add a copy that has to be hand-edited every
       ;; release and can silently disagree with the derived check.
       :contains ("## Supported Versions"
                  "private report"
                  "5 business days"
                  "## Disclosure Expectations"))
      (license-file-exists-and-uses-mit-license
       :file "LICENSE"
       :exists t
       :contains ("MIT License"
                  "Permission is hereby granted, free of charge"))
      (roadmap-documents-verification-driven-adoption-constraints :file "docs/src/project/roadmap.md" :contains ("## Status Semantics" "directional, not release commitments" "GitHub releases page" "documented REPL test-runner contract" "executable verification" "cookbook.md" "documented workflows only after they are exercised"))
      (roadmap-release-history-and-direction-stay-separate
       :file "docs/src/project/roadmap.md"
       :contains ("directional, not release commitments"
                  "Public changes that are already shipped belong in the release description"))))

  ;; Empty as of the 2026-08-01 revision. Both cases that lived here asserted
  ;; on CHANGELOG.md's Keep a Changelog structure and on its unreleased
  ;; section. There is no CHANGELOG.md any more: the GitHub Release
  ;; description is the org's only canonical changelog, and nothing in the
  ;; working tree can be checked against it. The parameter itself stays so
  ;; DOCUMENT-SEARCH-FOUNDATION-CASES keeps its shape and a future
  ;; foundation-only case has somewhere to go.
  (defparameter *document-search-foundation-extra-cases* '())

  ;; These cases used to check README.md's own summary prose linking out to
  ;; each governance document. Now that README is a lean landing page without
  ;; those per-topic sections, they check the docs/src page(s) that took over
  ;; as the authoritative source for the same cross-reference, using an
  ;; explicit :FILE (or a combined :HAYSTACK) instead of a README :SECTION.
  (defparameter *readme-document-search-shared-cases*
    '((readme-repository-layout-documents-where-release-history-lives
       :file "docs/src/reference/repository-layout.md"
       :contains ("compatibility.md"
                  "There is no `CHANGELOG.md`"
                  "GitHub Release description"))
      (readme-repository-layout-documents-the-canonical-test-entrypoint-and-license
       :file "docs/src/reference/repository-layout.md"
       :contains ("`run-tests.lisp`"
                  "canonical checkout test runner"
                  "cookbook.md"
                  "pattern-oriented usage guide"
                  "faq.md"
                  "user-facing decision points"
                  "architecture.md"
                  "layering model and design constraints"
                  "code-of-conduct.md"
                  "contributor behavior and reporting expectations"
                  "support.md"
                  "request routing and maintenance boundary"
                  "release-process.md"
                  "maintainer release checklist"
                  "`LICENSE`"
                  "MIT license terms"))
      (readme-links-the-governance-documents
       :file "docs/src/reference/repository-layout.md"
       :contains ("contributing.md"))
      (readme-contributing-and-governance-sections-document-contract-maintenance :file "docs/src/project/contributing.md" :contains ("documented public behavior" "executable tests" "relevant examples" "README.md" "checked workflow" "release evidence"))
      (readme-links-the-release-process-document
       :file "docs/src/project/contributing.md"
       :contains ("release-process.md"
                  "executable verification"))
      (readme-compatibility-section-links-the-compatibility-document :haystack (concatenate (quote string) (repository-file-string "docs/src/project/contributing.md") (repository-file-string "docs/src/reference/compatibility.md")) :contains ("compatibility.md" "executable verification" "Hosts outside the emitted flake systems"))))

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

(defun nth-document-fenced-code-block (pathname start-heading end-heading language index)
  (let ((blocks (document-fenced-code-blocks pathname start-heading end-heading language)))
    (or (nth index blocks)
        (error "Expected a ~A code block at index ~D in ~A between ~S and ~S, got ~D block(s)"
               language index pathname start-heading end-heading (length blocks)))))

(defun fenced-code-blocks-from-file (pathname start-heading end-heading language)
  (let* ((document (repository-file-string pathname))
         (section (markdown-section document start-heading end-heading)))
    (markdown-fenced-code-blocks section language)))
