;;;; t/system-test.lisp

(in-package #:cl-boundary-kit/test)

(describe "native system boundary"
  (it "make-system-boundary-invokes-its-exit-function-with-the-code"
    (let* ((requested (list))
           (system (make-system-boundary
                    :exit-fn (lambda (code) (push code requested) :exited))))
      (expect (system-exit system 3) :to-be :exited)
      (expect requested :to-equal (list 3))))

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
      (expect requested :to-equal '(0))))

  (it "make-system-boundary-rejects-a-non-function-exit-fn"
    (signals error
      (make-system-boundary :exit-fn :bad)))

  ;; %DEFAULT-SYSTEM-EXIT -- MAKE-SYSTEM-BOUNDARY's &KEY default -- is the only
  ;; path that actually terminates the process, so every test above supplies a
  ;; non-terminating :EXIT-FN instead. Exercise %DEFAULT-SYSTEM-EXIT directly,
  ;; stubbing HOST-KIT:QUIT so the call is observed rather than actually exiting.
  (it "default-system-exit-calls-host-kit-quit-with-the-code"
    (let ((requested '())
          (original (symbol-function 'host-kit:quit)))
      (unwind-protect
           (progn
             (setf (symbol-function 'host-kit:quit)
                   (lambda (code) (push code requested) :exited))
             (expect (cl-boundary-kit::%default-system-exit 7) :to-be :exited)
             (expect requested :to-equal '(7)))
        (setf (symbol-function 'host-kit:quit) original)))))

(describe "test system boundary"
  (it "test-system-boundary-records-exit-codes-without-terminating"
    (let ((system (make-test-system-boundary)))
      (expect (system-exit system) :to-be 0)
      (expect (system-exit system 2) :to-be 2)
      (expect (test-system-exit-codes system) :to-equal (list 0 2))))

  (it "system-exit-rejects-negative-and-non-integer-codes"
    (let ((system (make-test-system-boundary)))
      (signals error
        (system-exit system -1))
      (signals error
        (system-exit system 1.5d0))))

  (it "test-system-exit-codes-signals-for-unsupported-system-types"
    (signals error
      (test-system-exit-codes (make-recording-system-boundary)))))

(describe "recording system boundary"
  (it "recording-system-boundary-records-exit-requests"
    (let ((system (make-recording-system-boundary)))
      (expect (system-exit system) :to-be 0)
      (expect (system-exit system 1) :to-be 1)
      (expect (recording-system-calls system)
              :to-have-recorded-calls (list (boundary-call-plist :exit (list 0) :result 0)
                                            (boundary-call-plist :exit (list 1) :result 1)))))

  (it "make-recording-system-boundary-rejects-a-non-system-delegate"
    (signals error
      (make-recording-system-boundary :delegate :bad)))

  (it-each ((recording-system-calls)
            (reset-recording-system-calls))
      "~A signals for unsupported system types"
      (operation)
    (expect (lambda () (funcall operation (make-test-system-boundary))) :to-throw "Unsupported system boundary type"))

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
      (expect (lambda () (system-exit system :invalid)) :to-throw "SYSTEM-EXIT code must be a non-negative integer")
      (with-soft-assertions
        (expect delegated-codes :to-equal (list))
        (expect (recording-system-calls system) :to-equal (list))
        (expect (system-exit system 9) :to-be :delegated)
        (expect delegated-codes :to-equal (list 9))
        (expect (recording-system-calls system)
                :to-equal (list (boundary-call-plist :exit (list 9) :result :delegated)))))))

(describe "native system boundary validation"
  (it "native-system-boundary-rejects-invalid-codes-before-calling-exit-function"
    (let* ((called (list))
          (system (make-system-boundary :exit-fn (lambda (code) (push code called)))))
      (expect (lambda () (system-exit system :invalid)) :to-throw "SYSTEM-EXIT code must be a non-negative integer")
      (expect called :to-equal (list)))))
