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

(defparameter *default-process-timeout-seconds* 60
  "Default TIMEOUT (seconds) for PROCESS-BOUNDARY-RUN when a caller omits :TIMEOUT. Pass an explicit :TIMEOUT NIL to wait indefinitely.")

(defun %native-process-options (input directory environment environment-supplied-p
                                output error-output)
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



(defun %start-both-capturing-threads-or-cleanup (process output error-output)
  ;; A partially started capture must not wait indefinitely if a descendant
  ;; inherits a pipe after the direct child is killed.
  (let (stdout-thread stderr-thread both-threads-started-p)
    (unwind-protect
        (progn
          (setf stdout-thread
                (%start-capturing-thread process #'sb-ext:process-output output))
          (setf stderr-thread
                (%start-capturing-thread process #'sb-ext:process-error error-output))
          (setf both-threads-started-p t))
      (unless both-threads-started-p
        (%force-kill-and-reap process)
        (%close-process-streams process)
        (%terminate-capturing-thread stdout-thread)
        (%terminate-capturing-thread stderr-thread)))
    (values stdout-thread stderr-thread)))

;; The public entry point keeps a direct, non-CPS signature -- MAKE-PROCESS-
;; BOUNDARY's default :RUN-FN calls it expecting a plain return value -- while
;; delegating to %RUN-NATIVE-PROCESS/CPS below for the deadline-sharing
;; timeout handling between the stdout and stderr capture threads.
(defun %real-process-run (command &key arguments input directory
                                  (environment nil environment-supplied-p)
                                  output error-output timeout)
  (let ((program (%normalize-program command arguments)))
    (%run-native-process/cps program input directory environment
                             environment-supplied-p output error-output timeout
                             #'identity)))

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
        (multiple-value-bind (stdout-thread stderr-thread)
            (%start-both-capturing-threads-or-cleanup process output error-output)
          (let* ((deadline (%deadline-seconds timeout))
                 (timed-out (%wait-for-process-with-deadline process deadline))
                 (exit-code (sb-ext:process-exit-code process)))
            (multiple-value-bind (stdout stdout-timed-out-p)
                (%join-capturing-thread
                 stdout-thread
                 :timeout (%deadline-remaining-seconds deadline))
              (multiple-value-bind (stderr stderr-timed-out-p)
                  (%join-capturing-thread
                   stderr-thread
                   :timeout (%deadline-remaining-seconds deadline))
                (when (or stdout-timed-out-p stderr-timed-out-p)
                  ;; A descendant can retain the pipe after its parent exits.
                  (%close-process-streams process)
                  (when stdout-timed-out-p
                    (setf stdout (%terminate-capturing-thread stdout-thread)))
                  (when stderr-timed-out-p
                    (setf stderr (%terminate-capturing-thread stderr-thread))))
                (funcall continuation
                         (%make-native-process-result
                          program stdout stderr exit-code timed-out))))))
      ;; An early exit above (e.g. a capture thread failing to start) skips
      ;; %WAIT-FOR-PROCESS-WITH-DEADLINE entirely, so the child would
      ;; otherwise be left running as an untracked orphan: closing its
      ;; streams does not kill or reap it. Force it down first, on every exit
      ;; path, not only the timeout path.
      (%force-kill-and-reap process)
      (%close-process-streams process)
      (sb-ext:process-close process))))
