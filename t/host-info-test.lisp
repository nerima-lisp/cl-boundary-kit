;;;; t/host-info-test.lisp

(in-package #:cl-boundary-kit/test)

(it "test-host-info-returns-fixed-values"
  (let ((host (make-test-host-info :hostname "h" :username "u" :pid 7)))
    (expect (string= "h" (host-info-hostname host)) :to-be-truthy)
    (expect (string= "u" (host-info-username host)) :to-be-truthy)
    (expect (= 7 (host-info-pid host)) :to-be-truthy)))

(it "make-test-host-info-rejects-invalid-values"
  (signals error
    (make-test-host-info :hostname 42))
  (signals error
    (make-test-host-info :pid -1)))

(it "make-host-info-reads-injected-collaborators"
  (let ((host (make-host-info
               :hostname-fn (lambda () "injected-host")
               :username-fn (lambda () "injected-user")
               :pid-fn (lambda () 99))))
    (expect (string= "injected-host" (host-info-hostname host)) :to-be-truthy)
    (expect (string= "injected-user" (host-info-username host)) :to-be-truthy)
    (expect (= 99 (host-info-pid host)) :to-be-truthy)))

(it "make-host-info-defaults-reflect-the-running-process"
  (let ((host (make-host-info)))
    (expect (stringp (host-info-hostname host)) :to-be-truthy)
    (expect (stringp (host-info-username host)) :to-be-truthy)
    (expect (integerp (host-info-pid host)) :to-be-truthy)))

(it "make-host-info-rejects-non-function-collaborators"
  (signals error
    (make-host-info :hostname-fn :bad)))

(it "recording-host-info-records-reads"
  (let* ((delegate (make-test-host-info :hostname "h" :username "u" :pid 7))
         (host (make-recording-host-info :delegate delegate)))
    (host-info-hostname host)
    (host-info-username host)
    (host-info-pid host)
    (expect (equal (recording-host-info-calls host)
                   (list (boundary-call-plist :hostname '() :result "h")
                         (boundary-call-plist :username '() :result "u")
                         (boundary-call-plist :pid '() :result 7))) :to-be-truthy)))

(it "make-recording-host-info-rejects-a-non-host-info-delegate"
  (signals error
    (make-recording-host-info :delegate :bad)))

(it-each ((recording-host-info-calls)
          (reset-recording-host-info-calls))
    "~A signals for unsupported host-info types"
    (operation)
  (expect (lambda () (funcall operation (make-test-host-info)))
          :to-signal-message-containing "Unsupported host-info type"))

(it "reset-recording-host-info-calls-clears-history-and-returns-it"
  (let ((host (make-recording-host-info)))
    (host-info-hostname host)
    (expect (= 1 (length (recording-host-info-calls host))) :to-be-truthy)
    (expect (eq host (reset-recording-host-info-calls host)) :to-be-truthy)
    (expect (null (recording-host-info-calls host)) :to-be-truthy)))

(it "make-test-host-info-rejects-a-non-string-username"
  (signals-error-message-contains "User name must be a string"
    (make-test-host-info :username 42)))
