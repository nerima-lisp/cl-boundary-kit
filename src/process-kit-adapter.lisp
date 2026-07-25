;;;; src/process-kit-adapter.lisp

(in-package #:cl-boundary-kit)

(defun %process-kit-destination (destination)
  ;; Mirrors %PROCESS-OUTPUT-OPTION's convention (NIL or :STRING means
  ;; "capture and return as a string"; anything else -- a stream, a
  ;; pathname, :INHERIT, :NULL -- passes through unchanged), targeting
  ;; process-kit's :CAPTURE instead of sb-ext:run-program's :STREAM.
  (if (or (null destination) (eq destination :string))
      :capture
      destination))

(defun %process-kit-command-spec (full-command directory environment environment-supplied-p
                                  output error-output)
  (process-kit:make-command
   (first full-command) (rest full-command)
   :search *native-process-search-path-p*
   :environment-policy (if environment-supplied-p
                           (%normalize-process-environment environment)
                           :inherit)
   :directory directory
   :stdout (%process-kit-destination output)
   :stderr (%process-kit-destination error-output)
   :result-type :string))

(defun process-kit-run-fn (command &key arguments input directory
                                    (environment nil environment-supplied-p)
                                    output error-output (timeout *default-process-timeout-seconds*))
  "A RUN-FN for `make-process-boundary' backed by the nerima-lisp
`cl-process-kit' process execution toolkit (`process-kit:run-command'),
in place of this system's own hand-rolled `sb-ext:run-program' escalation
loop.

`cl-process-kit' puts the child in its own process group and escalates
SIGTERM then SIGKILL once TIMEOUT (seconds) elapses, so a timed-out command
never leaves an orphaned process behind -- the same guarantee this system's
default runner provides, from a dedicated, independently tested library.
TIMEOUT defaults to *DEFAULT-PROCESS-TIMEOUT-SECONDS*; pass an explicit
:TIMEOUT NIL to wait for the child indefinitely instead.

Plug this into `make-process-boundary':

  (make-process-boundary :run-fn #'process-kit-run-fn)

Returns the same `(:command :stdout :stderr :exit-code [:timed-out t])'
plist shape as the default runner, so callers (`process-result-success-p',
`process-result-check', recording/test process boundaries) are unaffected
by which runner is plugged in."
  (let* ((full-command (normalize-command command arguments))
         (spec (%process-kit-command-spec full-command directory
                                          environment environment-supplied-p
                                          output error-output))
         (result (process-kit:run-command spec :input input :timeout timeout
                                          :on-timeout :return)))
    (%make-native-process-result full-command
                                 (process-kit:process-result-stdout result)
                                 (process-kit:process-result-stderr result)
                                 (process-kit:process-result-exit-code result)
                                 (process-kit:process-result-timed-out-p result))))
