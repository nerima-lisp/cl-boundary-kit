;;;; src/system.lisp

(in-package #:cl-boundary-kit)

(defun %validate-exit-code (code)
  (unless (and (integerp code) (>= code 0))
    (error "SYSTEM-EXIT code must be a non-negative integer: ~S" code))
  code)

(defun %default-system-exit (code)
  ;; Resolve the host exit entrypoint at call time via FIND-SYMBOL rather than a
  ;; read-time UIOP: package reference, so this file still loads in environments
  ;; that have not loaded ASDF/UIOP (for example the examples bootstrap, which
  ;; loads the sources directly with a bare `sbcl --script`).
  (let ((quit (and (find-package "UIOP")
                   (find-symbol "QUIT" "UIOP"))))
    (if quit
        (funcall quit code)
        (unsupported-operation 'system-exit
                               "no host exit function is available"))))

(defun make-system-boundary (&key (exit-fn #'%default-system-exit))
  "Create a system boundary whose `system-exit` calls EXIT-FN.

EXIT-FN receives the requested exit code. The default terminates the process
through `uiop:quit`, so this is the only path that actually exits."
  (require-function exit-fn "EXIT-FN")
  (make-instance 'system-boundary :exit-fn exit-fn))

(defun make-test-system-boundary ()
  "Create a system boundary that records exit codes instead of exiting.

Each `system-exit` call captures the requested code and returns it without
terminating the process, so tests can assert that code requested termination.
The captured codes are available through `test-system-exit-codes`."
  (make-instance 'test-system-boundary :exit-fn nil))

(defun test-system-exit-codes (system)
  "Return the exit codes requested through SYSTEM, oldest first."
  (unless (typep system 'test-system-boundary)
    (error "Unsupported system boundary type: ~S" system))
  (reverse (%test-system-exit-codes system)))

(define-recording-boundary-constructor make-recording-system-boundary
    recording-system-boundary system-boundary (make-test-system-boundary)
  "Create a system boundary that records exit requests while delegating to DELEGATE.

DELEGATE defaults to a non-terminating `make-test-system-boundary`, so a
recording system boundary never exits the process unless you pass a delegate
that does."
  :exit-fn nil)

(define-recording-call-log recording-system-calls reset-recording-system-calls
    (system recording-system-boundary %recording-system-calls) "system boundary")

(defmethod system-exit ((system system-boundary) &optional (code 0))
  (%validate-exit-code code)
  (funcall (system-boundary-exit-fn system) code))

(defmethod system-exit ((system test-system-boundary) &optional (code 0))
  (%validate-exit-code code)
  (push code (%test-system-exit-codes system))
  code)

(define-recording-delegate-method system-exit
    (system recording-system-boundary recording-system-boundary-delegate %recording-system-calls)
    ((&optional (code 0)) (code)) :exit (list code)
  (%validate-exit-code code))
