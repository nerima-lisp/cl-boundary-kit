;;;; t/process-native-test.lisp
;;;;
;;;; Native process runner tests -- timeout/SIGKILL escalation, output capture,
;;;; and environment handling -- split out of process-test.lisp.
(in-package #:cl-boundary-kit/test)

(defvar *native-process-boundary* nil)

(describe "native process result helpers"
  ;; Regression: captured native output used to be reconstructed line-by-line,
  ;; which dropped the trailing newline that most tools emit.
  (it
    "native-process-output-capture-preserves-a-trailing-newline"
    (expect (cl-boundary-kit::%slurp-stream
             (make-string-input-stream (format nil "hello~%")))
            :to-equal (format nil "hello~%"))
    (expect (cl-boundary-kit::%slurp-stream (make-string-input-stream "")) :to-equal ""))

  ;; Regression: a parent closing this stream to unblock a reader stuck on a
  ;; descendant-held pipe can race a read already inside select(2), raising
  ;; an error that used to escape %SLURP-STREAM and crash the whole process.
  ;; A closed stream deterministically reproduces the same "read after
  ;; close" shape without needing a real subprocess/threading race.
  (it
    "native-process-output-capture-tolerates-a-stream-closed-mid-read"
    (let ((stream (make-string-input-stream "partial")))
      (close stream)
      (expect (cl-boundary-kit::%slurp-stream stream) :to-equal "")))

  (it
    "native-process-result-flags-a-timeout-without-perturbing-normal-runs"
    (expect
      (getf
        (cl-boundary-kit::%make-native-process-result '("prog") "" "" nil t)
        :timed-out)
      :to-be-truthy)
    (expect (cl-boundary-kit::%make-native-process-result '("prog") "out" "" 0) :not :to-contain :timed-out)))

(describe "native process timeouts"
  (before-each
    (setf *native-process-boundary* (make-process-boundary)))

  ;; Regression: a process killed on timeout used to be indistinguishable from
  ;; one that merely exited with a NIL code.  The result now flags the timeout,
  ;; while a normal run keeps its historical plist shape.
  ;; Exercises the real deadline/kill path end to end: a subprocess that outlives
  ;; its timeout is terminated and the result flags the timeout rather than
  ;; masquerading as a normal exit.  Uses the running SBCL as the subprocess so
  ;; the test needs no external command on PATH (important under the Nix sandbox).
  (it "native-process-run-terminates-and-flags-a-timed-out-subprocess"
    (let* ((runtime (namestring sb-ext:*runtime-pathname*))
           (start (get-internal-real-time))
           (result (process-boundary-run
                    *native-process-boundary* runtime
                    :arguments (list "--non-interactive" "--no-sysinit" "--no-userinit"
                                     "--eval" "(sleep 30)")
                    :timeout 1))
           (elapsed-seconds (/ (- (get-internal-real-time) start)
                               internal-time-units-per-second)))
      (expect (getf result :timed-out) :to-be-truthy)
      ;; Killed at the ~1s deadline, not after the full 30s sleep.
      (expect elapsed-seconds :to-be-less-than 10)))

  (it "native-process-timeout-does-not-block-on-a-descendant-owned-pipe"
    (uiop:with-temporary-file (:stream stream
                               :pathname pid-path
                               :directory (uiop:temporary-directory)
                               :prefix "cl-boundary-kit-descendant-"
                               :suffix ".pid"
                               :direction :output)
      (write-string "" stream)
      :close-stream
      (let ((pid nil))
        (unwind-protect
             (let* ((command (format nil "sleep 30 & echo $! > ~S; wait"
                                     (namestring pid-path)))
                    (start (get-internal-real-time))
                    (result (process-boundary-run
                             *native-process-boundary* "/bin/sh"
                             :arguments (list "-c" command)
                             :timeout 1))
                    (elapsed-seconds
                     (/ (- (get-internal-real-time) start)
                        internal-time-units-per-second)))
               (expect (getf result :timed-out) :to-be-truthy)
               (expect elapsed-seconds :to-be-less-than 8))
          (when (probe-file pid-path)
            (with-open-file (pid-stream pid-path)
              (setf pid (read-line pid-stream nil nil))))
          (when (and pid (plusp (length pid)))
            ;; Not /bin/kill: Nix's Linux build sandbox only bind-mounts
            ;; /bin/sh, not a full FHS /bin, so spawning an external kill
            ;; binary is unreliable here. SB-POSIX:KILL signals the PID
            ;; directly with no external process or PATH lookup involved.
            (require :sb-posix)
            (ignore-errors
              (funcall (read-from-string "sb-posix:kill")
                       (parse-integer pid) 9)))
          (ignore-errors (delete-file pid-path))))))

  ;; Regression: a timed-out subprocess was only ever sent SIGTERM; a child
  ;; that traps or ignores it hung PROCESS-BOUNDARY-RUN forever despite a
  ;; :TIMEOUT being given. The runner must escalate to SIGKILL (uncatchable)
  ;; after a bounded grace period. Uses the running SBCL as the subprocess so
  ;; the test needs no external command on PATH.
  (it "native-process-run-escalates-to-sigkill-when-the-subprocess-ignores-sigterm"
    (let* ((runtime (namestring sb-ext:*runtime-pathname*))
           (start (get-internal-real-time))
           (result (process-boundary-run
                    *native-process-boundary* runtime
                    :arguments (list "--non-interactive" "--no-sysinit" "--no-userinit"
                                     "--eval" "(sb-sys:enable-interrupt sb-unix:sigterm :ignore)"
                                     "--eval" "(sleep 30)")
                    :timeout 1))
           (elapsed-seconds (/ (- (get-internal-real-time) start)
                               internal-time-units-per-second)))
      (expect (getf result :timed-out) :to-be-truthy)
      ;; 1s deadline + a few seconds of SIGTERM grace before SIGKILL, well
      ;; short of the full 30s sleep.
      (expect elapsed-seconds :to-be-less-than 10))))

(describe "native process output capture"
  ;; Regression: %RUN-NATIVE-PROCESS/CPS used to wait for the whole process to
  ;; exit before reading stdout/stderr. A child writing more than one OS pipe
  ;; buffer combined across both streams blocks on write() until drained, so
  ;; waiting-then-reading deadlocks forever on large output. Streams must be
  ;; drained concurrently with waiting. Uses the running SBCL as the
  ;; subprocess so the test needs no external command on PATH.
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
      (expect (length (getf result :stdout)) :to-be-greater-than-or-equal 400000)
      (expect (let ((stdout (getf result :stdout)))
                (subseq stdout (- (length stdout) 10)))
              :to-equal "0123456789")))

  (it
    "native-process-run-captures-large-stderr-without-deadlocking"
    (let* ((process (make-process-boundary))
           (runtime (namestring sb-ext:*runtime-pathname*))
           (result
          (process-boundary-run
            process
            runtime
            :arguments
            (list
              "--non-interactive"
              "--no-sysinit"
              "--no-userinit"
              "--eval"
              "(progn (loop repeat 40000 do (write-string \"0123456789\" *error-output*)) (finish-output *error-output*))")
            :timeout
            15)))
      (expect (length (getf result :stderr)) :to-be-greater-than-or-equal 400000)
      (expect
        (let ((stderr (getf result :stderr)))
          (subseq stderr (- (length stderr) 10)))
        :to-equal "0123456789")))

  ;; Regression: if the stderr-capture thread failed to start (e.g. resource
  ;; exhaustion), %RUN-NATIVE-PROCESS/CPS exited before ever reaching
  ;; %WAIT-FOR-PROCESS-WITH-TIMEOUT, so the already-spawned child was neither
  ;; killed nor reaped -- it kept running as an untracked orphan, and joining
  ;; the stdout-capture thread (already blocked reading its pipe) would not
  ;; return until that orphan's own natural lifetime ended. sb-thread:make-thread
  ;; is monkey-patched here (via without-package-locks) to fail on its second
  ;; call within a single process-boundary-run, deterministically forcing the
  ;; path that previously leaked; a long child (sleep) proves the fix returns
  ;; promptly rather than waiting out the sleep, and that no process lingers.
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
      (expect (/ (- (get-internal-real-time) start)
                 internal-time-units-per-second)
              :to-be-less-than 2))))

(defun %run-native-reporting (var-names &rest environment-args)
  (let* ((process (make-process-boundary))
         (runtime (namestring sb-ext:*runtime-pathname*))
         (probe
        (format
          nil
          "(dolist (v '~S) (format t \"[~~A]\" (sb-ext:posix-getenv v)))"
          var-names)))
    (getf
      (apply
        #'process-boundary-run
        process
        runtime
        :arguments
        (list "--non-interactive" "--no-sysinit" "--no-userinit" "--eval" probe)
        environment-args)
      :stdout)))

(describe "native process environment"
  ;; Regression (security): omitting :ENVIRONMENT entirely must still inherit
  ;; the parent process's environment (unchanged existing behavior).
  (it
    "native-process-run-inherits-the-parent-environment-when-not-supplied"
    (expect (%run-native-reporting '("PATH")) :not :to-match "[NIL]"))

  ;; Regression (security): %NATIVE-PROCESS-OPTIONS used to test ENVIRONMENT's
  ;; truthiness, so an explicit empty :ENVIRONMENT '() was indistinguishable
  ;; from "not supplied" and silently fell back to inheriting the full parent
  ;; environment -- exactly the case a caller passing :environment '() is
  ;; trying to avoid (e.g. running an untrusted command without leaking
  ;; ambient secrets). It must now reach the child as a genuinely empty
  ;; environment.
  (it
    "native-process-run-honors-an-explicit-empty-environment-instead-of-inheriting"
    (expect (%run-native-reporting '("PATH") :environment nil) :to-match "[NIL]"))

  ;; Regression: sb-ext:run-program's :ENV wants (KEYWORD . STRING) conses,
  ;; but every other environment representation in this library (e.g.
  ;; ENVIRONMENT-LIST's return value) uses STRING keys, so passing that
  ;; natural alist straight into :ENVIRONMENT used to crash deep inside SBCL
  ;; instead of working.
  (it
    "native-process-run-accepts-a-string-keyed-environment-alist"
    (expect (%run-native-reporting '("MARKER" "PATH") :environment '(("MARKER" . "hello"))) :to-match "[hello][NIL]")))

(describe "native process search path"
  ;; *NATIVE-PROCESS-SEARCH-PATH-P* is opt-in so the default native runner does
  ;; not implicitly resolve attacker-influenced program names through $PATH.
  (it
    "native-process-search-path-p-defaults-to-nil-and-requires-an-absolute-path"
    (expect *native-process-search-path-p* :to-be-null)
    (let ((process (make-process-boundary)))
      (signals
        error
        (process-boundary-run process "sh" :arguments (list "-c" "echo ok")))
      (expect (getf (process-boundary-run
                     process
                     (namestring sb-ext:*runtime-pathname*)
                     :arguments (list "--version"))
                    :exit-code)
              :to-equal 0)))

  (it
    "native-process-search-path-p-bound-to-t-searches-path"
    (let ((process (make-process-boundary))
          (*native-process-search-path-p* t))
      (expect (getf (process-boundary-run process "sh" :arguments (list "-c" "echo ok"))
                    :stdout)
              :to-match "ok"))))


(describe "process result"
  (it
    "process-result-success-p-reads-the-exit-code"
    (let ((ok
          (make-test-process-boundary
            :results
            (list (list :stdout "ok" :stderr "" :exit-code 0))))
          (bad
          (make-test-process-boundary
            :results
            (list (list :stdout "" :stderr "boom" :exit-code 1)))))
      (expect (process-result-success-p (process-boundary-run ok "cmd")) :to-be t)
      (expect (process-result-success-p (process-boundary-run bad "cmd")) :to-be-null)))

  (it
    "process-result-success-p-signals-on-a-result-without-an-integer-exit-code"
    (signals error (process-result-success-p (list :stdout "x"))))

  (it
    "process-result-check-returns-the-result-on-success"
    (let ((result (list :command '("cmd") :stdout "ok" :stderr "" :exit-code 0)))
      (expect (process-result-check result) :to-be result)))

  (it
    "process-result-check-signals-with-diagnostics-on-failure"
    (expect (lambda ()
              (process-result-check
               (list :command '("cmd") :stdout "" :stderr "boom" :exit-code 2)))
            :to-throw "boom")))

(describe "native process option helpers"
  ;; Unit coverage for the native process-runner helpers whose branches the
  ;; boundary-level tests do not otherwise reach: environment-entry
  ;; normalization (string, symbol-keyed cons, and rejection) and the
  ;; capture-destination predicate.
  (it
    "process-environment-entry-string-normalizes-every-accepted-shape"
    (expect
      (cl-boundary-kit::%process-environment-entry-string "NAME=value")
      :to-equal
      "NAME=value")
    (expect
      (cl-boundary-kit::%process-environment-entry-string '("NAME" . "value"))
      :to-equal
      "NAME=value")
    (expect
      (cl-boundary-kit::%process-environment-entry-string '(:name . "value"))
      :to-equal
      "NAME=value"))

  (it
    "process-environment-entry-string-rejects-an-unsupported-entry"
    (expect (lambda () (cl-boundary-kit::%process-environment-entry-string 42)) :to-throw "Invalid process environment entry"))

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
      (expect (getf result :exit-code) :to-be 0)
      (expect (getf result :stdout) :to-be-null)
      (expect (getf result :stderr) :to-be-null)
      (expect (get-output-stream-string output) :to-equal "out")
      (expect (get-output-stream-string error-output) :to-equal "err"))))

(describe "native process run"
  ;; Covers the :DIRECTORY and :INPUT arms of %NATIVE-PROCESS-OPTIONS. Uses the
  ;; running SBCL as the subprocess so no external command is needed under the
  ;; Nix sandbox; it just exits 0 after receiving an (empty) input stream and a
  ;; working directory.
  (it
    "native-process-run-accepts-a-working-directory-and-input-stream"
    (let* ((process (make-process-boundary))
           (runtime (namestring sb-ext:*runtime-pathname*)))
      (with-input-from-string (input "")
        (let ((result
              (process-boundary-run
                process
                runtime
                :arguments
                (list
                  "--non-interactive"
                  "--no-sysinit"
                  "--no-userinit"
                  "--eval"
                  "(sb-ext:quit)")
                :input
                input
                :directory
                (uiop:temporary-directory))))
          (expect (getf result :exit-code) :to-be 0)))))

  (it
    "native-process-run-completes-a-short-lived-child-before-timeout-polling"
    (let ((result
          (process-boundary-run
            (make-process-boundary)
            "/bin/sh"
            :arguments
            (list "-c" "exit 0")
            :timeout
            5)))
      (expect (getf result :exit-code) :to-be 0)
      (expect (getf result :timed-out) :to-be-null)))

  (it
    "native-process-run-waits-without-a-deadline-and-preserves-a-nonzero-exit-status"
    (let ((result
          (process-boundary-run
            (make-process-boundary)
            "/bin/sh"
            :arguments
            (list "-c" "printf failure >&2; exit 7")
            :timeout
            nil)))
      (expect (getf result :exit-code) :to-be 7)
      (expect (getf result :stderr) :to-match "failure")
      (expect (getf result :timed-out) :to-be-null)))

  (it
    "native-process-run-cleans-up-when-the-second-capture-thread-cannot-start"
    (let* ((symbol (find-symbol "%START-CAPTURING-THREAD" "CL-BOUNDARY-KIT"))
           (original (symbol-function symbol))
           (attempts 0)
           (start (get-internal-real-time))
           (signaled-p nil))
      (unwind-protect
           (progn
             (sb-ext:without-package-locks (setf (symbol-function symbol)
                     (lambda (&rest arguments)
                       (incf attempts)
                       (if (= attempts 2)
                           (error "capture startup failed")
                           (apply original arguments)))))
             (handler-case
                 (process-boundary-run
                  (make-process-boundary)
                  "/bin/sh"
                  :arguments (list "-c" "sleep 30")
                  :timeout 10)
               (error ()
                 (setf signaled-p t)))
             (expect signaled-p :to-be-truthy)
             (expect attempts :to-be 2)
             (expect (/ (- (get-internal-real-time) start)
                        internal-time-units-per-second)
                     :to-be-less-than 10))
        (sb-ext:without-package-locks (setf (symbol-function symbol) original)))))

  (it
    "process-boundary-run-rejects-a-non-process-boundary"
    (expect (lambda () (process-boundary-run (list :boundary-type :not-a-process) "cmd")) :to-throw "must be a process boundary")))
