;;;; t/api-doc-links-readme-test.lisp

(in-package #:cl-boundary-kit/test)

(define-readme-document-search-tests
  (:cases (readme-document-search-shared-cases))
  (readme-links-the-governance-documents-cookbook
   :section ("## Cookbook" "## FAQ")
   :contains ("COOKBOOK.md"))
  (readme-links-the-governance-documents-faq
   :section ("## FAQ" "## Architecture")
   :contains ("FAQ.md"))
  (readme-links-the-governance-documents-architecture
   :section ("## Architecture" "## Governance")
   :contains ("ARCHITECTURE.md"))
  (readme-links-the-governance-documents-governance
   :section ("## Governance" "## Code of Conduct")
   :contains ("GOVERNANCE.md"))
  (readme-links-the-governance-documents-code-of-conduct
   :section ("## Code of Conduct" "## Support")
   :contains ("CODE_OF_CONDUCT.md"))
  (readme-links-the-governance-documents-support
   :section ("## Support" "## Security")
   :contains ("SUPPORT.md")))
