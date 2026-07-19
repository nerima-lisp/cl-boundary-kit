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

(defun %read-process-captured-output (process accessor destination)
  (when (%capture-destination-p destination)
    (%slurp-stream (funcall accessor process))))

(defun %deadline-seconds (timeout)
  (when timeout
    (+ (get-internal-real-time)
       (round (* timeout internal-time-units-per-second)))))

(defun %process-alive-p (process)
  (sb-ext:process-alive-p process))

(defun %wait-for-process-with-deadline (process deadline)
  (loop
    when (null deadline) do
      (sb-ext:process-wait process)
      (return nil)
    when (not (%process-alive-p process)) do
      (return nil)
    when (>= (get-internal-real-time) deadline) do
      (sb-ext:process-kill process 15)
      (sb-ext:process-wait process)
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
    (let ((timed-out (%wait-for-process-with-timeout process timeout)))
      (let ((stdout (%read-process-captured-output process
                                                   #'sb-ext:process-output
                                                   output))
            (stderr (%read-process-captured-output process
                                                   #'sb-ext:process-error
                                                   error-output))
            (exit-code (sb-ext:process-exit-code process)))
        (funcall continuation
                 (%make-native-process-result program stdout stderr exit-code
                                              timed-out))))))

(defun %real-process-run (command &key arguments input directory environment output error-output timeout)
  (%run-native-process/cps (%normalize-program command arguments)
                           input
                           directory
                           environment
                           output
                           error-output
                           timeout
                           #'identity))
