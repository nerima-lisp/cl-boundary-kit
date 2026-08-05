;;;; t/secret-test.lisp

(in-package #:cl-boundary-kit/test)

(describe "test-secret-store"
  (it "test-secret-store-reads-values-with-present-p"
    (let ((store (make-test-secret-store :initial '(("token" . "abc")))))
      (multiple-value-bind (value present) (secret-get store "token")
        (expect value :to-equal "abc")
        (expect present :to-be t))
      (multiple-value-bind (value present) (secret-get store "missing" :fallback)
        (expect value :to-be :fallback)
        (expect present :to-be-null))))

  (it "test-secret-store-distinguishes-a-stored-nil-from-a-missing-secret"
    (let ((store (make-test-secret-store)))
      (multiple-value-bind (value present) (secret-get store "absent" :default)
        (expect value :to-be :default)
        (expect present :to-be-null))))

  (it "test-secret-store-accepts-a-plist-initial-value"
    (let ((store (make-test-secret-store :initial (list "a" "1" "b" "2"))))
      (expect (secret-get store "a") :to-equal "1")
      (expect (secret-get store "b") :to-equal "2")))

  (it "test-secret-store-enumerates-names-sorted"
    (let ((store (make-test-secret-store :initial '(("db" . "x") ("api" . "y")))))
      (expect (secret-names store) :to-equal (list "api" "db")))
    (expect (secret-names (make-test-secret-store)) :to-be-null)))

(describe "make-secret-store"
  (it "native-secret-names-is-unsupported-without-a-names-fn"
    (signals cl-boundary-kit:unsupported-boundary-operation
      (secret-names (make-secret-store :get-fn (lambda (n d) (declare (ignore n)) (values d nil))))))

  (it "make-secret-store-wires-an-injected-get-fn"
    (let ((store (make-secret-store
                  :get-fn (lambda (name default)
                            (declare (ignore default))
                            (values (concatenate 'string "secret-of-" name) t)))))
      (expect (secret-get store "x") :to-equal "secret-of-x")))

  (it "make-secret-store-rejects-a-non-function-get-fn"
    (signals error
      (make-secret-store :get-fn :bad)))

  (it "secret-names-returns-the-names-fn-result"
    (let ((store (make-secret-store :get-fn (lambda (name) (declare (ignore name)) (values nil nil))
                                    :names-fn (lambda () (list "API_KEY" "DB_PASSWORD")))))
      (expect (secret-names store) :to-equal (list "API_KEY" "DB_PASSWORD")))))

(describe "recording-secret-store"
  (it "recording-secret-store-records-names-verbatim-not-redacted"
    (let ((store (make-recording-secret-store
                  :delegate (make-test-secret-store :initial '(("api" . "y"))))))
      (expect (secret-names store) :to-equal (list "api"))
      (expect (recording-secret-calls store) :to-have-recorded-calls (list (boundary-call-plist :names '() :result (list "api"))))))

  (it "recording-secret-store-redacts-the-value-and-omits-the-default"
    (let* ((delegate (make-test-secret-store :initial '(("token" . "abc"))))
           (store (make-recording-secret-store :delegate delegate)))
      ;; The caller still receives the real value.
      (expect (secret-get store "token" :fallback) :to-equal "abc")
      ;; But the history records only the name and a redacted marker.
      (expect (recording-secret-calls store) :to-have-recorded-calls (list (boundary-call-plist :get (list "token") :result :redacted)))))

  (it "recording-secret-store-preserves-the-present-p-secondary-value"
    (let ((store (make-recording-secret-store
                  :delegate (make-test-secret-store :initial '(("token" . "abc"))))))
      (multiple-value-bind (value present) (secret-get store "token")
        (expect value :to-equal "abc")
        (expect present :to-be t))))

  (it "make-recording-secret-store-rejects-a-non-secret-store-delegate"
    (signals error
      (make-recording-secret-store :delegate :bad)))

  (it-each ((recording-secret-calls)
            (reset-recording-secret-calls))
      "~A signals for unsupported store types"
      (operation)
    (expect (lambda () (funcall operation (make-test-secret-store))) :to-throw "Unsupported secret store type"))

  (deftest-reset-recording-clears-history
      "reset-recording-secret-calls-clears-history-and-returns-the-store"
      (store (make-recording-secret-store))
      (recording-secret-calls reset-recording-secret-calls)
    (secret-get store "token")))
