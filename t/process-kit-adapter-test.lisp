;;;; t/process-kit-adapter-test.lisp

(in-package #:cl-boundary-kit/test)

(defmacro with-process-kit-boundary ((name) &body body)
  `(let ((,name (make-process-boundary :run-fn #'process-kit-run-fn)))
     ,@body))

(it "process-kit-run-fn-runs-a-command-and-captures-stdout"
  (let ((*native-process-search-path-p* t))
    (with-process-kit-boundary (process)
      (let ((result (process-boundary-run process "sh" :arguments (list "-c" "printf hi"))))
        (expect (string= (getf result :stdout) "hi") :to-be-truthy)
        (expect (= (getf result :exit-code) 0) :to-be-truthy)
        (expect (null (getf result :timed-out)) :to-be-truthy)))))

(it "process-kit-run-fn-captures-a-non-zero-exit-code-and-stderr"
  (let ((*native-process-search-path-p* t))
    (with-process-kit-boundary (process)
      (let ((result (process-boundary-run
                     process "sh"
                     :arguments (list "-c" "printf err 1>&2; exit 3"))))
        (expect (string= (getf result :stderr) "err") :to-be-truthy)
        (expect (= (getf result :exit-code) 3) :to-be-truthy)))))

(it "process-kit-run-fn-forwards-input-to-the-child"
  (let ((*native-process-search-path-p* t))
    (with-process-kit-boundary (process)
      (let ((result (process-boundary-run process "cat" :input "from stdin")))
        (expect (string= (getf result :stdout) "from stdin") :to-be-truthy)))))

;;; Exercises the same real deadline/kill path as
;;; NATIVE-PROCESS-RUN-TERMINATES-AND-FLAGS-A-TIMED-OUT-SUBPROCESS in
;;; process-test.lisp, but through PROCESS-KIT-RUN-FN's cl-process-kit
;;; backend: a subprocess that outlives its timeout is escalated
;;; SIGTERM -> SIGKILL and the result flags the timeout instead of
;;; masquerading as a normal exit. Uses the running SBCL as the subprocess
;;; so the test needs no external command on PATH.
(it "process-kit-run-fn-terminates-and-flags-a-timed-out-subprocess"
  (with-process-kit-boundary (process)
    (let* ((runtime (namestring sb-ext:*runtime-pathname*))
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
      (expect (< elapsed-seconds 10) :to-be-truthy))))
