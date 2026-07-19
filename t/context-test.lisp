;;;; t/context-test.lisp

(in-package #:cl-boundary-kit/test)

(it "boundary-context-bundles-handlers"
  (let* ((fs (make-filesystem))
         (clock (make-fake-clock :start 3))
         (context (make-boundary-context :filesystem fs :clock clock)))
    (expect (eq (boundary-context-get context :filesystem) fs) :to-be-truthy)
    (expect (eq (boundary-context-get context :clock) clock) :to-be-truthy)
    (expect (null (boundary-context-get context :missing)) :to-be-truthy)))

(it "boundary-context-preserves-explicit-nil"
  (let ((context (make-boundary-context :filesystem nil)))
    (expect (null (boundary-context-get context :filesystem :fallback)) :to-be-truthy)
    (expect (boundary-context-present-p context :filesystem) :to-be-truthy)
    (expect (null (boundary-context-present-p context :missing)) :to-be-truthy)
    (expect (eq (boundary-context-get context :missing :fallback) :fallback) :to-be-truthy)))

(it "boundary-context-rejects-odd-binding-count"
  (signals error
    (make-boundary-context :filesystem)))

(it "boundary-context-rejects-non-keyword-keys"
  (signals error
    (make-boundary-context 'filesystem (make-filesystem))))

(it "boundary-context-get-rejects-non-context-values"
  (signals error
    (boundary-context-get :not-a-context :filesystem)))

(it "boundary-context-present-p-rejects-non-context-values"
  (signals error
    (boundary-context-present-p :not-a-context :filesystem)))

(it "boundary-context-keys-lists-bound-keys"
  (let ((context (make-boundary-context :filesystem :fs :clock :clock)))
    (expect (equal (sort (boundary-context-keys context) #'string< :key #'symbol-name)
               '(:clock :filesystem)) :to-be-truthy)))

(it "boundary-context-keys-rejects-non-context-values"
  (signals error
    (boundary-context-keys :not-a-context)))

(it "boundary-context-with-overrides-without-mutating-the-original"
  (let* ((context (make-boundary-context :filesystem :fs :clock :clock))
         (derived (boundary-context-with context :clock :new-clock :random :random)))
    (expect (eq (boundary-context-get derived :filesystem) :fs) :to-be-truthy)
    (expect (eq (boundary-context-get derived :clock) :new-clock) :to-be-truthy)
    (expect (eq (boundary-context-get derived :random) :random) :to-be-truthy)
    (expect (eq (boundary-context-get context :clock) :clock) :to-be-truthy)
    (expect (null (boundary-context-present-p context :random)) :to-be-truthy)))

(it "boundary-context-with-rejects-non-context-values"
  (signals error
    (boundary-context-with :not-a-context :filesystem :fs)))

(it "boundary-context-with-rejects-odd-binding-count"
  (signals error
    (boundary-context-with (make-boundary-context) :filesystem)))
