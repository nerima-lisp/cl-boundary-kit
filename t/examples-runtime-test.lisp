;;;; t/examples-runtime-test.lisp

(in-package #:cl-boundary-kit/test)

(eval-when (:compile-toplevel :load-toplevel :execute)
  ;; Consumed at macroexpansion time by DEFINE-EXAMPLE-OUTPUT-TESTS.
(defparameter *example-output-checks*
  '(("examples/boundary-composition.lisp"
     "clock: 7")
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
     "same-recorded: T"
     "same-forwarded: T"
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
     "same-recorded: T"
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
     "detail: native environment mutation is unavailable"))))

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
