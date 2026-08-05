;;;; t/kv-test.lisp

(in-package #:cl-boundary-kit/test)

(describe "make-kv-store"
  (it "make-kv-store-wires-injected-collaborators"
    (let* ((events '())
           (store (make-kv-store
                   :get-fn (lambda (key default)
                             (push (list :get key default) events)
                             (values :value t))
                   :put-fn (lambda (key value)
                             (push (list :put key value) events)
                             value)
                   :delete-fn (lambda (key)
                                (push (list :delete key) events)
                                t)
                   :keys-fn (lambda ()
                              (push :keys events)
                              (list "a")))))
      (expect (kv-get store "k" :fallback) :to-be :value)
      (expect (kv-put store "k" 7) :to-be 7)
      (expect (kv-delete store "k") :to-be t)
      (expect (kv-keys store) :to-equal (list "a"))))

  (it "make-kv-store-rejects-non-function-collaborators"
    (signals error
      (make-kv-store :get-fn :bad
                     :put-fn (lambda (k v)
                               (declare (ignore k))
                               v)
                     :delete-fn (lambda (k) k)
                     :keys-fn (lambda () '())))))

(describe "test-kv-store"
  (it "test-kv-store-stores-reads-and-deletes-values"
    (let ((store (make-test-kv-store :initial '(("alpha" . 1)))))
      (with-soft-assertions
        (expect (kv-get store "alpha") :to-be 1)
        (expect (kv-put store "beta" 2) :to-be 2)
        (expect (kv-keys store) :to-equal (list "alpha" "beta"))
        (expect (kv-delete store "beta") :to-be t)
        (expect (kv-delete store "beta") :to-be-null)
        (expect (kv-keys store) :to-equal (list "alpha")))))

  (it "test-kv-store-distinguishes-a-stored-nil-from-a-missing-key"
    (let ((store (make-test-kv-store)))
      (kv-put store "present" nil)
      (multiple-value-bind (value present) (kv-get store "present" :default)
        (expect value :to-be-null)
        (expect present :to-be t))
      (multiple-value-bind (value present) (kv-get store "absent" :default)
        (expect value :to-be :default)
        (expect present :to-be-null))))

  (it "test-kv-store-accepts-a-plist-initial-value"
    (let ((store (make-test-kv-store :initial '("x" 10 "y" 20))))
      (expect (kv-get store "x") :to-be 10)
      (expect (kv-get store "y") :to-be 20)))

  (it "make-test-kv-store-rejects-a-malformed-initial-value"
    (signals error
      (make-test-kv-store :initial '("x" 10 "y")))))

(describe "recording-kv-store"
  (it "recording-kv-store-records-every-operation"
    (let ((store (make-recording-kv-store)))
      (kv-put store "k" 1)
      (kv-get store "k" :default)
      (kv-delete store "k")
      (kv-keys store)
      (expect (recording-kv-calls store)
              :to-have-recorded-calls
              (list (boundary-call-plist :put (list "k" 1) :result 1)
                    (boundary-call-plist :get (list "k" :default) :result 1)
                    (boundary-call-plist :delete (list "k") :result t)
                    (boundary-call-plist :keys '() :result '())))))

  (it "recording-kv-store-preserves-the-present-p-secondary-value"
    (let ((store (make-recording-kv-store)))
      (kv-put store "k" nil)
      (multiple-value-bind (value present) (kv-get store "k" :default)
        (expect value :to-be-null)
        (expect present :to-be t))))

  (it "make-recording-kv-store-rejects-a-non-kv-store-delegate"
    (signals error
      (make-recording-kv-store :delegate :bad)))

  (it-each ((recording-kv-calls)
            (reset-recording-kv-calls))
      "~A signals for unsupported store types"
      (operation)
    (expect (lambda () (funcall operation (make-test-kv-store))) :to-throw "Unsupported key/value store type"))

  (deftest-reset-recording-clears-history
      "reset-recording-kv-calls-clears-history-and-returns-the-store"
      (store (make-recording-kv-store))
      (recording-kv-calls reset-recording-kv-calls)
    (kv-put store "k" 1)))

(describe "kv-store derived operations"
  (it "kv-update-reads-modifies-and-writes-a-value"
    (let ((store (make-test-kv-store :initial '(("n" . 1)))))
      (expect (kv-update store "n" #'1+) :to-be 2)
      (expect (kv-get store "n") :to-be 2)
      ;; Uses the supplied default when the key is absent.
      (expect (kv-update store "m" (lambda (v) (+ v 10)) 0) :to-be 10)))

  (it "kv-update-rejects-a-non-function"
    (signals error
      (kv-update (make-test-kv-store) "k" :bad)))

  (it "kv-update-on-a-recording-store-records-the-underlying-get-and-put"
    (let ((store (make-recording-kv-store)))
      (kv-update store "n" (lambda (v) (if v (1+ v) 1)))
      (expect (recording-kv-calls store) :to-have-recorded-operations (list :get :put))))

  (it "kv-clear-removes-every-key-and-returns-the-store"
    (let ((store (make-test-kv-store :initial '(("a" . 1) ("b" . 2)))))
      (expect (kv-clear store) :to-be store)
      (expect (kv-keys store) :to-be-null)))

  (it "kv-get-or-put-returns-present-values-and-stores-computed-ones-only-on-a-miss"
    (let ((store (make-test-kv-store :initial '(("a" . 1))))
          (calls 0))
      (flet ((compute () (incf calls) 99))
        (with-soft-assertions
          (expect (kv-get-or-put store "a" #'compute) :to-be 1)
          (expect calls :to-be 0)
          (expect (kv-get-or-put store "b" #'compute) :to-be 99)
          (expect (kv-get store "b") :to-be 99)
          ;; Second call for "b" is a hit, so compute does not run again.
          (expect (kv-get-or-put store "b" #'compute) :to-be 99)
          (expect calls :to-be 1)))))

  (it "kv-get-or-put-rejects-a-non-function-thunk"
    (signals error
      (kv-get-or-put (make-test-kv-store) "k" :bad)))

  (it "kv-increment-counts-from-zero-and-honors-a-delta"
    (let ((store (make-test-kv-store)))
      (with-soft-assertions
        (expect (kv-increment store "hits") :to-be 1)
        (expect (kv-increment store "hits") :to-be 2)
        (expect (kv-increment store "hits" 10) :to-be 12)
        (expect (kv-get store "hits") :to-be 12)
        ;; A negative delta decrements.
        (expect (kv-increment store "hits" -1) :to-be 11))))

  (it "kv-increment-rejects-a-non-real-delta"
    (signals error
      (kv-increment (make-test-kv-store) "k" :bad)))

  (it "kv-increment-on-a-recording-store-records-the-underlying-get-and-put"
    (let ((store (make-recording-kv-store)))
      (kv-increment store "n")
      (expect (recording-kv-calls store) :to-have-recorded-operations (list :get :put)))))
