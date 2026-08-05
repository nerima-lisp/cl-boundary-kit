;;;; t/host-info-test.lisp

(in-package #:cl-boundary-kit/test)

(describe "host-info"
  (it "test-host-info-returns-fixed-values"
    (let ((host (make-test-host-info :hostname "h" :username "u" :pid 7)))
      (expect (host-info-hostname host) :to-equal "h")
      (expect (host-info-username host) :to-equal "u")
      (expect (host-info-pid host) :to-be 7)))

  (it "make-test-host-info-rejects-invalid-values"
    (signals error
      (make-test-host-info :hostname 42))
    (signals error
      (make-test-host-info :pid -1)))

  (it "make-test-host-info-rejects-a-non-string-username"
    (expect (lambda () (make-test-host-info :username 42)) :to-throw "User name must be a string"))

  (it "make-host-info-reads-injected-collaborators"
    (let ((host (make-host-info
                 :hostname-fn (lambda () "injected-host")
                 :username-fn (lambda () "injected-user")
                 :pid-fn (lambda () 99))))
      (expect (host-info-hostname host) :to-equal "injected-host")
      (expect (host-info-username host) :to-equal "injected-user")
      (expect (host-info-pid host) :to-be 99)))

  (it "make-host-info-defaults-reflect-the-running-process"
    (let ((host (make-host-info)))
      (expect (host-info-hostname host) :to-be-type-of 'string)
      (expect (host-info-username host) :to-be-type-of 'string)
      (expect (host-info-pid host) :to-be-type-of 'integer)))

  (it "make-host-info-rejects-non-function-collaborators"
    (signals error
      (make-host-info :hostname-fn :bad))))

(describe "recording-host-info"
  (it "recording-host-info-records-reads"
    (let* ((delegate (make-test-host-info :hostname "h" :username "u" :pid 7))
           (host (make-recording-host-info :delegate delegate)))
      (host-info-hostname host)
      (host-info-username host)
      (host-info-pid host)
      (expect (recording-host-info-calls host)
              :to-have-recorded-calls
              (list (boundary-call-plist :hostname '() :result "h")
                    (boundary-call-plist :username '() :result "u")
                    (boundary-call-plist :pid '() :result 7)))))

  (it "make-recording-host-info-rejects-a-non-host-info-delegate"
    (signals error
      (make-recording-host-info :delegate :bad)))

  (it-each ((recording-host-info-calls)
            (reset-recording-host-info-calls))
      "~A signals for unsupported host-info types"
      (operation)
    (expect (lambda () (funcall operation (make-test-host-info))) :to-throw "Unsupported host-info type"))

  (it "reset-recording-host-info-calls-clears-history-and-returns-it"
    (let ((host (make-recording-host-info)))
      (host-info-hostname host)
      (expect (recording-host-info-calls host) :to-have-length 1)
      (expect (reset-recording-host-info-calls host) :to-be host)
      (expect (recording-host-info-calls host) :to-be-null))))
