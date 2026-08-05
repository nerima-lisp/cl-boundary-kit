;;;; t/env-native-test.lisp

(in-package #:cl-boundary-kit/test)

(describe "native environment collaborators"
  (it "make-environment-can-preserve-explicit-nil"
    (let ((env (make-environment
                :get-fn (lambda (name)
                          (declare (ignore name))
                          (values nil t)))))
      (expect (environment-get env "EMPTY" "fallback") :to-be-null)))

  (it "environment-present-p-accepts-custom-getters"
    (let ((env (make-environment
                :get-fn (lambda (name)
                          (cond
                            ((string= name "EXPLICIT-NIL") (values nil t))
                            ((string= name "MISSING") (values nil nil))
                            (t "value"))))))
      (expect (environment-present-p env "EXPLICIT-NIL") :to-be-truthy)
      (expect (environment-present-p env "MISSING") :to-be-null)
      (expect (environment-present-p env "OTHER") :to-be-truthy)))

  (it "make-environment-signals-unsupported-on-set-without-setter"
    (let ((env (make-environment :set-fn nil)))
      (signals-unsupported-boundary-operation
          (environment-set "native environment mutation is unavailable")
        (environment-set env "A" "1"))))

  (it "make-environment-signals-unsupported-on-unset-without-unsetter"
    (let ((env (make-environment :unset-fn nil)))
      (signals-unsupported-boundary-operation
          (environment-unset "native environment mutation is unavailable")
        (environment-unset env "A"))))

  (it "make-environment-rejects-non-function-collaborators"
    (signals error
      (make-environment :get-fn :bad))
    (signals error
      (make-environment :set-fn :bad))
    (signals error
      (make-environment :list-fn :bad))))

(describe "native environment against the real process"
  (it "native-environment-set-and-unset-mutate-the-real-process-environment"
    ;; make-environment's SET-FN/UNSET-FN now default to a real cl-host-kit
    ;; backend instead of erroring; CALL-WITH-ENVIRONMENT-VARIABLE restores the
    ;; prior (absent) binding afterward so this leaves no trace on the process.
    (let ((environment (make-environment)))
      (call-with-environment-variable
       environment "CL_BOUNDARY_KIT_NATIVE_ENV_TEST" "probe-value"
       (lambda ()
         (expect (environment-get environment "CL_BOUNDARY_KIT_NATIVE_ENV_TEST") :to-equal "probe-value")))
      (expect (environment-present-p environment "CL_BOUNDARY_KIT_NATIVE_ENV_TEST") :to-be-null)))

  (it "native-environment-list-and-get-read-the-real-process-environment"
    ;; Exercises the native reader path (%native-environment-list, the CPS entry
    ;; splitter, and %native-environment-get) rather than a test double.
    (let ((environment (make-environment)))
      (expect (environment-list environment) :to-be-type-of 'list)
      ;; PATH is present in essentially every process environment.
      (expect (environment-get environment "PATH") :to-be-type-of 'string))))

(describe "native environment entry parsing"
  (it "split-environment-entry-handles-entries-with-and-without-a-separator"
    ;; The else arm (no #\=) maps the whole entry to a NAME with an empty value.
    (expect (cl-boundary-kit::%split-environment-entry "NAME=value") :to-equal (cons "NAME" "value"))
    (expect (cl-boundary-kit::%split-environment-entry "BARE") :to-equal (cons "BARE" ""))))
