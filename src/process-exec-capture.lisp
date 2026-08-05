;;;; src/process-exec-capture.lisp
;;;;
;;;; Draining a child process's stdout/stderr concurrently with waiting for it,
;;;; so a child that fills an OS pipe buffer cannot deadlock the parent.

(in-package #:cl-boundary-kit)

;;; DATA: the pipe-drain block size and the join-timeout floor, kept apart from
;;; the draining LOGIC below.
(defconstant +process-output-chunk-size+ 4096
  "Characters read per block when draining a child process pipe.")

(defconstant +process-join-timeout-floor-seconds+ 0.001
  "Smallest timeout handed to JOIN-THREAD. SBCL treats a zero timeout as
unbounded, so preserving a nonblocking join means asking for a small positive
timeout rather than zero.")

(defun %slurp-stream (stream)
  ;; Copy the stream verbatim.  Reconstructing it line-by-line dropped the
  ;; trailing newline (most shell tools emit one) and would normalize any
  ;; other separators, silently altering captured output.  Block reads keep
  ;; the copy O(n) with far fewer stream operations than char-at-a-time.
  (when stream
    (let ((out (make-string-output-stream))
          (chunk (make-string +process-output-chunk-size+)))
      ;; The parent closes this pipe to unblock a reader stuck on a
      ;; descendant-held fd, so a read already inside select(2) then fails with
      ;; EBADF.  Unhandled, that error escapes this thread and, with the
      ;; debugger disabled, quits the whole process, so the drain returns the
      ;; partial capture the caller already expects from a terminated reader.
      (handler-case
          (loop for n = (read-sequence chunk stream)
                while (plusp n)
                do (write-string chunk out :end n))
        (error () nil))
      (get-output-stream-string out))))

(defparameter *capturing-thread-maker*
  (function sb-thread:make-thread)
  "Function used to start a stdout or stderr capture thread.")

(defparameter *%capturing-thread-termination-timeout-seconds* 1
    "Maximum wait after forcibly stopping a library-owned reader thread.")


(defun %start-capturing-thread (process accessor destination)
  "Start a reader thread only when DESTINATION requests captured output."
  (when (%capture-destination-p destination)
    (let ((stream (funcall accessor process)))
      (funcall *capturing-thread-maker* (lambda () (%slurp-stream stream))))))

(defun %join-capturing-thread (thread &key timeout)
  "Return the captured output and whether joining THREAD exceeded TIMEOUT."
  (when thread
    (let ((effective-timeout
            (and timeout (max timeout +process-join-timeout-floor-seconds+))))
      (multiple-value-bind (output status)
          (sb-thread:join-thread thread :default "" :timeout effective-timeout)
        (values output (eq status :timeout))))))

(defun %close-process-streams (process)
  "Close the parent pipe ends without waiting for descendants."
  (dolist (stream (list (sb-ext:process-input process)
                        (sb-ext:process-output process)
                        (sb-ext:process-error process)))
    (when stream
      (ignore-errors (close stream)))))

(defun %terminate-capturing-thread (thread)
  "Stop a reader thread after its stream has been closed."
  (when thread
    (ignore-errors (sb-thread:terminate-thread thread))
    (let ((output (%join-capturing-thread
                   thread
                   :timeout *%capturing-thread-termination-timeout-seconds*)))
      (if (stringp output) output ""))))
