;;;; t/env-native-test.lisp

(in-package #:cl-boundary-kit/test)

(it "make-environment-can-preserve-explicit-nil"
  (let ((env (make-environment
              :get-fn (lambda (name)
                        (declare (ignore name))
                        (values nil t)))))
    (expect (null (environment-get env "EMPTY" "fallback")) :to-be-truthy)))

(it "environment-present-p-accepts-custom-getters"
  (let ((env (make-environment
              :get-fn (lambda (name)
                        (cond
                          ((string= name "EXPLICIT-NIL") (values nil t))
                          ((string= name "MISSING") (values nil nil))
                          (t "value"))))))
    (expect (environment-present-p env "EXPLICIT-NIL") :to-be-truthy)
    (expect (null (environment-present-p env "MISSING")) :to-be-truthy)
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

(it "native-environment-set-and-unset-mutate-the-real-process-environment"
  ;; make-environment's SET-FN/UNSET-FN now default to a real cl-host-kit
  ;; backend instead of erroring; CALL-WITH-ENVIRONMENT-VARIABLE restores the
  ;; prior (absent) binding afterward so this leaves no trace on the process.
  (let ((environment (make-environment)))
    (call-with-environment-variable
     environment "CL_BOUNDARY_KIT_NATIVE_ENV_TEST" "probe-value"
     (lambda ()
       (expect
         (equal (environment-get environment "CL_BOUNDARY_KIT_NATIVE_ENV_TEST") "probe-value")
         :to-be-truthy)))
    (expect
      (null (environment-present-p environment "CL_BOUNDARY_KIT_NATIVE_ENV_TEST"))
      :to-be-truthy)))

(it "make-environment-rejects-non-function-collaborators"
  (signals error
    (make-environment :get-fn :bad))
  (signals error
    (make-environment :set-fn :bad))
  (signals error
    (make-environment :list-fn :bad)))

(it "native-environment-list-and-get-read-the-real-process-environment"
  ;; Exercises the native reader path (%native-environment-list, the CPS entry
  ;; splitter, and %native-environment-get) rather than a test double.
  (let ((environment (make-environment)))
    (expect (listp (environment-list environment)) :to-be-truthy)
    ;; PATH is present in essentially every process environment.
    (expect (stringp (environment-get environment "PATH")) :to-be-truthy)))

(it "split-environment-entry-handles-entries-with-and-without-a-separator"
  ;; The else arm (no #\=) maps the whole entry to a NAME with an empty value.
  (expect (equal (cl-boundary-kit::%split-environment-entry "NAME=value")
                 (cons "NAME" "value"))
          :to-be-truthy)
  (expect (equal (cl-boundary-kit::%split-environment-entry "BARE")
                 (cons "BARE" ""))
          :to-be-truthy))
