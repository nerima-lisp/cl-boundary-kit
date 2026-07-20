;;;; t/examples-runtime-test.lisp

(in-package #:cl-boundary-kit/test)

(eval-when (:compile-toplevel :load-toplevel :execute)
  ;; Consumed at macroexpansion time by DEFINE-EXAMPLE-OUTPUT-TESTS.
(defparameter *example-output-checks*
  '(("examples/boundary-composition.lisp"
     "clock: 7")
    ("examples/application-composition.lisp"
     "hits-a: 2"
     "hits-b: 1"
     "request-metrics: 3"
     "log-count: 3"
     "context-keys: 5")
    ("examples/deterministic-random.lisp"
     "sequence-a:"
     "sequence-b:"
     "same-sequence: T")
    ("examples/fake-clock.lisp"
     "before: 100"
     "after: 110")
    ("examples/recording-boundary.lisp"
     "result: (:OPERATION :PING :ARGUMENTS (1 2) :STATUS :OK)"
     ":OPERATION :PING")
    ("examples/recording-environment.lisp"
     "PATH: /usr/bin"
     "EMPTY: NIL"
     ":OPERATION :GET")
    ("examples/recording-filesystem.lisp"
     "result: T"
     ":OPERATION :WRITE-FILE"
     ":EXTERNAL-FORMAT :UTF-8")
    ("examples/recording-logger.lisp"
     "equal-recorded: T"
     "independent-recorded: T"
     "equal-forwarded: T"
     "independent-forwarded: T"
     "forwarded: ((:TIMESTAMP 42 :LEVEL :INFO :MESSAGE \"example\" :FIELDS"
     "(:USER \"take\")))"
     "events: ((:TIMESTAMP 42 :LEVEL :INFO :MESSAGE \"example\" :FIELDS (:USER \"take\")))")
    ("examples/recording-network.lisp"
     "response: (:STATUS 204)"
     ":REQUEST (:METHOD :GET :URL \"https://example.test\")"
     ":TIMEOUT 5")
    ("examples/recording-process.lisp"
     "result: (:COMMAND (\"demo\" \"--mode\" \"arg\") :STDOUT \"ok\" :STDERR \"\" :EXIT-CODE 0)"
     ":COMMAND (\"demo\" \"--mode\")")
    ("examples/test-environment.lisp"
     "PATH: /usr/bin"
     "EMPTY: NIL"
     "MISSING?: NIL"
     "HOME: /tmp/home"
     "entries: ((\"EMPTY\") (\"HOME\" . \"/tmp/home\") (\"PATH\" . \"/usr/bin\"))"
     ":OPERATION :SET")
    ("examples/test-filesystem.lisp"
     "before: \"hello\""
     "after: \"hello world\""
     ":OPERATION :WRITE-FILE")
    ("examples/test-logger.lisp"
     "equal-recorded: T"
     "independent-recorded: T"
     "events: ((:TIMESTAMP 101 :LEVEL :WARN :MESSAGE \"test-only\""
     "(:REQUEST-ID \"req-9\")))")
    ("examples/test-network.lisp"
     "first: (:STATUS 200 :BODY \"ok\")"
     "second: (:STATUS 429 :BODY \"slow down\")"
     ":REQUEST (:METHOD :POST :URL \"https://example.test/jobs\")")
    ("examples/test-process.lisp"
     "first: (:STDOUT \"ok\" :STDERR \"\" :EXIT-CODE 0)"
     "second: (:STDOUT \"warn\" :STDERR \"note\" :EXIT-CODE 1)"
     ":COMMAND \"demo-2\"")
    ("examples/test-random.lisp"
     "first: 7"
     "second: 2"
     "third: 0.5d0")
    ("examples/unsupported-operation.lisp"
     "operation: CL-BOUNDARY-KIT:ENVIRONMENT-SET"
     "detail: native environment mutation is unavailable")
    ("examples/sequential-uuid.lisp"
     "first: req-0000000000000000"
     "second: req-0000000000000001"
     "reproducible: T")
    ("examples/recording-uuid.lisp"
     "first: id-1"
     "second: id-2"
     ":OPERATION :GENERATE"
     ":RESULT \"id-1\"")
    ("examples/sequential-temp-path.lisp"
     "first: /tmp/job-00000000.tmp"
     "second: /tmp/job-00000001.tmp")
    ("examples/test-args.lisp"
     "count: 3"
     "first: app"
     "list: (\"app\" \"--verbose\" \"input.txt\")")
    ("examples/test-host-info.lisp"
     "hostname: build-01"
     "username: ci"
     "pid: 4242")
    ("examples/recording-sleeper.lisp"
     "slept: 5"
     "slept: 0.25"
     ":OPERATION :SLEEP"
     ":ARGUMENTS (5)")
    ("examples/test-console.lisp"
     "first-input: alice"
     "at-eof: NIL"
     "output: (\"hello, alice\")"
     "errors: (\"second line missing\")")
    ("examples/test-system.lisp"
     "default-code: 0"
     "explicit-code: 2"
     "exit-codes: (0 2)")
    ("examples/test-kv-store.lisp"
     "alpha: 1"
     "missing: DEFAULT present: NIL"
     "deleted-beta: T"
     "keys: (\"alpha\")")
    ("examples/test-metrics.lisp"
     "(:TYPE :COUNT :NAME \"requests\" :VALUE 1)"
     "(:TYPE :GAUGE :NAME \"queue-depth\" :VALUE 7)"
     "(:TYPE :TIMING :NAME \"request-ms\" :VALUE 42)")
    ("examples/recording-lock.lisp"
     "held: T"
     "released: NIL"
     ":OPERATION :ACQUIRE"
     ":OPERATION :RELEASE")
    ("examples/test-semaphore.lisp"
     "start: 2"
     "drained: 0"
     "after-release: 1")
    ("examples/test-working-directory.lisp"
     "before: /home/take/"
     "after: /tmp/work/")
    ("examples/test-dns.lisp"
     "addresses: (\"192.0.2.1\" \"192.0.2.2\")"
     "unknown-signals: T")
    ("examples/recording-secret.lisp"
     "value: s3cr3t"
     ":OPERATION :GET"
     ":RESULT :REDACTED")
    ("examples/test-feature-flags.lisp"
     "new-checkout: T"
     "legacy-flow: NIL")
    ("examples/test-cache.lisp"
     "before: active"
     "after-expiry: EXPIRED")
    ("examples/test-rate-limiter.lisp"
     "first: T"
     "throttled: NIL"
     "after-refill: T")
    ("examples/test-scheduler.lisp"
     "pending: ((:ID 1 :DELAY 5) (:ID 2 :DELAY 10))"
     "results: (:FIRST :SECOND)"
     "drained: NIL")
    ("examples/test-publisher.lisp"
     "(:TOPIC \"orders\" :MESSAGE \"created:42\")"
     "(:TOPIC \"orders\" :MESSAGE \"shipped:42\")")
    ("examples/test-subscriber.lisp"
     "first: job-1"
     "second: job-2"
     "drained: NIL")
    ("examples/test-notifier.lisp"
     "(:RECIPIENT \"ops@example.test\" :SUBJECT \"Deploy\" :BODY"
     "\"Build 42 shipped\")"))))

(defun example-output-check-paths ()
  (sort (mapcar #'car (copy-list *example-output-checks*)) #'string<))

(eval-when (:compile-toplevel :load-toplevel :execute)
  ;; Called at macroexpansion time by DEFINE-EXAMPLE-OUTPUT-TESTS.
  (defun example-test-symbol (path)
    ;; cl-weave's IT evaluates its name argument, so return a literal string
    ;; label rather than an interned symbol.
    (string-downcase
     (concatenate 'string
                  (substitute #\- #\_
                              (pathname-name path))
                  "-EXAMPLE-MATCHES-README-CONTRACT"))))

(defmacro define-example-output-tests (checks)
  (let ((resolved-checks (if (and (symbolp checks) (boundp checks))
                             (symbol-value checks)
                             checks)))
    `(progn
       ,@(loop for spec in resolved-checks
               collect
               (let ((path (car spec))
                     (needles (cdr spec)))
                 `(it ,(example-test-symbol path)
                     (let ((output (%run-example (example-path-name ,path))))
                       ,@(loop for needle in needles
                               collect `(expect (not (null (search ,needle output))) :to-be-truthy)))))))))

(define-example-output-tests *example-output-checks*)

(it "documented-examples-have-output-checks"
  (let ((documented (readme-example-paths))
        (covered (example-output-check-paths)))
    (expect (null (set-difference documented covered :test #'string=)) :to-be-truthy)
    (expect (null (set-difference covered documented :test #'string=)) :to-be-truthy)))

(it "examples-load-without-errors"
  (dolist (path (readme-example-paths))
    (%run-example (example-path-name path)))
  t)

(it "examples-run-in-fresh-sbcl-processes"
  (dolist (path (readme-example-paths))
    (multiple-value-bind (stdout stderr exit-code)
        (run-example-in-fresh-sbcl path)
      (declare (ignore stdout))
      (expect (zerop exit-code) :to-be-truthy)
      (expect (null (search "ERROR" stderr)) :to-be-truthy))))
