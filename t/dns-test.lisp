;;;; t/dns-test.lisp

(in-package #:cl-boundary-kit/test)

(it "test-dns-resolver-returns-mapped-addresses"
  (let ((resolver (make-test-dns-resolver
                   :hosts '(("a.test" . ("10.0.0.1" "10.0.0.2"))
                            ("b.test" . ("10.0.0.3"))))))
    (expect (equal (list "10.0.0.1" "10.0.0.2") (dns-resolve resolver "a.test")) :to-be-truthy)
    (expect (equal (list "10.0.0.3") (dns-resolve resolver "b.test")) :to-be-truthy)))

(it "test-dns-resolver-signals-for-an-unknown-hostname"
  (let ((resolver (make-test-dns-resolver :hosts '(("a.test" . ("10.0.0.1"))))))
    (signals error
      (dns-resolve resolver "missing.test"))))

(it "test-dns-resolver-accepts-a-plist-of-hosts"
  (let ((resolver (make-test-dns-resolver :hosts (list "a.test" (list "10.0.0.1")))))
    (expect (equal (list "10.0.0.1") (dns-resolve resolver "a.test")) :to-be-truthy)))

(it "make-test-dns-resolver-rejects-non-string-addresses"
  (signals error
    (make-test-dns-resolver :hosts '(("a.test" . (42))))))

(it "dns-resolve-rejects-a-non-string-hostname"
  (signals error
    (dns-resolve (make-test-dns-resolver) 42)))

(it "make-dns-resolver-wires-an-injected-resolve-fn"
  (let ((resolver (make-dns-resolver
                   :resolve-fn (lambda (hostname)
                                 (list (concatenate 'string "addr-of-" hostname))))))
    (expect (equal (list "addr-of-x.test") (dns-resolve resolver "x.test")) :to-be-truthy)))

(it "make-dns-resolver-rejects-a-non-function-resolve-fn"
  (signals error
    (make-dns-resolver :resolve-fn :bad)))

(it "recording-dns-resolver-records-lookups"
  (let* ((delegate (make-test-dns-resolver :hosts '(("a.test" . ("10.0.0.1")))))
         (resolver (make-recording-dns-resolver :delegate delegate)))
    (dns-resolve resolver "a.test")
    (expect (equal (recording-dns-calls resolver)
                   (list (boundary-call-plist :resolve (list "a.test")
                                              :result (list "10.0.0.1")))) :to-be-truthy)))

(it "make-recording-dns-resolver-rejects-a-non-resolver-delegate"
  (signals error
    (make-recording-dns-resolver :delegate :bad)))

(it "recording-dns-calls-signals-for-unsupported-resolver-types"
  (signals error
    (recording-dns-calls (make-test-dns-resolver))))

(it "reset-recording-dns-calls-clears-history-and-returns-the-resolver"
  (let ((resolver (make-recording-dns-resolver
                   :delegate (make-test-dns-resolver :hosts '(("a.test" . ("10.0.0.1")))))))
    (dns-resolve resolver "a.test")
    (expect (= 1 (length (recording-dns-calls resolver))) :to-be-truthy)
    (expect (eq resolver (reset-recording-dns-calls resolver)) :to-be-truthy)
    (expect (null (recording-dns-calls resolver)) :to-be-truthy)))

(it "reset-recording-dns-calls-signals-for-unsupported-resolver-types"
  (signals error
    (reset-recording-dns-calls (make-test-dns-resolver))))
