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

(defun %process-environment-entry-string (entry)
  ;; Accept this library's own (STRING . STRING) alist shape -- the same
  ;; shape ENVIRONMENT-LIST returns -- plus a bare "NAME=VALUE" string or a
  ;; (KEYWORD . STRING) cons, and normalize all of them to "NAME=VALUE".
  (cond
    ((stringp entry) entry)
    ((and (consp entry) (or (stringp (car entry)) (symbolp (car entry))))
     (format nil "~A=~A"
            (if (symbolp (car entry)) (symbol-name (car entry)) (car entry))
            (cdr entry)))
    (t (error "Invalid process environment entry: ~S" entry))))

(defun %normalize-process-environment (environment)
  (mapcar #'%process-environment-entry-string environment))

(defparameter *native-process-search-path-p* t
  "Whether the native process boundary searches $PATH for the program, like
execvp. Bind to NIL around a call so a relative or attacker-influenced
program name must instead resolve to an absolute path, rather than being
implicitly resolved against whatever directories $PATH happens to list.")

(defun %native-process-options (input directory environment environment-supplied-p output error-output)
  ;; ENVIRONMENT-SUPPLIED-P (not a truthiness check on ENVIRONMENT) decides
  ;; whether :ENVIRONMENT is passed at all: an explicit empty '() must still
  ;; reach sb-ext:run-program as "give the child no environment", not be
  ;; treated the same as "omitted" and silently fall back to inheriting the
  ;; full parent environment (and whatever secrets it holds). This uses
  ;; run-program's :ENVIRONMENT keyword (a list of "NAME=VALUE" strings)
  ;; rather than its :ENV "CMU CL compatibility" alist keyword -- :ENV NIL
  ;; is empirically indistinguishable from "omitted" inside SBCL itself and
  ;; still inherits the parent environment, defeating an explicit empty
  ;; environment the exact same way the bug this fixes did.
  (append (when input
            (list :input input))
          (when directory
            (list :directory directory))
          (when environment-supplied-p
            (list :environment (%normalize-process-environment environment)))
          (list :output (%process-output-option output)
                :error (%process-output-option error-output)
                :search *native-process-search-path-p*
                :wait nil)))

(defun %run-native-process/cps (program input directory environment environment-supplied-p
                                output error-output timeout continuation)
  (let ((process (apply #'sb-ext:run-program
                        (first program)
                        (rest program)
                        (%native-process-options input
                                                 directory
                                                 environment
                                                 environment-supplied-p
                                                 output
                                                 error-output))))
    (unwind-protect
        (let (stdout-thread stderr-thread both-threads-started-p)
          (unwind-protect
              (progn
                (setf stdout-thread (%start-capturing-thread process #'sb-ext:process-output output))
                (setf stderr-thread (%start-capturing-thread process #'sb-ext:process-error error-output))
                (setf both-threads-started-p t))
            ;; If starting the stderr thread signals, the stdout thread (if
            ;; already running) must still be joined here -- otherwise it is
            ;; orphaned racing PROCESS-CLOSE below against the stream it is
            ;; still reading. Guarded by BOTH-THREADS-STARTED-P so the normal
            ;; (non-error) path doesn't join twice.
            (unless both-threads-started-p
              (%join-capturing-thread stdout-thread)
              (%join-capturing-thread stderr-thread)))
          (let ((timed-out (%wait-for-process-with-timeout process timeout)))
            (let ((stdout (%join-capturing-thread stdout-thread))
                  (stderr (%join-capturing-thread stderr-thread))
                  (exit-code (sb-ext:process-exit-code process)))
              (funcall continuation
                       (%make-native-process-result program stdout stderr exit-code
                                                    timed-out)))))
      (sb-ext:process-close process))))

(defun %real-process-run (command &key arguments input directory
                                  (environment nil environment-supplied-p)
                                  output error-output timeout)
  (%run-native-process/cps (%normalize-program command arguments)
                           input
                           directory
                           environment
                           environment-supplied-p
                           output
                           error-output
                           timeout
                           #'identity))
