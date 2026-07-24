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
  (let ((env (make-environment)))
    (signals-unsupported-boundary-operation
        (environment-set "native environment mutation is unavailable")
      (environment-set env "A" "1"))))

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

(it "split-environment-entry-cps-handles-entries-with-and-without-a-separator"
  ;; The else arm (no #\=) maps the whole entry to a NAME with an empty value.
  (cl-boundary-kit::%split-environment-entry-cps
   "NAME=value"
   (lambda (binding) (expect (equal binding (cons "NAME" "value")) :to-be-truthy)))
  (cl-boundary-kit::%split-environment-entry-cps
   "BARE"
   (lambda (binding) (expect (equal binding (cons "BARE" "")) :to-be-truthy))))
