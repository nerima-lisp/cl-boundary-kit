;;;; t/dns-test.lisp

(in-package #:cl-boundary-kit/test)

(describe "test dns resolver"
  (it "test-dns-resolver-returns-mapped-addresses"
    (let ((resolver (make-test-dns-resolver
                     :hosts '(("a.test" . ("10.0.0.1" "10.0.0.2"))
                              ("b.test" . ("10.0.0.3"))))))
      (expect (dns-resolve resolver "a.test") :to-equal (list "10.0.0.1" "10.0.0.2"))
      (expect (dns-resolve resolver "b.test") :to-equal (list "10.0.0.3"))))

  (it "test-dns-resolver-signals-for-an-unknown-hostname"
    (let ((resolver (make-test-dns-resolver :hosts '(("a.test" . ("10.0.0.1"))))))
      (signals error
        (dns-resolve resolver "missing.test"))))

  (it "test-dns-resolver-accepts-a-plist-of-hosts"
    (let ((resolver (make-test-dns-resolver :hosts (list "a.test" (list "10.0.0.1")))))
      (expect (dns-resolve resolver "a.test") :to-equal (list "10.0.0.1"))))

  (it "test-dns-resolver-copies-seeded-address-lists"
    (let* ((addresses (list "10.0.0.1" "10.0.0.2"))
           (resolver (make-test-dns-resolver
                      :hosts (list (cons "a.test" addresses)))))
      (setf (first addresses) "127.0.0.1"
            (rest addresses) nil)
      (expect (dns-resolve resolver "a.test") :to-equal (list "10.0.0.1" "10.0.0.2"))))

  (it "make-test-dns-resolver-rejects-non-string-addresses"
    (signals error
      (make-test-dns-resolver :hosts '(("a.test" . (42))))))

  (it "dns-resolve-rejects-a-non-string-hostname"
    (signals error
      (dns-resolve (make-test-dns-resolver) 42)))

  (it "make-test-dns-resolver-rejects-non-list-addresses"
    (expect (lambda () (make-test-dns-resolver :hosts '(("a.test" . "not-a-list")))) :to-throw "DNS addresses for")))

(describe "native dns resolver"
  (it "make-dns-resolver-wires-an-injected-resolve-fn"
    (let ((resolver (make-dns-resolver
                     :resolve-fn (lambda (hostname)
                                   (list (concatenate 'string "addr-of-" hostname))))))
      (expect (dns-resolve resolver "x.test") :to-equal (list "addr-of-x.test"))))

  (it "make-dns-resolver-rejects-a-non-function-resolve-fn"
    (signals error
      (make-dns-resolver :resolve-fn :bad))))

(describe "recording dns resolver"
  (it "recording-dns-resolver-records-lookups"
    (let* ((delegate (make-test-dns-resolver :hosts '(("a.test" . ("10.0.0.1")))))
           (resolver (make-recording-dns-resolver :delegate delegate)))
      (dns-resolve resolver "a.test")
      (expect (recording-dns-calls resolver)
              :to-have-recorded-calls (list (boundary-call-plist :resolve (list "a.test")
                                                                :result (list "10.0.0.1"))))))

  (it "make-recording-dns-resolver-rejects-a-non-resolver-delegate"
    (signals error
      (make-recording-dns-resolver :delegate :bad)))

  (it-each ((recording-dns-calls)
            (reset-recording-dns-calls))
      "~A signals for unsupported resolver types"
      (operation)
    (expect (lambda () (funcall operation (make-test-dns-resolver))) :to-throw "Unsupported DNS resolver type"))

  (deftest-reset-recording-clears-history
      "reset-recording-dns-calls-clears-history-and-returns-the-resolver"
      (resolver (make-recording-dns-resolver
                 :delegate (make-test-dns-resolver :hosts '(("a.test" . ("10.0.0.1"))))))
      (recording-dns-calls reset-recording-dns-calls)
    (dns-resolve resolver "a.test"))

  (it "dns-resolver-validates-addresses-and-recording-defaults" (expect (lambda () (make-test-dns-resolver :hosts (quote (("a.test" . (42)))))) :to-throw "DNS address for") (let ((resolver (make-recording-dns-resolver))) (signals error (dns-resolve resolver "missing.test")))))

