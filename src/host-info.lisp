;;;; src/host-info.lisp

(in-package #:cl-boundary-kit)

(defclass host-info ()
  ((hostname-fn :initarg :hostname-fn :reader host-info-hostname-fn)
   (username-fn :initarg :username-fn :reader host-info-username-fn)
   (pid-fn :initarg :pid-fn :reader host-info-pid-fn)))

(defclass test-host-info (host-info)
  ((hostname :initarg :hostname :reader %test-host-info-hostname)
   (username :initarg :username :reader %test-host-info-username)
   (pid :initarg :pid :reader %test-host-info-pid)))

(defclass recording-host-info (host-info)
  ((delegate :initarg :delegate :reader recording-host-info-delegate)
   (calls :initform '() :accessor %recording-host-info-calls)))

(defun %default-host-username ()
  ;; No portable Common Lisp accessor exists; read USER/USERNAME through
  ;; SB-EXT:POSIX-GETENV resolved at call time, falling back to "unknown".
  (let ((getenv (and (find-package "SB-EXT")
                     (find-symbol "POSIX-GETENV" "SB-EXT"))))
    (or (and getenv (or (funcall getenv "USER") (funcall getenv "USERNAME")))
        "unknown")))

(defun %default-host-pid ()
  ;; SB-POSIX:GETPID resolved at call time so this file loads without SB-POSIX;
  ;; falls back to 0 when no process-id accessor is available.
  (let ((getpid (and (find-package "SB-POSIX")
                     (find-symbol "GETPID" "SB-POSIX"))))
    (if getpid (funcall getpid) 0)))

(defun %validate-pid (pid)
  (unless (and (integerp pid) (>= pid 0))
    (error "Process id must be a non-negative integer: ~S" pid))
  pid)

(defun make-host-info (&key
                         (hostname-fn #'machine-instance)
                         (username-fn #'%default-host-username)
                         (pid-fn #'%default-host-pid))
  "Create a host-info boundary from HOSTNAME-FN, USERNAME-FN, and PID-FN.

`host-info-hostname`, `host-info-username`, and `host-info-pid` call the matching
collaborator with no arguments. The defaults read the real host through
`machine-instance`, the `USER`/`USERNAME` environment, and the process id, so a
plain `make-host-info` reflects the running process. Every collaborator is
validated at construction time."
  (require-function hostname-fn "HOSTNAME-FN")
  (require-function username-fn "USERNAME-FN")
  (require-function pid-fn "PID-FN")
  (make-instance 'host-info
                 :hostname-fn hostname-fn
                 :username-fn username-fn
                 :pid-fn pid-fn))

(defun make-test-host-info (&key (hostname "test-host") (username "tester") (pid 0))
  "Create a host-info boundary that returns fixed HOSTNAME, USERNAME, and PID.

This is the deterministic double for tests, returning the supplied values
instead of reading the real host."
  (make-instance 'test-host-info
                 :hostname-fn nil :username-fn nil :pid-fn nil
                 :hostname (require-string hostname "Host name")
                 :username (require-string username "User name")
                 :pid (%validate-pid pid)))

(define-recording-boundary-constructor make-recording-host-info
    recording-host-info host-info (make-test-host-info)
  "Create a host-info boundary that records reads while delegating to DELEGATE,
which defaults to a `make-test-host-info`."
  :hostname-fn nil :username-fn nil :pid-fn nil)

(define-recording-call-log recording-host-info-calls reset-recording-host-info-calls
    (host-info recording-host-info %recording-host-info-calls) "host-info")

(defmethod host-info-hostname ((host-info host-info))
  (funcall (host-info-hostname-fn host-info)))

(defmethod host-info-username ((host-info host-info))
  (funcall (host-info-username-fn host-info)))

(defmethod host-info-pid ((host-info host-info))
  (funcall (host-info-pid-fn host-info)))

(defmethod host-info-hostname ((host-info test-host-info))
  (%test-host-info-hostname host-info))

(defmethod host-info-username ((host-info test-host-info))
  (%test-host-info-username host-info))

(defmethod host-info-pid ((host-info test-host-info))
  (%test-host-info-pid host-info))

(define-recording-delegate-method host-info-hostname
    (host-info recording-host-info recording-host-info-delegate %recording-host-info-calls)
    (() ()) :hostname '())

(define-recording-delegate-method host-info-username
    (host-info recording-host-info recording-host-info-delegate %recording-host-info-calls)
    (() ()) :username '())

(define-recording-delegate-method host-info-pid
    (host-info recording-host-info recording-host-info-delegate %recording-host-info-calls)
    (() ()) :pid '())
