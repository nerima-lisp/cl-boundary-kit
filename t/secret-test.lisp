;;;; t/secret-test.lisp

(in-package #:cl-boundary-kit/test)

(it "test-secret-store-reads-values-with-present-p"
  (let ((store (make-test-secret-store :initial '(("token" . "abc")))))
    (multiple-value-bind (value present) (secret-get store "token")
      (expect (string= "abc" value) :to-be-truthy)
      (expect (eq t present) :to-be-truthy))
    (multiple-value-bind (value present) (secret-get store "missing" :fallback)
      (expect (eq :fallback value) :to-be-truthy)
      (expect (null present) :to-be-truthy))))

(it "test-secret-store-distinguishes-a-stored-nil-from-a-missing-secret"
  (let ((store (make-test-secret-store)))
    (multiple-value-bind (value present) (secret-get store "absent" :default)
      (expect (eq :default value) :to-be-truthy)
      (expect (null present) :to-be-truthy))))

(it "test-secret-store-accepts-a-plist-initial-value"
  (let ((store (make-test-secret-store :initial (list "a" "1" "b" "2"))))
    (expect (string= "1" (secret-get store "a")) :to-be-truthy)
    (expect (string= "2" (secret-get store "b")) :to-be-truthy)))

(it "test-secret-store-enumerates-names-sorted"
  (let ((store (make-test-secret-store :initial '(("db" . "x") ("api" . "y")))))
    (expect (equal (list "api" "db") (secret-names store)) :to-be-truthy))
  (expect (null (secret-names (make-test-secret-store))) :to-be-truthy))

(it "native-secret-names-is-unsupported-without-a-names-fn"
  (signals cl-boundary-kit:unsupported-boundary-operation
    (secret-names (make-secret-store :get-fn (lambda (n d) (declare (ignore n)) (values d nil))))))

(it "recording-secret-store-records-names-verbatim-not-redacted"
  (let ((store (make-recording-secret-store
                :delegate (make-test-secret-store :initial '(("api" . "y"))))))
    (expect (equal (list "api") (secret-names store)) :to-be-truthy)
    (expect (equal (list (boundary-call-plist :names '() :result (list "api")))
                   (recording-secret-calls store)) :to-be-truthy)))

(it "make-secret-store-wires-an-injected-get-fn"
  (let ((store (make-secret-store
                :get-fn (lambda (name default)
                          (declare (ignore default))
                          (values (concatenate 'string "secret-of-" name) t)))))
    (expect (string= "secret-of-x" (secret-get store "x")) :to-be-truthy)))

(it "make-secret-store-rejects-a-non-function-get-fn"
  (signals error
    (make-secret-store :get-fn :bad)))

(it "recording-secret-store-redacts-the-value-and-omits-the-default"
  (let* ((delegate (make-test-secret-store :initial '(("token" . "abc"))))
         (store (make-recording-secret-store :delegate delegate)))
    ;; The caller still receives the real value.
    (expect (string= "abc" (secret-get store "token" :fallback)) :to-be-truthy)
    ;; But the history records only the name and a redacted marker.
    (expect (equal (recording-secret-calls store)
                   (list (boundary-call-plist :get (list "token") :result :redacted))) :to-be-truthy)))

(it "recording-secret-store-preserves-the-present-p-secondary-value"
  (let ((store (make-recording-secret-store
                :delegate (make-test-secret-store :initial '(("token" . "abc"))))))
    (multiple-value-bind (value present) (secret-get store "token")
      (expect (string= "abc" value) :to-be-truthy)
      (expect (eq t present) :to-be-truthy))))

(it "make-recording-secret-store-rejects-a-non-secret-store-delegate"
  (signals error
    (make-recording-secret-store :delegate :bad)))

(it "recording-secret-calls-signals-for-unsupported-store-types"
  (signals error
    (recording-secret-calls (make-test-secret-store))))

(it "reset-recording-secret-calls-clears-history-and-returns-the-store"
  (let ((store (make-recording-secret-store)))
    (secret-get store "token")
    (expect (= 1 (length (recording-secret-calls store))) :to-be-truthy)
    (expect (eq store (reset-recording-secret-calls store)) :to-be-truthy)
    (expect (null (recording-secret-calls store)) :to-be-truthy)))

(it "reset-recording-secret-calls-signals-for-unsupported-store-types"
  (signals error
    (reset-recording-secret-calls (make-test-secret-store))))
