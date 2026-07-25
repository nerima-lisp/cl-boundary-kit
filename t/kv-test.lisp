;;;; t/kv-test.lisp

(in-package #:cl-boundary-kit/test)

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
    (expect (eq :value (kv-get store "k" :fallback)) :to-be-truthy)
    (expect (= 7 (kv-put store "k" 7)) :to-be-truthy)
    (expect (eq t (kv-delete store "k")) :to-be-truthy)
    (expect (equal (list "a") (kv-keys store)) :to-be-truthy)))

(it "make-kv-store-rejects-non-function-collaborators"
  (signals error
    (make-kv-store :get-fn :bad
                   :put-fn (lambda (k v)
                             (declare (ignore k))
                             v)
                   :delete-fn (lambda (k) k)
                   :keys-fn (lambda () '()))))

(it "test-kv-store-stores-reads-and-deletes-values"
  (let ((store (make-test-kv-store :initial '(("alpha" . 1)))))
    (with-soft-assertions
      (expect (= 1 (kv-get store "alpha")) :to-be-truthy)
      (expect (= 2 (kv-put store "beta" 2)) :to-be-truthy)
      (expect (equal (list "alpha" "beta") (kv-keys store)) :to-be-truthy)
      (expect (eq t (kv-delete store "beta")) :to-be-truthy)
      (expect (null (kv-delete store "beta")) :to-be-truthy)
      (expect (equal (list "alpha") (kv-keys store)) :to-be-truthy))))

(it "test-kv-store-distinguishes-a-stored-nil-from-a-missing-key"
  (let ((store (make-test-kv-store)))
    (kv-put store "present" nil)
    (multiple-value-bind (value present) (kv-get store "present" :default)
      (expect (null value) :to-be-truthy)
      (expect (eq t present) :to-be-truthy))
    (multiple-value-bind (value present) (kv-get store "absent" :default)
      (expect (eq :default value) :to-be-truthy)
      (expect (null present) :to-be-truthy))))

(it "test-kv-store-accepts-a-plist-initial-value"
  (let ((store (make-test-kv-store :initial '("x" 10 "y" 20))))
    (expect (= 10 (kv-get store "x")) :to-be-truthy)
    (expect (= 20 (kv-get store "y")) :to-be-truthy)))

(it "make-test-kv-store-rejects-a-malformed-initial-value"
  (signals error
    (make-test-kv-store :initial '("x" 10 "y"))))

(it "recording-kv-store-records-every-operation"
  (let ((store (make-recording-kv-store)))
    (kv-put store "k" 1)
    (kv-get store "k" :default)
    (kv-delete store "k")
    (kv-keys store)
    (expect (equal (recording-kv-calls store)
                   (list (boundary-call-plist :put (list "k" 1) :result 1)
                         (boundary-call-plist :get (list "k" :default) :result 1)
                         (boundary-call-plist :delete (list "k") :result t)
                         (boundary-call-plist :keys '() :result '()))) :to-be-truthy)))

(it "recording-kv-store-preserves-the-present-p-secondary-value"
  (let ((store (make-recording-kv-store)))
    (kv-put store "k" nil)
    (multiple-value-bind (value present) (kv-get store "k" :default)
      (expect (null value) :to-be-truthy)
      (expect (eq t present) :to-be-truthy))))

(it "make-recording-kv-store-rejects-a-non-kv-store-delegate"
  (signals error
    (make-recording-kv-store :delegate :bad)))

(it-each ((recording-kv-calls)
          (reset-recording-kv-calls))
    "~A signals for unsupported store types"
    (operation)
  (expect (lambda () (funcall operation (make-test-kv-store)))
          :to-signal-message-containing "Unsupported key/value store type"))

(it "reset-recording-kv-calls-clears-history-and-returns-the-store"
  (let ((store (make-recording-kv-store)))
    (kv-put store "k" 1)
    (expect (= 1 (length (recording-kv-calls store))) :to-be-truthy)
    (expect (eq store (reset-recording-kv-calls store)) :to-be-truthy)
    (expect (null (recording-kv-calls store)) :to-be-truthy)))

(it "kv-update-reads-modifies-and-writes-a-value"
  (let ((store (make-test-kv-store :initial '(("n" . 1)))))
    (expect (= 2 (kv-update store "n" #'1+)) :to-be-truthy)
    (expect (= 2 (kv-get store "n")) :to-be-truthy)
    ;; Uses the supplied default when the key is absent.
    (expect (= 10 (kv-update store "m" (lambda (v) (+ v 10)) 0)) :to-be-truthy)))

(it "kv-update-rejects-a-non-function"
  (signals error
    (kv-update (make-test-kv-store) "k" :bad)))

(it "kv-update-on-a-recording-store-records-the-underlying-get-and-put"
  (let ((store (make-recording-kv-store)))
    (kv-update store "n" (lambda (v) (if v (1+ v) 1)))
    (expect (equal (list :get :put) (recorded-call-operations (recording-kv-calls store))) :to-be-truthy)))

(it "kv-clear-removes-every-key-and-returns-the-store"
  (let ((store (make-test-kv-store :initial '(("a" . 1) ("b" . 2)))))
    (expect (eq store (kv-clear store)) :to-be-truthy)
    (expect (null (kv-keys store)) :to-be-truthy)))

(it "kv-get-or-put-returns-present-values-and-stores-computed-ones-only-on-a-miss"
  (let ((store (make-test-kv-store :initial '(("a" . 1))))
        (calls 0))
    (flet ((compute () (incf calls) 99))
      (expect (= 1 (kv-get-or-put store "a" #'compute)) :to-be-truthy)
      (expect (= 0 calls) :to-be-truthy)
      (expect (= 99 (kv-get-or-put store "b" #'compute)) :to-be-truthy)
      (expect (= 99 (kv-get store "b")) :to-be-truthy)
      ;; Second call for "b" is a hit, so compute does not run again.
      (expect (= 99 (kv-get-or-put store "b" #'compute)) :to-be-truthy)
      (expect (= 1 calls) :to-be-truthy))))

(it "kv-get-or-put-rejects-a-non-function-thunk"
  (signals error
    (kv-get-or-put (make-test-kv-store) "k" :bad)))

(it "kv-increment-counts-from-zero-and-honors-a-delta"
  (let ((store (make-test-kv-store)))
    (expect (= 1 (kv-increment store "hits")) :to-be-truthy)
    (expect (= 2 (kv-increment store "hits")) :to-be-truthy)
    (expect (= 12 (kv-increment store "hits" 10)) :to-be-truthy)
    (expect (= 12 (kv-get store "hits")) :to-be-truthy)
    ;; A negative delta decrements.
    (expect (= 11 (kv-increment store "hits" -1)) :to-be-truthy)))

(it "kv-increment-rejects-a-non-real-delta"
  (signals error
    (kv-increment (make-test-kv-store) "k" :bad)))

(it "kv-increment-on-a-recording-store-records-the-underlying-get-and-put"
  (let ((store (make-recording-kv-store)))
    (kv-increment store "n")
    (expect (equal (list :get :put)
                   (recorded-call-operations (recording-kv-calls store))) :to-be-truthy)))
