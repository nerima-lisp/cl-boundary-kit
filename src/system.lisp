;;;; src/system.lisp

(in-package #:cl-boundary-kit)

(defclass system-boundary ()
  ((exit-fn :initarg :exit-fn :reader system-boundary-exit-fn)))

(defclass test-system-boundary (system-boundary)
  ((exit-codes :initform '() :accessor %test-system-exit-codes)))

(defclass recording-system-boundary (system-boundary)
  ((delegate :initarg :delegate :reader recording-system-boundary-delegate)
   (calls :initform '() :accessor %recording-system-calls)))

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

(defun make-recording-system-boundary (&key (delegate (make-test-system-boundary)))
  "Create a system boundary that records exit requests while delegating to DELEGATE.

DELEGATE defaults to a non-terminating `make-test-system-boundary`, so a
recording system boundary never exits the process unless you pass a delegate
that does."
  (require-instance delegate 'system-boundary "DELEGATE")
  (make-instance 'recording-system-boundary :exit-fn nil :delegate delegate))

(defun recording-system-calls (system)
  "Return the recorded system-boundary calls in call order."
  (unless (typep system 'recording-system-boundary)
    (error "Unsupported system boundary type: ~S" system))
  (%snapshot-recorded-calls (%recording-system-calls system)))

(defun reset-recording-system-calls (system)
  "Clear SYSTEM's recorded call history and return SYSTEM.

A recording system boundary otherwise retains every call for the object's whole
lifetime; call this periodically to bound memory growth instead of only being
able to reclaim it by discarding the object."
  (unless (typep system 'recording-system-boundary)
    (error "Unsupported system boundary type: ~S" system))
  (setf (%recording-system-calls system) nil)
  system)

(defmethod system-exit ((system system-boundary) &optional (code 0))
  (%validate-exit-code code)
  (funcall (system-boundary-exit-fn system) code))

(defmethod system-exit ((system test-system-boundary) &optional (code 0))
  (%validate-exit-code code)
  (push code (%test-system-exit-codes system))
  code)

(defmethod system-exit ((system recording-system-boundary) &optional (code 0))
  (%validate-exit-code code)
  (let ((result (system-exit (recording-system-boundary-delegate system) code)))
    (%record-call (%recording-system-calls system)
      :operation :exit
      :arguments (list code)
      :result result)
    result))
