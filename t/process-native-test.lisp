;;;; t/process-native-test.lisp
;;;;
;;;; Native process runner tests -- timeout/SIGKILL escalation, output capture,
;;;; and environment handling -- split out of process-test.lisp.

(in-package #:cl-boundary-kit/test)

(it "native-process-output-capture-preserves-a-trailing-newline"
  (expect (string= (format nil "hello~%")
                   (cl-boundary-kit::%slurp-stream
                    (make-string-input-stream (format nil "hello~%"))))
          :to-be-truthy)
  (expect (string= "" (cl-boundary-kit::%slurp-stream
                       (make-string-input-stream "")))
          :to-be-truthy))

(it "native-process-result-flags-a-timeout-without-perturbing-normal-runs"
  (expect (getf (cl-boundary-kit::%make-native-process-result
                 '("prog") "" "" nil t)
                :timed-out)
          :to-be-truthy)
  (expect (null (member :timed-out
                        (cl-boundary-kit::%make-native-process-result
                         '("prog") "out" "" 0)))
          :to-be-truthy))

(it "native-process-run-terminates-and-flags-a-timed-out-subprocess"
  (let* ((process (make-process-boundary))
         (runtime (namestring sb-ext:*runtime-pathname*))
         (start (get-internal-real-time))
         (result (process-boundary-run
                  process runtime
                  :arguments (list "--non-interactive" "--no-sysinit" "--no-userinit"
                                   "--eval" "(sleep 30)")
                  :timeout 1))
         (elapsed-seconds (/ (- (get-internal-real-time) start)
                             internal-time-units-per-second)))
    (expect (getf result :timed-out) :to-be-truthy)
    ;; Killed at the ~1s deadline, not after the full 30s sleep.
    (expect (< elapsed-seconds 10) :to-be-truthy)))

(it "native-process-run-escalates-to-sigkill-when-the-subprocess-ignores-sigterm"
  (let* ((process (make-process-boundary))
         (runtime (namestring sb-ext:*runtime-pathname*))
         (start (get-internal-real-time))
         (result (process-boundary-run
                  process runtime
                  :arguments (list "--non-interactive" "--no-sysinit" "--no-userinit"
                                   "--eval" "(sb-sys:enable-interrupt sb-unix:sigterm :ignore)"
                                   "--eval" "(sleep 30)")
                  :timeout 1))
         (elapsed-seconds (/ (- (get-internal-real-time) start)
                             internal-time-units-per-second)))
    (expect (getf result :timed-out) :to-be-truthy)
    ;; 1s deadline + a few seconds of SIGTERM grace before SIGKILL, well
    ;; short of the full 30s sleep.
    (expect (< elapsed-seconds 10) :to-be-truthy)))

(it "native-process-run-captures-output-larger-than-a-pipe-buffer-without-deadlocking"
  (let* ((process (make-process-boundary))
         (runtime (namestring sb-ext:*runtime-pathname*))
         (result (process-boundary-run
                  process runtime
                  :arguments (list "--non-interactive" "--no-sysinit" "--no-userinit"
                                   "--eval"
                                   "(progn (loop repeat 40000 do (write-string \"0123456789\")) (finish-output))")
                  :timeout 15)))
    ;; >= rather than = : stdout also carries the SBCL startup banner ahead
    ;; of the 400000 digit characters written by the --eval form. The exact
    ;; trailing content proves nothing was dropped or truncated.
    (expect (>= (length (getf result :stdout)) 400000) :to-be-truthy)
    (expect (let ((stdout (getf result :stdout)))
              (string= (subseq stdout (- (length stdout) 10)) "0123456789"))
            :to-be-truthy)))

(it "native-process-run-captures-large-stderr-without-deadlocking"
  (let* ((process (make-process-boundary))
         (runtime (namestring sb-ext:*runtime-pathname*))
         (result (process-boundary-run
                  process runtime
                  :arguments (list "--non-interactive" "--no-sysinit" "--no-userinit"
                                   "--eval"
                                   "(progn (loop repeat 40000 do (write-string \"0123456789\" *error-output*)) (finish-output *error-output*))")
                  :timeout 15)))
    (expect (>= (length (getf result :stderr)) 400000) :to-be-truthy)
    (expect (let ((stderr (getf result :stderr)))
              (string= (subseq stderr (- (length stderr) 10)) "0123456789"))
            :to-be-truthy)))

(defun %run-native-reporting (var-names &rest environment-args)
  (let* ((process (make-process-boundary))
         (runtime (namestring sb-ext:*runtime-pathname*))
         (probe (format nil "(dolist (v '~S) (format t \"[~~A]\" (sb-ext:posix-getenv v)))"
                       var-names)))
    (getf (apply #'process-boundary-run
                 process runtime
                 :arguments (list "--non-interactive" "--no-sysinit" "--no-userinit"
                                  "--eval" probe)
                 environment-args)
          :stdout)))

(it "native-process-run-inherits-the-parent-environment-when-not-supplied"
  (expect (not (search "[NIL]" (%run-native-reporting '("PATH")))) :to-be-truthy))

(it "native-process-run-honors-an-explicit-empty-environment-instead-of-inheriting"
  (expect (search "[NIL]" (%run-native-reporting '("PATH") :environment nil))
          :to-be-truthy))

(it "native-process-run-accepts-a-string-keyed-environment-alist"
  (expect (search "[hello][NIL]"
                  (%run-native-reporting '("MARKER" "PATH")
                                         :environment '(("MARKER" . "hello"))))
          :to-be-truthy))

(it "native-process-search-path-p-defaults-to-nil-and-requires-an-absolute-path"
  (expect (null *native-process-search-path-p*) :to-be-truthy)
  (let ((process (make-process-boundary)))
    (signals error
      (process-boundary-run process "sh" :arguments (list "-c" "echo ok")))
    (expect (equal (getf (process-boundary-run process (namestring sb-ext:*runtime-pathname*)
                                              :arguments (list "--version"))
                         :exit-code)
                   0)
            :to-be-truthy)))

(it "native-process-search-path-p-bound-to-t-searches-path"
  (let ((process (make-process-boundary))
        (*native-process-search-path-p* t))
    (expect (search "ok" (getf (process-boundary-run process "sh" :arguments (list "-c" "echo ok"))
                               :stdout))
            :to-be-truthy)))

(it "native-process-run-kills-the-child-and-returns-promptly-if-a-capture-thread-fails-to-start"
  (let* ((process (make-process-boundary))
         (runtime (namestring sb-ext:*runtime-pathname*))
         (call-count 0)
         (start (get-internal-real-time)))
    (let ((cl-boundary-kit::*capturing-thread-maker*
            (lambda (function &rest args)
              (if (= (incf call-count) 2)
                  (error "simulated capture-thread spawn failure")
                  (apply (function sb-thread:make-thread) function args)))))
      (signals error
        (process-boundary-run
         process
         runtime
         :arguments
         (list "--non-interactive"
               "--no-sysinit"
               "--no-userinit"
               "--eval"
               "(sleep 5)"))))
    ;; Well under the five seconds the child would otherwise stay alive.
    ;; This also proves the early-cleanup path reaped the child.
    (expect (< (/ (- (get-internal-real-time) start)
                  internal-time-units-per-second)
               2)
            :to-be-truthy)))

(it "process-result-success-p-reads-the-exit-code"
  (let ((ok (make-test-process-boundary
             :results (list (list :stdout "ok" :stderr "" :exit-code 0))))
        (bad (make-test-process-boundary
              :results (list (list :stdout "" :stderr "boom" :exit-code 1)))))
    (expect (eq t (process-result-success-p (process-boundary-run ok "cmd"))) :to-be-truthy)
    (expect (null (process-result-success-p (process-boundary-run bad "cmd"))) :to-be-truthy)))

(it "process-result-success-p-signals-on-a-result-without-an-integer-exit-code"
  (signals error
    (process-result-success-p (list :stdout "x"))))

(it "process-result-check-returns-the-result-on-success"
  (let ((result (list :command '("cmd") :stdout "ok" :stderr "" :exit-code 0)))
    (expect (eq result (process-result-check result)) :to-be-truthy)))

(it "process-result-check-signals-with-diagnostics-on-failure"
  (signals-error-message-contains "boom"
    (process-result-check (list :command '("cmd") :stdout "" :stderr "boom" :exit-code 2))))

(it "process-environment-entry-string-normalizes-every-accepted-shape"
  (expect (cl-boundary-kit::%process-environment-entry-string "NAME=value")
          :to-equal "NAME=value")
  (expect (cl-boundary-kit::%process-environment-entry-string '("NAME" . "value"))
          :to-equal "NAME=value")
  (expect (cl-boundary-kit::%process-environment-entry-string '(:name . "value"))
          :to-equal "NAME=value"))

(it "process-environment-entry-string-rejects-an-unsupported-entry"
  (signals-error-message-contains "Invalid process environment entry"
    (cl-boundary-kit::%process-environment-entry-string 42)))

(it "capture-destination-p-detects-capture-and-stream-output-destinations"
  (expect (cl-boundary-kit::%capture-destination-p nil) :to-be-truthy)
  (expect (cl-boundary-kit::%capture-destination-p :string) :to-be-truthy)
  (expect (cl-boundary-kit::%capture-destination-p *standard-output*) :to-be nil)
  ;; %process-output-option maps both capture requests to :STREAM and passes
  ;; an explicit stream through unchanged.
  (expect (cl-boundary-kit::%process-output-option :string) :to-be :stream)
  (expect (cl-boundary-kit::%process-output-option :inherit) :to-be :inherit)
  (let* ((process (make-process-boundary))
         (runtime (namestring sb-ext:*runtime-pathname*))
         (output (make-string-output-stream))
         (error-output (make-string-output-stream))
         (result (process-boundary-run
                  process runtime
                  :arguments (list "--noinform" "--non-interactive" "--no-sysinit" "--no-userinit" "--eval" "(progn (format t \"out\") (format *error-output* \"err\"))")
                  :timeout nil
                  :output output
                  :error-output error-output)))
    (expect (eql 0 (getf result :exit-code)) :to-be-truthy)
    (expect (null (getf result :stdout)) :to-be-truthy)
    (expect (null (getf result :stderr)) :to-be-truthy)
    (expect (string= "out" (get-output-stream-string output)) :to-be-truthy)
    (expect (string= "err" (get-output-stream-string error-output)) :to-be-truthy)))

(it "native-process-run-accepts-a-working-directory-and-input-stream"
  (let* ((process (make-process-boundary))
         (runtime (namestring sb-ext:*runtime-pathname*)))
    (with-input-from-string (input "")
      (let ((result (process-boundary-run
                     process runtime
                     :arguments (list "--non-interactive" "--no-sysinit" "--no-userinit"
                                      "--eval" "(sb-ext:quit)")
                     :input input
                     :directory (uiop:temporary-directory))))
        (expect (eql 0 (getf result :exit-code)) :to-be-truthy)))))

(it "process-boundary-run-rejects-a-non-process-boundary"
  (signals-error-message-contains "must be a process boundary"
    (process-boundary-run (list :boundary-type :not-a-process) "cmd")))
