;;;; t/env-test.lisp

(in-package #:cl-boundary-kit/test)

(it "test-environment-reads-and-writes"
  (let ((env (make-test-environment :initial-values '(("A" . "1")
                                                       ("EMPTY" . nil)))))
    (expect (string= (environment-get env "A") "1") :to-be-truthy)
    (expect (environment-present-p env "A") :to-be-truthy)
    (expect (string= (environment-set env "B" "2") "2") :to-be-truthy)
    (expect (string= (environment-get env "B") "2") :to-be-truthy)
    (expect (environment-present-p env "B") :to-be-truthy)
    (expect (null (environment-get env "EMPTY" "fallback")) :to-be-truthy)
    (expect (environment-present-p env "EMPTY") :to-be-truthy)
    (expect (null (environment-present-p env "MISSING")) :to-be-truthy)
    (expect (string= (environment-get env "MISSING" "fallback") "fallback") :to-be-truthy)
    (expect (some (lambda (pair) (equal pair '("A" . "1")))
              (environment-list env)) :to-be-truthy)))

(it "test-environment-accepts-plist-initial-values"
  (let ((env (make-test-environment :initial-values '("A" "1" "EMPTY" nil))))
    (expect (string= (environment-get env "A") "1") :to-be-truthy)
    (expect (environment-present-p env "A") :to-be-truthy)
    (expect (null (environment-get env "EMPTY" "fallback")) :to-be-truthy)
    (expect (environment-present-p env "EMPTY") :to-be-truthy)
    (let ((entries (environment-list env)))
      (expect (equal '(("A" . "1") ("EMPTY" . nil)) entries) :to-be-truthy)
      (expect (some (lambda (pair) (equal pair '("A" . "1"))) entries) :to-be-truthy)
      (expect (some (lambda (pair) (equal pair '("EMPTY" . nil))) entries) :to-be-truthy))))

(it "test-environment-list-is-sorted-by-name"
  (let ((env (make-test-environment :initial-values '(("Z" . "last")
                                                       ("A" . "first")
                                                       ("M" . nil)))))
    (expect (equal '(("A" . "first")
                 ("M" . nil)
                 ("Z" . "last"))
               (environment-list env)) :to-be-truthy)))

(it "test-environment-rejects-odd-initial-values"
  (signals error
    (make-test-environment :initial-values '("A" "1" "BROKEN"))))
