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
    (expect calls :to-have-length 1)
    (expect (first calls) :to-equal expected-call)))

(describe "process boundary"
  (it "process-boundary-runs-command"
    (let ((*native-process-search-path-p* t))
      (with-process-boundary (process)
        (let ((result (process-boundary-run process "sh" :arguments (list "-c" "printf hi"))))
          (expect (getf result :stdout) :to-equal "hi")
          (expect (getf result :exit-code) :to-be 0)))))

  (it "process-boundary-returns-command-shape-and-stderr"
    (let ((*native-process-search-path-p* t))
      (with-process-boundary (process)
        (let ((result (process-boundary-run process "sh"
                                            :arguments (list "-c" "printf out && printf err >&2"))))
          (expect (getf result :command) :to-equal '("sh" "-c" "printf out && printf err >&2"))
          (expect (getf result :stdout) :to-equal "out")
          (expect (getf result :stderr) :to-equal "err")
          (expect (getf result :exit-code) :to-be 0)))))

  (it "process-boundary-normalizes-list-command-with-arguments"
    (let ((*native-process-search-path-p* t))
      (with-process-boundary (process)
        (let ((result (process-boundary-run process '("sh" "-c")
                                            :arguments (list "printf hi"))))
          (expect (getf result :command) :to-equal '("sh" "-c" "printf hi"))
          (expect (getf result :stdout) :to-equal "hi")
          (expect (getf result :exit-code) :to-be 0)))))

  (it "process-boundary-copies-string-command-argument-tail"
    (with-process-boundary-runner
        (process (process-result
                  :command (cl-boundary-kit::normalize-command command arguments)))
      (let* ((arguments (list "one" "two"))
             (result (process-boundary-run process "cmd" :arguments arguments)))
        (setf (first arguments) "changed"
              (rest arguments) nil)
        (expect (getf result :command) :to-equal '("cmd" "one" "two")))))

  (it "process-boundary-copies-list-command-argument-tail"
    (with-process-boundary-runner
        (process (process-result
                  :command (cl-boundary-kit::normalize-command command arguments)))
      (let* ((arguments (list "one" "two"))
             (result (process-boundary-run process '("cmd" "--flag") :arguments arguments)))
        (setf (first arguments) "changed"
              (rest arguments) nil)
        (expect (getf result :command) :to-equal '("cmd" "--flag" "one" "two")))))

  (it "make-process-boundary-rejects-non-function-runner"
    (signals error
      (make-process-boundary :run-fn :bad))))

(describe "test process boundary"
  (it "test-process-boundary-consumes-queued-results-and-records-calls"
    (with-test-process-boundary (process
                                 :results (list (process-result :stdout "one")
                                                (process-result :stdout "two"
                                                                :stderr "warn"
                                                                :exit-code 3)))
      (expect (process-boundary-run process "first" :arguments '("--flag"))
              :to-equal (process-result :stdout "one"))
      (expect (process-boundary-run process "second"
                                    :input "payload"
                                    :timeout +process-test-timeout+)
              :to-equal (process-result :stdout "two"
                                        :stderr "warn"
                                        :exit-code 3))
      (expect (recording-process-calls process)
              :to-have-recorded-calls
              (list (process-call :command "first"
                                  :arguments '("--flag")
                                  :timeout *default-process-timeout-seconds*
                                  :result (process-result :stdout "one"))
                    (process-call :command "second"
                                  :input "payload"
                                  :timeout +process-test-timeout+
                                  :result (process-result :stdout "two"
                                                          :stderr "warn"
                                                          :exit-code 3))))))

  (it "test-process-boundary-copies-seeded-results-list"
    (let* ((first-result (process-result :stdout "one"))
           (second-result (process-result :stdout "two"))
           (results (list first-result second-result))
           (process (make-test-process-boundary :results results)))
      (setf (first results) (process-result :stdout "changed")
            (rest results) nil)
      (expect (process-boundary-run process "first") :to-equal first-result)
      (expect (process-boundary-run process "second") :to-equal second-result)))

  (it "test-process-boundary-signals-when-results-are-exhausted"
    (with-test-process-boundary (process :results nil)
      (signals error
        (process-boundary-run process "missing"))))

  (it "test-process-boundary-preserves-explicit-nil-results-in-call-history"
    (with-test-process-boundary (process :results (list nil))
      (expect (process-boundary-run process "noop") :to-be-null)
      (expect (recording-process-calls process)
              :to-have-recorded-calls
              (list (process-call :command "noop"
                                  :timeout *default-process-timeout-seconds*
                                  :result nil)))))

  (it "make-test-process-boundary-rejects-non-list-results"
    (signals error
      (make-test-process-boundary :results :bad))))

(describe "recording process boundary"
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
        (expect result :to-equal (process-result :stdout "ok"))
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
        (expect result :to-equal (process-result :command '("sh" "-c" "printf hi")
                                                :stdout "ok"))
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

  ;; Regression: wrapping a self-recording (:TEST-kind) delegate used to
  ;; double-record every call -- once on the wrapper, once on the delegate's
  ;; own history -- because the recording dispatch recursed through the
  ;; delegate's public PROCESS-BOUNDARY-RUN, re-entering the delegate's own
  ;; recording path. Only the wrapper should record.
  (it "recording-process-boundary-does-not-double-record-a-self-recording-delegate"
    (let* ((delegate (make-test-process-boundary :results (list (process-result :stdout "ok"))))
           (process (make-recording-process-boundary :delegate delegate)))
      (process-boundary-run process "cmd")
      (expect (recording-process-calls process) :to-have-length 1)
      (expect (recording-process-calls delegate) :to-have-length 0))))

(describe "process boundary timeout"
  (it "process-boundary-validates-timeout-before-consuming-test-results"
    (let* ((first-result (process-result :stdout "first"))
           (second-result (process-result :stdout "second"))
           (process (make-test-process-boundary
                     :results (list first-result second-result))))
      (signals error
        (process-boundary-run process "negative" :timeout -1))
      (signals error
        (process-boundary-run process "non-real" :timeout :bad))
      (expect (recording-process-calls process) :to-be-null)
      (expect (process-boundary-run process "valid" :timeout 0) :to-equal first-result)))

  (progn
    (it "process-boundary-forwards-timeout-to-custom-runner"
      (with-process-boundary-runner (process (process-result :stdout (write-to-string timeout)))
        (let ((result (process-boundary-run process "demo" :timeout +process-test-timeout+)))
          (expect result :to-equal (process-result :stdout (write-to-string +process-test-timeout+))))))

    (it "process-boundary-forwards-an-explicit-nil-timeout-to-custom-runner"
      (with-process-boundary-runner
          (process (process-result :stdout (if timeout "bounded" "unbounded")))
        (let ((result (process-boundary-run process "demo" :timeout nil)))
          (expect result :to-equal (process-result :stdout "unbounded")))))))

(describe "recording process boundary lifecycle"
  (it "recording-process-boundary-propagates-errors-without-recording"
    (with-recording-process-runner (process (error "process failed"))
      (signals error
        (process-boundary-run process "explode"))
      (let ((calls (recording-process-calls process)))
        (expect calls :to-be-null))))

  (it "recording-process-boundary-preserves-explicit-nil-results-in-call-history"
    (with-recording-process-runner (process nil)
      (expect (process-boundary-run process "noop") :to-be-null)
      (expect (recording-process-calls process)
              :to-have-recorded-calls
              (list (process-call :command "noop"
                                  :timeout *default-process-timeout-seconds*
                                  :result nil)))))

  (it "make-recording-process-boundary-rejects-non-process-delegate"
    (signals error
      (make-recording-process-boundary :delegate :bad)))

  ;; Every other test supplies an explicit :DELEGATE; exercise the &KEY default
  ;; (a fresh MAKE-PROCESS-BOUNDARY) too.
  (it "make-recording-process-boundary-defaults-to-a-fresh-process-boundary"
    (let ((*native-process-search-path-p* t))
      (let* ((process (make-recording-process-boundary))
             (result (process-boundary-run process "sh" :arguments (list "-c" "printf hi"))))
        (expect (getf result :stdout) :to-equal "hi")
        (expect (recording-process-calls process) :to-have-length 1))))

  (it-each ((recording-process-calls)
            (reset-recording-process-calls))
      "~A signals for unsupported boundary types"
      (operation)
    (expect (lambda () (funcall operation (make-process-boundary))) :to-throw "Unsupported process boundary type"))

  (it "reset-recording-process-calls-clears-history-and-returns-the-boundary"
    (let ((process (make-test-process-boundary :results (list (process-result :stdout "ok")
                                                               (process-result :stdout "ok2")))))
      (process-boundary-run process "cmd")
      (expect (recording-process-calls process) :to-have-length 1)
      (expect (reset-recording-process-calls process) :to-be process)
      (expect (recording-process-calls process) :to-be-null)
      (process-boundary-run process "cmd2")
      (expect (recording-process-calls process) :to-have-length 1))))
