;;;; t/context-test.lisp

(in-package #:cl-boundary-kit/test)

(describe "boundary-context"
  (it "boundary-context-bundles-handlers"
    (let* ((fs (make-filesystem))
           (clock (make-fake-clock :start 3))
           (context (make-boundary-context :filesystem fs :clock clock)))
      (expect (boundary-context-get context :filesystem) :to-be fs)
      (expect (boundary-context-get context :clock) :to-be clock)
      (expect (boundary-context-get context :missing) :to-be-null)))

  (it "boundary-context-require-returns-present-values-and-signals-on-absent-keys"
    (let ((context (make-boundary-context :clock 7 :filesystem nil)))
      (expect (boundary-context-require context :clock) :to-be 7)
      ;; A present but NIL binding is still returned, not treated as absent.
      (expect (boundary-context-require context :filesystem) :to-be-null)
      (signals error
        (boundary-context-require context :missing))))

  (it "boundary-context-count-and-alist-inspect-all-bindings"
    (let ((context (make-boundary-context :clock 1 :filesystem 2)))
      (with-soft-assertions
        (expect (boundary-context-count context) :to-be 2)
        (expect (sort (boundary-context-alist context) #'string< :key #'car)
                :to-equal '((:clock . 1) (:filesystem . 2)))
        (expect (boundary-context-count (make-boundary-context)) :to-be 0)
        (expect (boundary-context-alist (make-boundary-context)) :to-be-null))))

  (it "boundary-context-count-and-alist-reject-non-contexts"
    (signals error (boundary-context-count :bad))
    (signals error (boundary-context-alist :bad)))

  (it "boundary-context-remove-drops-keys-without-mutating-the-original"
    (let* ((context (make-boundary-context :clock 1 :filesystem 2 :network 3))
           (trimmed (boundary-context-remove context :filesystem :network)))
      (with-soft-assertions
        (expect (boundary-context-get trimmed :clock) :to-be 1)
        (expect (boundary-context-present-p trimmed :filesystem) :to-be-null)
        (expect (boundary-context-present-p trimmed :network) :to-be-null)
        ;; Original is untouched.
        (expect (boundary-context-present-p context :filesystem) :to-be-truthy)
        ;; Removing an absent key is a no-op.
        (expect (progn (boundary-context-remove context :nope) :ok) :to-be :ok))))

  (it "boundary-context-merge-layers-the-second-context-over-the-first"
    (let* ((base (make-boundary-context :clock 1 :filesystem 2))
           (overrides (make-boundary-context :filesystem 20 :network 30))
           (merged (boundary-context-merge base overrides)))
      (with-soft-assertions
        (expect (boundary-context-get merged :clock) :to-be 1)
        (expect (boundary-context-get merged :filesystem) :to-be 20)
        (expect (boundary-context-get merged :network) :to-be 30)
        ;; Inputs untouched.
        (expect (boundary-context-get base :filesystem) :to-be 2)
        (expect (boundary-context-present-p overrides :clock) :to-be-null))))

  (it "boundary-context-derivation-helpers-reject-non-contexts"
    (signals error (boundary-context-require :bad :key))
    (signals error (boundary-context-remove :bad :key))
    (signals error (boundary-context-merge :bad (make-boundary-context)))
    (signals error (boundary-context-merge (make-boundary-context) :bad)))

  (it "boundary-context-preserves-explicit-nil"
    (let ((context (make-boundary-context :filesystem nil)))
      (with-soft-assertions
        (expect (boundary-context-get context :filesystem :fallback) :to-be-null)
        (expect (boundary-context-present-p context :filesystem) :to-be-truthy)
        (expect (boundary-context-present-p context :missing) :to-be-null)
        (expect (boundary-context-get context :missing :fallback) :to-be :fallback))))

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
      (expect (sort (boundary-context-keys context) #'string< :key #'symbol-name)
              :to-equal '(:clock :filesystem))))

  (it "boundary-context-keys-rejects-non-context-values"
    (signals error
      (boundary-context-keys :not-a-context)))

  (it "boundary-context-with-overrides-without-mutating-the-original"
    (let* ((context (make-boundary-context :filesystem :fs :clock :clock))
           (derived (boundary-context-with context :clock :new-clock :random :random)))
      (with-soft-assertions
        (expect (boundary-context-get derived :filesystem) :to-be :fs)
        (expect (boundary-context-get derived :clock) :to-be :new-clock)
        (expect (boundary-context-get derived :random) :to-be :random)
        (expect (boundary-context-get context :clock) :to-be :clock)
        (expect (boundary-context-present-p context :random) :to-be-null))))

  (it "boundary-context-with-rejects-non-context-values"
    (signals error
      (boundary-context-with :not-a-context :filesystem :fs)))

  (it "boundary-context-with-rejects-odd-binding-count"
    (signals error
      (boundary-context-with (make-boundary-context) :filesystem))))
