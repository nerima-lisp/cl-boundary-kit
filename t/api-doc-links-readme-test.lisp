;;;; t/api-doc-links-readme-test.lisp

(in-package #:cl-boundary-kit/test)

;; README no longer carries a dedicated section per governance document; the
;; cross-reference these cases check now lives in docs/src/repository-layout.md,
;; which enumerates every one of these files with its purpose.
(define-document-search-tests
  (:cases (readme-document-search-shared-cases))
  (readme-links-the-governance-documents-cookbook
   :file "docs/src/repository-layout.md"
   :contains ("COOKBOOK.md"))
  (readme-links-the-governance-documents-faq
   :file "docs/src/repository-layout.md"
   :contains ("FAQ.md"))
  (readme-links-the-governance-documents-architecture
   :file "docs/src/repository-layout.md"
   :contains ("ARCHITECTURE.md"))
  (readme-links-the-governance-documents-governance
   :file "docs/src/repository-layout.md"
   :contains ("GOVERNANCE.md"))
  (readme-links-the-governance-documents-code-of-conduct
   :file "docs/src/repository-layout.md"
   :contains ("CODE_OF_CONDUCT.md"))
  (readme-links-the-governance-documents-support
   :file "docs/src/repository-layout.md"
   :contains ("SUPPORT.md")))
