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

(defparameter *%process-kill-grace-seconds* 2
  "Seconds to wait after SIGTERM before escalating to SIGKILL on timeout.")

(defun %deadline-seconds (timeout)
  (when timeout
    (+ (get-internal-real-time)
       (round (* timeout internal-time-units-per-second)))))

(defun %process-alive-p (process)
  (sb-ext:process-alive-p process))

(defun %kill-process-with-escalation (process)
  ;; A child that traps or ignores SIGTERM would otherwise hang this call
  ;; (and the timeout contract) forever; SIGKILL cannot be caught or ignored.
  (sb-ext:process-kill process 15)
  (let ((grace-deadline (+ (get-internal-real-time)
                           (round (* *%process-kill-grace-seconds*
                                     internal-time-units-per-second)))))
    (loop
      (when (not (%process-alive-p process))
        (return))
      (when (>= (get-internal-real-time) grace-deadline)
        (sb-ext:process-kill process 9)
        (sb-ext:process-wait process)
        (return))
      (sleep 0.01))))

(defun %wait-for-process-with-deadline (process deadline)
  (loop
    when (null deadline) do
      (sb-ext:process-wait process)
      (return nil)
    when (not (%process-alive-p process)) do
      (return nil)
    when (>= (get-internal-real-time) deadline) do
      (%kill-process-with-escalation process)
      (return t)
    do (sleep 0.01)))

(defun %wait-for-process-with-timeout (process timeout)
  (%wait-for-process-with-deadline process (%deadline-seconds timeout)))

(defun %make-native-process-result (program stdout stderr exit-code &optional timed-out)
  ;; :TIMED-OUT is added only when the deadline fired, so a normal run keeps
  ;; its historical plist shape while a killed process is no longer
  ;; indistinguishable from one that merely exited with a NIL code.
  (append (list :command program
                :stdout stdout
                :stderr stderr
                :exit-code exit-code)
          (when timed-out (list :timed-out t))))

(defun %native-process-options (input directory environment output error-output)
  (append (when input
            (list :input input))
          (when directory
            (list :directory directory))
          (when environment
            (list :env environment))
          (list :output (%process-output-option output)
                :error (%process-output-option error-output)
                :search t
                :wait nil)))

(defun %run-native-process/cps (program input directory environment output error-output timeout continuation)
  (let ((process (apply #'sb-ext:run-program
                        (first program)
                        (rest program)
                        (%native-process-options input
                                                 directory
                                                 environment
                                                 output
                                                 error-output))))
    (unwind-protect
        (let ((stdout-thread (%start-capturing-thread process #'sb-ext:process-output output))
              (stderr-thread (%start-capturing-thread process #'sb-ext:process-error error-output)))
          (let ((timed-out (%wait-for-process-with-timeout process timeout)))
            (let ((stdout (%join-capturing-thread stdout-thread))
                  (stderr (%join-capturing-thread stderr-thread))
                  (exit-code (sb-ext:process-exit-code process)))
              (funcall continuation
                       (%make-native-process-result program stdout stderr exit-code
                                                    timed-out)))))
      (sb-ext:process-close process))))

(defun %real-process-run (command &key arguments input directory environment output error-output timeout)
  (%run-native-process/cps (%normalize-program command arguments)
                           input
                           directory
                           environment
                           output
                           error-output
                           timeout
                           #'identity))
