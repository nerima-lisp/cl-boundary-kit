(in-package #:cl-boundary-kit)

(defun %make-native-process-result (program stdout stderr exit-code &optional timed-out)
  ;; :TIMED-OUT is added only when the deadline fired, so a normal run keeps
  ;; its historical plist shape while a killed process is no longer
  ;; indistinguishable from one that merely exited with a NIL code.
  (if timed-out
      (list* :command program
             :stdout stdout
             :stderr stderr
             :exit-code exit-code
             (list :timed-out t))
      (list :command program
            :stdout stdout
            :stderr stderr
            :exit-code exit-code)))

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

(defparameter *native-process-search-path-p* nil
  "Whether the native process boundary searches $PATH for the program, like
execvp. The default is NIL so relative or attacker-influenced program names must
resolve to absolute paths unless callers explicitly opt in to PATH lookup.")

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
  (let ((options (list :output (%process-output-option output)
                       :error (%process-output-option error-output)
                       :search *native-process-search-path-p*
                       :wait nil)))
    (when environment-supplied-p
      (setf options (list* :environment (%normalize-process-environment environment) options)))
    (when directory
      (setf options (list* :directory directory options)))
    (when input
      (setf options (list* :input input options)))
    options))

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
            ;; (non-error) path doesn't join twice. The process is killed
            ;; FIRST: a stdout-thread already blocked reading from its pipe
            ;; only sees EOF once the child exits, so joining before killing
            ;; would block for the child's entire natural remaining
            ;; lifetime instead of returning promptly -- and leave the
            ;; child running as an untracked orphan in the meantime.
            (unless both-threads-started-p
              (%force-kill-and-reap process)
              (%join-capturing-thread stdout-thread)
              (%join-capturing-thread stderr-thread)))
          (let ((timed-out (%wait-for-process-with-timeout process timeout)))
            (let ((stdout (%join-capturing-thread stdout-thread))
                  (stderr (%join-capturing-thread stderr-thread))
                  (exit-code (sb-ext:process-exit-code process)))
              (funcall continuation
                       (%make-native-process-result program stdout stderr exit-code
                                                    timed-out)))))
      ;; An early exit above (e.g. a capture thread failing to start) skips
      ;; %WAIT-FOR-PROCESS-WITH-TIMEOUT entirely, so the child would
      ;; otherwise be left running as an untracked orphan: closing its
      ;; streams does not kill or reap it. Force it down first, on every exit
      ;; path, not only the timeout path.
      (%force-kill-and-reap process)
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
