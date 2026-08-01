;;;; t/api-doc-links-readme-test.lisp

(in-package #:cl-boundary-kit/test)

;; README no longer carries a dedicated section per governance document; the
;; cross-reference these cases check now lives in docs/src/reference/repository-layout.md,
;; which enumerates every one of these files with its purpose.
(define-document-search-tests
  (:cases (readme-document-search-shared-cases))
  (readme-links-the-governance-documents-cookbook
   :file "docs/src/reference/repository-layout.md"
   :contains ("cookbook.md"))
  (readme-links-the-governance-documents-faq
   :file "docs/src/reference/repository-layout.md"
   :contains ("faq.md"))
  (readme-links-the-governance-documents-architecture
   :file "docs/src/reference/repository-layout.md"
   :contains ("architecture.md"))
  (readme-links-the-governance-documents-governance
   :file "docs/src/reference/repository-layout.md"
   :contains ("governance.md"))
  (readme-links-the-governance-documents-code-of-conduct
   :file "docs/src/reference/repository-layout.md"
   :contains ("code-of-conduct.md"))
  (readme-links-the-governance-documents-support
   :file "docs/src/reference/repository-layout.md"
   :contains ("support.md")))
