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
                                   :timeout *default-process-timeout-seconds*
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
               (list (process-call :command "noop"
                                   :timeout *default-process-timeout-seconds*
                                   :result nil))) :to-be-truthy)))

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
                     :timeout *default-process-timeout-seconds*
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
                     :timeout *default-process-timeout-seconds*
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
               (list (process-call :command "noop"
                                   :timeout *default-process-timeout-seconds*
                                   :result nil))) :to-be-truthy)))

(it "make-recording-process-boundary-rejects-non-process-delegate"
  (signals error
    (make-recording-process-boundary :delegate :bad)))

(it-each ((recording-process-calls)
          (reset-recording-process-calls))
    "~A signals for unsupported boundary types"
    (operation)
  (expect (lambda () (funcall operation (make-process-boundary)))
          :to-signal-message-containing "Unsupported process boundary type"))

(it "reset-recording-process-calls-clears-history-and-returns-the-boundary"
  (let ((process (make-test-process-boundary :results (list (process-result :stdout "ok")
                                                             (process-result :stdout "ok2")))))
    (process-boundary-run process "cmd")
    (expect (= (length (recording-process-calls process)) 1) :to-be-truthy)
    (expect (eq (reset-recording-process-calls process) process) :to-be-truthy)
    (expect (null (recording-process-calls process)) :to-be-truthy)
    (process-boundary-run process "cmd2")
    (expect (= (length (recording-process-calls process)) 1) :to-be-truthy)))

;;; Regression: captured native output used to be reconstructed line-by-line,
;;; which dropped the trailing newline that most tools emit.
;;; Regression: a process killed on timeout used to be indistinguishable from
;;; one that merely exited with a NIL code.  The result now flags the timeout,
;;; while a normal run keeps its historical plist shape.
;;; Exercises the real deadline/kill path end to end: a subprocess that outlives
;;; its timeout is terminated and the result flags the timeout rather than
;;; masquerading as a normal exit.  Uses the running SBCL as the subprocess so
;;; the test needs no external command on PATH (important under the Nix sandbox).
;;; Regression: a timed-out subprocess was only ever sent SIGTERM; a child
;;; that traps or ignores it hung PROCESS-BOUNDARY-RUN forever despite a
;;; :TIMEOUT being given. The runner must escalate to SIGKILL (uncatchable)
;;; after a bounded grace period. Uses the running SBCL as the subprocess so
;;; the test needs no external command on PATH.
;;; Regression: %RUN-NATIVE-PROCESS/CPS used to wait for the whole process to
;;; exit before reading stdout/stderr. A child writing more than one OS pipe
;;; buffer combined across both streams blocks on write() until drained, so
;;; waiting-then-reading deadlocks forever on large output. Streams must be
;;; drained concurrently with waiting. Uses the running SBCL as the
;;; subprocess so the test needs no external command on PATH.
;;; Regression (security): omitting :ENVIRONMENT entirely must still inherit
;;; the parent process's environment (unchanged existing behavior).
;;; Regression (security): %NATIVE-PROCESS-OPTIONS used to test ENVIRONMENT's
;;; truthiness, so an explicit empty :ENVIRONMENT '() was indistinguishable
;;; from "not supplied" and silently fell back to inheriting the full parent
;;; environment -- exactly the case a caller passing :environment '() is
;;; trying to avoid (e.g. running an untrusted command without leaking
;;; ambient secrets). It must now reach the child as a genuinely empty
;;; environment.
;;; Regression: sb-ext:run-program's :ENV wants (KEYWORD . STRING) conses,
;;; but every other environment representation in this library (e.g.
;;; ENVIRONMENT-LIST's return value) uses STRING keys, so passing that
;;; natural alist straight into :ENVIRONMENT used to crash deep inside SBCL
;;; instead of working.
;;; *NATIVE-PROCESS-SEARCH-PATH-P* is opt-in so the default native runner does
;;; not implicitly resolve attacker-influenced program names through $PATH.
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
;;; Unit coverage for the native process-runner helpers whose branches the
;;; boundary-level tests do not otherwise reach: environment-entry
;;; normalization (string, symbol-keyed cons, and rejection) and the
;;; capture-destination predicate.

;;; Covers the :DIRECTORY and :INPUT arms of %NATIVE-PROCESS-OPTIONS. Uses the
;;; running SBCL as the subprocess so no external command is needed under the
;;; Nix sandbox; it just exits 0 after receiving an (empty) input stream and a
;;; working directory.
