;;;; t/process-test.lisp

(in-package #:cl-boundary-kit/test)

(defparameter +process-test-timeout+ 2)

(defun process-result (&key (stdout "") (stderr "") (exit-code 0) command)
  (append (when command (list :command command))
          (list :stdout stdout :stderr stderr :exit-code exit-code)))

(defun process-call (&key command arguments input directory environment output error-output timeout result)
  (list :command command
        :arguments arguments
        :input input
        :directory directory
        :environment environment
        :output output
        :error-output error-output
        :timeout timeout
        :result result))

(defmacro with-process-boundary ((name &rest initargs) &body body)
  `(let ((,name (make-process-boundary ,@initargs)))
     ,@body))

(defmacro with-test-process-boundary ((name &key results) &body body)
  `(let ((,name (make-test-process-boundary :results ,results)))
     ,@body))

(defmacro with-recording-process-boundary ((name runner) &body body)
  `(let ((,name (make-recording-process-boundary
                 :delegate (make-process-boundary :run-fn ,runner))))
     ,@body))

(defmacro with-recording-process-runner ((name result-form) &body body)
  `(with-recording-process-boundary
       (,name (lambda (command &key arguments input directory environment output error-output timeout)
                (declare (ignorable command arguments input directory environment output error-output timeout))
                ,result-form))
     ,@body))

(defmacro with-process-boundary-runner ((name result-form) &body body)
  `(with-process-boundary
       (,name
        :run-fn (lambda (command &key arguments input directory environment output error-output timeout)
                  (declare (ignorable command arguments input directory environment output error-output timeout))
                  ,result-form))
     ,@body))

(defun assert-single-recorded-process-call (process expected-call)
  (let ((calls (recording-process-calls process)))
    (expect (= 1 (length calls)) :to-be-truthy)
    (expect (equal (first calls) expected-call) :to-be-truthy)))

(it "process-boundary-runs-command"
  (let ((*native-process-search-path-p* t))
    (with-process-boundary (process)
      (let ((result (process-boundary-run process "sh" :arguments (list "-c" "printf hi"))))
        (expect (string= (getf result :stdout) "hi") :to-be-truthy)
        (expect (= (getf result :exit-code) 0) :to-be-truthy)))))

(it "process-boundary-returns-command-shape-and-stderr"
  (let ((*native-process-search-path-p* t))
    (with-process-boundary (process)
      (let ((result (process-boundary-run process "sh"
                                          :arguments (list "-c" "printf out && printf err >&2"))))
        (expect (equal (getf result :command) '("sh" "-c" "printf out && printf err >&2")) :to-be-truthy)
        (expect (string= (getf result :stdout) "out") :to-be-truthy)
        (expect (string= (getf result :stderr) "err") :to-be-truthy)
        (expect (= (getf result :exit-code) 0) :to-be-truthy)))))

(it "process-boundary-normalizes-list-command-with-arguments"
  (let ((*native-process-search-path-p* t))
    (with-process-boundary (process)
      (let ((result (process-boundary-run process '("sh" "-c")
                                          :arguments (list "printf hi"))))
        (expect (equal (getf result :command) '("sh" "-c" "printf hi")) :to-be-truthy)
        (expect (string= (getf result :stdout) "hi") :to-be-truthy)
        (expect (= (getf result :exit-code) 0) :to-be-truthy)))))

(it "process-boundary-copies-string-command-argument-tail"
  (with-process-boundary-runner
      (process (process-result
                :command (cl-boundary-kit::normalize-command command arguments)))
    (let* ((arguments (list "one" "two"))
           (result (process-boundary-run process "cmd" :arguments arguments)))
      (setf (first arguments) "changed"
            (rest arguments) nil)
      (expect (equal (getf result :command) '("cmd" "one" "two")) :to-be-truthy))))

(it "process-boundary-copies-list-command-argument-tail"
  (with-process-boundary-runner
      (process (process-result
                :command (cl-boundary-kit::normalize-command command arguments)))
    (let* ((arguments (list "one" "two"))
           (result (process-boundary-run process '("cmd" "--flag") :arguments arguments)))
      (setf (first arguments) "changed"
            (rest arguments) nil)
      (expect (equal (getf result :command) '("cmd" "--flag" "one" "two")) :to-be-truthy))))

(it "make-process-boundary-rejects-non-function-runner"
  (signals error
    (make-process-boundary :run-fn :bad)))

(it "test-process-boundary-consumes-queued-results-and-records-calls"
  (with-test-process-boundary (process
                               :results (list (process-result :stdout "one")
                                              (process-result :stdout "two"
                                                              :stderr "warn"
                                                              :exit-code 3)))
    (expect (equal (process-boundary-run process "first" :arguments '("--flag"))
               (process-result :stdout "one")) :to-be-truthy)
    (expect (equal (process-boundary-run process "second"
                                     :input "payload"
                                     :timeout +process-test-timeout+)
               (process-result :stdout "two"
                               :stderr "warn"
                               :exit-code 3)) :to-be-truthy)
    (expect (equal (recording-process-calls process)
               (list (process-call :command "first"
                                   :arguments '("--flag")
                                   :result (process-result :stdout "one"))
                     (process-call :command "second"
                                   :input "payload"
                                   :timeout +process-test-timeout+
                                   :result (process-result :stdout "two"
                                                           :stderr "warn"
                                                           :exit-code 3)))) :to-be-truthy)))

(it "test-process-boundary-copies-seeded-results-list"
  (let* ((first-result (process-result :stdout "one"))
         (second-result (process-result :stdout "two"))
         (results (list first-result second-result))
         (process (make-test-process-boundary :results results)))
    (setf (first results) (process-result :stdout "changed")
          (rest results) nil)
    (expect (equal first-result (process-boundary-run process "first")) :to-be-truthy)
    (expect (equal second-result (process-boundary-run process "second")) :to-be-truthy)))

(it "test-process-boundary-signals-when-results-are-exhausted"
  (with-test-process-boundary (process :results nil)
    (signals error
      (process-boundary-run process "missing"))))

(it "test-process-boundary-preserves-explicit-nil-results-in-call-history"
  (with-test-process-boundary (process :results (list nil))
    (expect (null (process-boundary-run process "noop")) :to-be-truthy)
    (expect (equal (recording-process-calls process)
               (list (process-call :command "noop" :result nil))) :to-be-truthy)))

(it "make-test-process-boundary-rejects-non-list-results"
  (signals error
    (make-test-process-boundary :results :bad)))

(it "recording-process-boundary-records"
  (with-recording-process-runner (process (process-result :stdout "ok"))
    (let ((result (process-boundary-run process "sh"
                                        :arguments (list "-c" "exit 0")
                                        :input ""
                                        :directory #P"/tmp/"
                                        :environment '(("A" . "1"))
                                        :output :string
                                        :error-output :string
                                        :timeout +process-test-timeout+)))
      (expect (equal result (process-result :stdout "ok")) :to-be-truthy)
      (assert-single-recorded-process-call
       process
       (process-call :command "sh"
                     :arguments '("-c" "exit 0")
                     :input ""
                     :directory #P"/tmp/"
                     :environment '(("A" . "1"))
                     :output :string
                     :error-output :string
                     :timeout +process-test-timeout+
                     :result (process-result :stdout "ok"))))))

(it "recording-process-boundary-preserves-list-command-input"
  (with-recording-process-runner
      (process (process-result :command (append command arguments)
                               :stdout "ok"))
    (let ((result (process-boundary-run process '("sh" "-c")
                                        :arguments (list "printf hi"))))
      (expect (equal result (process-result :command '("sh" "-c" "printf hi")
                                        :stdout "ok")) :to-be-truthy)
      (assert-single-recorded-process-call
       process
       (process-call :command '("sh" "-c")
                     :arguments '("printf hi")
                     :result (process-result :command '("sh" "-c" "printf hi")
                                             :stdout "ok"))))))

(it "recording-process-boundary-history-is-independent-of-mutated-command-arguments"
  (with-recording-process-runner (process (process-result :stdout "ok"))
    (let ((command (list "sh" "-c"))
          (arguments (list "printf hi")))
      (process-boundary-run process command :arguments arguments)
      (setf (first command) "changed"
            (first arguments) "changed")
      (assert-single-recorded-process-call
       process
       (process-call :command '("sh" "-c")
                     :arguments '("printf hi")
                     :result (process-result :stdout "ok"))))))

;;; Regression: wrapping a self-recording (:TEST-kind) delegate used to
;;; double-record every call -- once on the wrapper, once on the delegate's
;;; own history -- because the recording dispatch recursed through the
;;; delegate's public PROCESS-BOUNDARY-RUN, re-entering the delegate's own
;;; recording path. Only the wrapper should record.
(it "recording-process-boundary-does-not-double-record-a-self-recording-delegate"
  (let* ((delegate (make-test-process-boundary :results (list (process-result :stdout "ok"))))
         (process (make-recording-process-boundary :delegate delegate)))
    (process-boundary-run process "cmd")
    (expect (= (length (recording-process-calls process)) 1) :to-be-truthy)
    (expect (= (length (recording-process-calls delegate)) 0) :to-be-truthy)))

(it "process-boundary-forwards-timeout-to-custom-runner"
  (with-process-boundary-runner (process (process-result :stdout (write-to-string timeout)))
    (let ((result (process-boundary-run process "demo" :timeout +process-test-timeout+)))
      (expect (equal result
                 (process-result :stdout (write-to-string +process-test-timeout+))) :to-be-truthy))))

(it "recording-process-boundary-propagates-errors-without-recording"
  (with-recording-process-runner (process (error "process failed"))
    (signals error
      (process-boundary-run process "explode"))
    (let ((calls (recording-process-calls process)))
      (expect (null calls) :to-be-truthy))))

(it "recording-process-boundary-preserves-explicit-nil-results-in-call-history"
  (with-recording-process-runner (process nil)
    (expect (null (process-boundary-run process "noop")) :to-be-truthy)
    (expect (equal (recording-process-calls process)
               (list (process-call :command "noop" :result nil))) :to-be-truthy)))

(it "make-recording-process-boundary-rejects-non-process-delegate"
  (signals error
    (make-recording-process-boundary :delegate :bad)))

(it "recording-process-calls-signals-for-unsupported-boundary-types"
  (signals-error-message-contains "Unsupported process boundary type"
      (recording-process-calls (make-process-boundary))))

(it "reset-recording-process-calls-clears-history-and-returns-the-boundary"
  (let ((process (make-test-process-boundary :results (list (process-result :stdout "ok")
                                                             (process-result :stdout "ok2")))))
    (process-boundary-run process "cmd")
    (expect (= (length (recording-process-calls process)) 1) :to-be-truthy)
    (expect (eq (reset-recording-process-calls process) process) :to-be-truthy)
    (expect (null (recording-process-calls process)) :to-be-truthy)
    (process-boundary-run process "cmd2")
    (expect (= (length (recording-process-calls process)) 1) :to-be-truthy)))

(it "reset-recording-process-calls-signals-for-unsupported-boundary-types"
  (signals-error-message-contains "Unsupported process boundary type"
      (reset-recording-process-calls (make-process-boundary))))

;;; Regression: captured native output used to be reconstructed line-by-line,
;;; which dropped the trailing newline that most tools emit.
(it "native-process-output-capture-preserves-a-trailing-newline"
  (expect (string= (format nil "hello~%")
                   (cl-boundary-kit::%slurp-stream
                    (make-string-input-stream (format nil "hello~%"))))
          :to-be-truthy)
  (expect (string= "" (cl-boundary-kit::%slurp-stream
                       (make-string-input-stream "")))
          :to-be-truthy))

;;; Regression: a process killed on timeout used to be indistinguishable from
;;; one that merely exited with a NIL code.  The result now flags the timeout,
;;; while a normal run keeps its historical plist shape.
(it "native-process-result-flags-a-timeout-without-perturbing-normal-runs"
  (expect (getf (cl-boundary-kit::%make-native-process-result
                 '("prog") "" "" nil t)
                :timed-out)
          :to-be-truthy)
  (expect (null (member :timed-out
                        (cl-boundary-kit::%make-native-process-result
                         '("prog") "out" "" 0)))
          :to-be-truthy))

;;; Exercises the real deadline/kill path end to end: a subprocess that outlives
;;; its timeout is terminated and the result flags the timeout rather than
;;; masquerading as a normal exit.  Uses the running SBCL as the subprocess so
;;; the test needs no external command on PATH (important under the Nix sandbox).
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

;;; Regression: a timed-out subprocess was only ever sent SIGTERM; a child
;;; that traps or ignores it hung PROCESS-BOUNDARY-RUN forever despite a
;;; :TIMEOUT being given. The runner must escalate to SIGKILL (uncatchable)
;;; after a bounded grace period. Uses the running SBCL as the subprocess so
;;; the test needs no external command on PATH.
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

;;; Regression: %RUN-NATIVE-PROCESS/CPS used to wait for the whole process to
;;; exit before reading stdout/stderr. A child writing more than one OS pipe
;;; buffer combined across both streams blocks on write() until drained, so
;;; waiting-then-reading deadlocks forever on large output. Streams must be
;;; drained concurrently with waiting. Uses the running SBCL as the
;;; subprocess so the test needs no external command on PATH.
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

;;; Regression (security): omitting :ENVIRONMENT entirely must still inherit
;;; the parent process's environment (unchanged existing behavior).
(it "native-process-run-inherits-the-parent-environment-when-not-supplied"
  (expect (not (search "[NIL]" (%run-native-reporting '("PATH")))) :to-be-truthy))

;;; Regression (security): %NATIVE-PROCESS-OPTIONS used to test ENVIRONMENT's
;;; truthiness, so an explicit empty :ENVIRONMENT '() was indistinguishable
;;; from "not supplied" and silently fell back to inheriting the full parent
;;; environment -- exactly the case a caller passing :environment '() is
;;; trying to avoid (e.g. running an untrusted command without leaking
;;; ambient secrets). It must now reach the child as a genuinely empty
;;; environment.
(it "native-process-run-honors-an-explicit-empty-environment-instead-of-inheriting"
  (expect (search "[NIL]" (%run-native-reporting '("PATH") :environment nil))
          :to-be-truthy))

;;; Regression: sb-ext:run-program's :ENV wants (KEYWORD . STRING) conses,
;;; but every other environment representation in this library (e.g.
;;; ENVIRONMENT-LIST's return value) uses STRING keys, so passing that
;;; natural alist straight into :ENVIRONMENT used to crash deep inside SBCL
;;; instead of working.
(it "native-process-run-accepts-a-string-keyed-environment-alist"
  (expect (search "[hello][NIL]"
                  (%run-native-reporting '("MARKER" "PATH")
                                         :environment '(("MARKER" . "hello"))))
          :to-be-truthy))

;;; *NATIVE-PROCESS-SEARCH-PATH-P* is opt-in so the default native runner does
;;; not implicitly resolve attacker-influenced program names through $PATH.
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

;;; Regression: if the stderr-capture thread failed to start (e.g. resource
;;; exhaustion), %RUN-NATIVE-PROCESS/CPS exited before ever reaching
;;; %WAIT-FOR-PROCESS-WITH-TIMEOUT, so the already-spawned child was neither
;;; killed nor reaped -- it kept running as an untracked orphan, and joining
;;; the stdout-capture thread (already blocked reading its pipe) would not
;;; return until that orphan's own natural lifetime ended. sb-thread:make-thread
;;; is monkey-patched here (via without-package-locks) to fail on its second
;;; call within a single process-boundary-run, deterministically forcing the
;;; path that previously leaked; a long child (sleep) proves the fix returns
;;; promptly rather than waiting out the sleep, and that no process lingers.
(it "native-process-run-kills-the-child-and-returns-promptly-if-a-capture-thread-fails-to-start"
  (let* ((process (make-process-boundary))
         (runtime (namestring sb-ext:*runtime-pathname*))
         (call-count 0)
         (original (symbol-function 'sb-thread:make-thread))
         (start (get-internal-real-time)))
    (unwind-protect
        (progn
          (sb-ext:without-package-locks
            (setf (symbol-function 'sb-thread:make-thread)
                  (lambda (function &rest args)
                    (incf call-count)
                    (if (= call-count 2)
                        (error "simulated capture-thread spawn failure")
                        (apply original function args)))))
          (signals error
            (process-boundary-run process runtime
                                  :arguments (list "--non-interactive" "--no-sysinit" "--no-userinit"
                                                   "--eval" "(sleep 5)"))))
      (sb-ext:without-package-locks
        (setf (symbol-function 'sb-thread:make-thread) original)))
    ;; Well under the child's 5s sleep: proves the fix didn't block waiting
    ;; for the child's natural lifetime to end.
    (expect (< (/ (- (get-internal-real-time) start) internal-time-units-per-second) 2)
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
