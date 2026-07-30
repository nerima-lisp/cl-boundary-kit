;;;; t/system-test.lisp

(in-package #:cl-boundary-kit/test)

(it "make-system-boundary-invokes-its-exit-function-with-the-code"
  (let* ((requested (list))
         (system (make-system-boundary
                  :exit-fn (lambda (code) (push code requested) :exited))))
    (expect (eq :exited (system-exit system 3)) :to-be-truthy)
    (expect (equal (list 3) requested) :to-be-truthy)))

(it "make-system-boundary-uses-host-kit-quit-by-default"
  (let ((original (symbol-function 'host-kit:quit))
        (received nil))
    (unwind-protect
         (progn
           (setf (symbol-function 'host-kit:quit)
                 (lambda (code)
                   (setf received code)
                   :quit-requested))
           (expect (system-exit (make-system-boundary) 17) :to-be :quit-requested)
           (expect received :to-be 17))
      (setf (symbol-function 'host-kit:quit) original))))

(it "make-system-boundary-defaults-the-exit-code-to-zero"
  (let* ((requested '())
         (system (make-system-boundary
                  :exit-fn (lambda (code) (push code requested)))))
    (system-exit system)
    (expect (equal '(0) requested) :to-be-truthy)))

(it "make-system-boundary-rejects-a-non-function-exit-fn"
  (signals error
    (make-system-boundary :exit-fn :bad)))

;; %DEFAULT-SYSTEM-EXIT -- MAKE-SYSTEM-BOUNDARY's &KEY default -- is the only
;; path that actually terminates the process, so every test above supplies a
;; non-terminating :EXIT-FN instead. Exercise %DEFAULT-SYSTEM-EXIT directly,
;; stubbing UIOP:QUIT so the call is observed rather than actually exiting.
(it "default-system-exit-calls-uiop-quit-with-the-code"
  (let ((requested '())
        (original (symbol-function 'uiop:quit)))
    (unwind-protect
         (progn
           (setf (symbol-function 'uiop:quit)
                 (lambda (code) (push code requested) :exited))
           (expect (eq :exited (cl-boundary-kit::%default-system-exit 7)) :to-be-truthy)
           (expect (equal '(7) requested) :to-be-truthy))
      (setf (symbol-function 'uiop:quit) original))))

;; Complements the test above: when no UIOP:QUIT is reachable at all,
;; %DEFAULT-SYSTEM-EXIT reports the missing host support instead of erroring
;; on the FUNCALL.
(it "default-system-exit-reports-missing-host-support"
  (let* ((uiop-package (find-package "UIOP"))
         (original-name (package-name uiop-package))
         (original-nicknames (package-nicknames uiop-package))
         (placeholder-package nil))
    (unwind-protect
         (progn
           (rename-package uiop-package "CL-BOUNDARY-KIT-HIDDEN-UIOP")
           (setf placeholder-package (make-package "UIOP"))
           (signals-error-message-contains
               "no host exit function is available"
             (cl-boundary-kit::%default-system-exit 0)))
      (when placeholder-package
        (delete-package placeholder-package))
      (rename-package uiop-package original-name original-nicknames))))

(it "test-system-boundary-records-exit-codes-without-terminating"
  (let ((system (make-test-system-boundary)))
    (expect (= 0 (system-exit system)) :to-be-truthy)
    (expect (= 2 (system-exit system 2)) :to-be-truthy)
    (expect (equal (list 0 2) (test-system-exit-codes system)) :to-be-truthy)))

(it "system-exit-rejects-negative-and-non-integer-codes"
  (let ((system (make-test-system-boundary)))
    (signals error
      (system-exit system -1))
    (signals error
      (system-exit system 1.5d0))))

(it "test-system-exit-codes-signals-for-unsupported-system-types"
  (signals error
    (test-system-exit-codes (make-recording-system-boundary))))

(it "recording-system-boundary-records-exit-requests"
  (let ((system (make-recording-system-boundary)))
    (expect (= 0 (system-exit system)) :to-be-truthy)
    (expect (= 1 (system-exit system 1)) :to-be-truthy)
    (expect (equal (recording-system-calls system)
                   (list (boundary-call-plist :exit (list 0) :result 0)
                         (boundary-call-plist :exit (list 1) :result 1))) :to-be-truthy)))

(it "make-recording-system-boundary-rejects-a-non-system-delegate"
  (signals error
    (make-recording-system-boundary :delegate :bad)))

(it-each ((recording-system-calls)
          (reset-recording-system-calls))
    "~A signals for unsupported system types"
    (operation)
  (expect (lambda () (funcall operation (make-test-system-boundary)))
          :to-signal-message-containing "Unsupported system boundary type"))

(deftest-reset-recording-clears-history
    "reset-recording-system-calls-clears-history-and-returns-the-system"
    (system (make-recording-system-boundary))
    (recording-system-calls reset-recording-system-calls)
  (system-exit system 0))
(it "recording-system-boundary-records-delegate-results-only-after-successful-validation"
  (let* ((delegated-codes (list))
         (delegate (make-system-boundary
                    :exit-fn (lambda (code)
                               (push code delegated-codes)
                               :delegated)))
         (system (make-recording-system-boundary :delegate delegate)))
    (signals-error-message-contains "SYSTEM-EXIT code must be a non-negative integer"
      (system-exit system :invalid))
    (with-soft-assertions
      (expect delegated-codes :to-equal (list))
      (expect (recording-system-calls system) :to-equal (list))
      (expect (system-exit system 9) :to-be :delegated)
      (expect delegated-codes :to-equal (list 9))
      (expect (recording-system-calls system)
              :to-equal (list (boundary-call-plist :exit (list 9) :result :delegated))))))

(it "native-system-boundary-rejects-invalid-codes-before-calling-exit-function"
  (let* ((called (list))
        (system (make-system-boundary :exit-fn (lambda (code) (push code called)))))
    (signals-error-message-contains "SYSTEM-EXIT code must be a non-negative integer"
      (system-exit system :invalid))
    (expect called :to-equal (list))))
