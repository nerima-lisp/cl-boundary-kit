;;;; src/process-exec-capture.lisp
;;;;
;;;; Draining a child process's stdout/stderr concurrently with waiting for it,
;;;; so a child that fills an OS pipe buffer cannot deadlock the parent.

(in-package #:cl-boundary-kit)

(defun %slurp-stream (stream)
  ;; Copy the stream verbatim.  Reconstructing it line-by-line dropped the
  ;; trailing newline (most shell tools emit one) and would normalize any
  ;; other separators, silently altering captured output.  Block reads keep
  ;; the copy O(n) with far fewer stream operations than char-at-a-time.
  (when stream
    (let ((out (make-string-output-stream))
          (chunk (make-string 4096)))
      (loop for n = (read-sequence chunk stream)
            while (plusp n)
            do (write-string chunk out :end n))
      (get-output-stream-string out))))

(defun %start-capturing-thread (process accessor destination)
  ;; Draining stdout/stderr must happen concurrently with waiting for the
  ;; process, not after: a child that writes more than one OS pipe buffer
  ;; combined across both streams blocks on write() until someone reads, so
  ;; waiting for exit before reading deadlocks forever on large output.
  (when (%capture-destination-p destination)
    (let ((stream (funcall accessor process)))
      (sb-thread:make-thread (lambda () (%slurp-stream stream))))))

(defun %join-capturing-thread (thread)
  (when thread
    (sb-thread:join-thread thread)))
