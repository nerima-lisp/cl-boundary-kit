;;;; t/api-test-helpers-regression.lisp

(in-package #:cl-boundary-kit/test)

(defun asd-version-strings ()
  (let ((asd (repository-file-string "cl-boundary-kit.asd"))
        (needle ":version \""))
    (loop with start = 0
          for position = (search needle asd :start2 start)
          while position
          collect (let* ((value-start (+ position (length needle)))
                         (value-end (position #\" asd :start value-start)))
                    (setf start value-start)
                    (subseq asd value-start value-end)))))

(defun supported-release-series (version)
  (let ((parts (uiop:split-string version :separator '(#\.))))
    (unless (= 3 (length parts))
      (error "Unsupported release version format ~S" version))
    (format nil "~A.~A.x" (first parts) (second parts))))

(defun example-file-paths ()
  (remove-if (lambda (path)
               (string= "bootstrap.lisp" (file-namestring path)))
             (mapcar #'namestring
                     (sort (copy-list (directory (merge-pathnames #P"examples/*.lisp"
                                                                  (repository-root))))
                           #'string<
                           :key #'namestring))
             :key #'file-namestring))

(defun public-subsystem-regression-suites ()
  '((:label "filesystem"
     :doc-file "docs/src/filesystem-and-environment.md" :doc-heading "## Filesystem"
     :exports ("MAKE-FILESYSTEM" "FILESYSTEM-READ-FILE" "MAKE-TEST-FILESYSTEM")
     :test-file "t/filesystem-test.lisp")
    (:label "environment"
     :doc-file "docs/src/filesystem-and-environment.md" :doc-heading "## Environment"
     :exports ("MAKE-ENVIRONMENT" "ENVIRONMENT-GET" "MAKE-TEST-ENVIRONMENT")
     :test-file "t/env-test.lisp")
    (:label "clock"
     :doc-file "docs/src/time-and-randomness.md" :doc-heading "## Clock"
     :exports ("MAKE-CLOCK" "CLOCK-NOW" "MAKE-FAKE-CLOCK")
     :test-file "t/clock-test.lisp")
    (:label "random"
     :doc-file "docs/src/time-and-randomness.md" :doc-heading "## Random"
     :exports ("MAKE-RANDOM-SOURCE" "MAKE-DETERMINISTIC-RANDOM-SOURCE" "MAKE-TEST-RANDOM-SOURCE")
     :test-file "t/random-test.lisp")
    (:label "uuid"
     :doc-file "docs/src/time-and-randomness.md" :doc-heading "## UUID"
     :exports ("MAKE-UUID-SOURCE" "MAKE-SEQUENTIAL-UUID-SOURCE" "UUID-GENERATE")
     :test-file "t/uuid-test.lisp")
    (:label "temp path"
     :doc-file "docs/src/time-and-randomness.md" :doc-heading "## Temp Path"
     :exports ("MAKE-TEMP-PATH-SOURCE" "MAKE-SEQUENTIAL-TEMP-PATH-SOURCE" "TEMP-PATH-NEXT")
     :test-file "t/temp-path-test.lisp")
    (:label "command-line arguments"
     :doc-file "docs/src/system-and-host.md" :doc-heading "## Command-Line Arguments"
     :exports ("MAKE-ARGS" "MAKE-TEST-ARGS" "ARGS-LIST" "ARGS-NTH")
     :test-file "t/args-test.lisp")
    (:label "host info"
     :doc-file "docs/src/system-and-host.md" :doc-heading "## Host Info"
     :exports ("MAKE-HOST-INFO" "MAKE-TEST-HOST-INFO"
               "HOST-INFO-HOSTNAME" "HOST-INFO-PID")
     :test-file "t/host-info-test.lisp")
    (:label "sleeper"
     :doc-file "docs/src/time-and-randomness.md" :doc-heading "## Sleeper"
     :exports ("MAKE-SLEEPER" "MAKE-TEST-SLEEPER" "SLEEPER-SLEEP")
     :test-file "t/sleeper-test.lisp")
    (:label "console"
     :doc-file "docs/src/observability.md" :doc-heading "## Console"
     :exports ("MAKE-CONSOLE" "MAKE-TEST-CONSOLE" "CONSOLE-READ-LINE" "CONSOLE-WRITE-LINE")
     :test-file "t/console-test.lisp")
    (:label "process"
     :doc-file "docs/src/process-network-and-dns.md" :doc-heading "## Process"
     :exports ("MAKE-PROCESS-BOUNDARY" "PROCESS-BOUNDARY-RUN" "MAKE-TEST-PROCESS-BOUNDARY")
     :test-file "t/process-test.lisp")
    (:label "network"
     :doc-file "docs/src/process-network-and-dns.md" :doc-heading "## Network"
     :exports ("MAKE-NETWORK-BOUNDARY" "NETWORK-BOUNDARY-REQUEST" "MAKE-TEST-NETWORK-BOUNDARY")
     :test-file "t/network-test.lisp")
    (:label "system"
     :doc-file "docs/src/system-and-host.md" :doc-heading "## System"
     :exports ("MAKE-SYSTEM-BOUNDARY" "MAKE-TEST-SYSTEM-BOUNDARY" "SYSTEM-EXIT")
     :test-file "t/system-test.lisp")
    (:label "logging"
     :doc-file "docs/src/observability.md" :doc-heading "## Logging"
     :exports ("MAKE-LOGGER" "LOGGER-LOG" "MAKE-TEST-LOGGER")
     :test-file "t/logging-test.lisp")
    (:label "key/value store"
     :doc-file "docs/src/state-and-storage.md" :doc-heading "## Key/Value Store"
     :exports ("MAKE-KV-STORE" "MAKE-TEST-KV-STORE" "KV-GET" "KV-PUT")
     :test-file "t/kv-test.lisp")
    (:label "metrics"
     :doc-file "docs/src/observability.md" :doc-heading "## Metrics"
     :exports ("MAKE-METRICS" "MAKE-TEST-METRICS" "METRICS-COUNT" "METRICS-GAUGE")
     :test-file "t/metrics-test.lisp")
    (:label "lock"
     :doc-file "docs/src/concurrency-control.md" :doc-heading "## Lock"
     :exports ("MAKE-LOCK" "MAKE-TEST-LOCK" "LOCK-ACQUIRE" "LOCK-RELEASE")
     :test-file "t/lock-test.lisp")
    (:label "semaphore"
     :doc-file "docs/src/concurrency-control.md" :doc-heading "## Semaphore"
     :exports ("MAKE-SEMAPHORE" "MAKE-TEST-SEMAPHORE"
               "SEMAPHORE-ACQUIRE" "SEMAPHORE-AVAILABLE")
     :test-file "t/semaphore-test.lisp")
    (:label "working directory"
     :doc-file "docs/src/filesystem-and-environment.md" :doc-heading "## Working Directory"
     :exports ("MAKE-WORKING-DIRECTORY" "MAKE-TEST-WORKING-DIRECTORY"
               "WORKING-DIRECTORY-GET" "WORKING-DIRECTORY-SET")
     :test-file "t/working-directory-test.lisp")
    (:label "dns"
     :doc-file "docs/src/process-network-and-dns.md" :doc-heading "## DNS Resolver"
     :exports ("MAKE-DNS-RESOLVER" "MAKE-TEST-DNS-RESOLVER" "DNS-RESOLVE")
     :test-file "t/dns-test.lisp")
    (:label "secret"
     :doc-file "docs/src/state-and-storage.md" :doc-heading "## Secret Store"
     :exports ("MAKE-SECRET-STORE" "MAKE-TEST-SECRET-STORE" "SECRET-GET")
     :test-file "t/secret-test.lisp")
    (:label "feature flags"
     :doc-file "docs/src/state-and-storage.md" :doc-heading "## Feature Flags"
     :exports ("MAKE-FEATURE-FLAGS" "MAKE-TEST-FEATURE-FLAGS" "FEATURE-ENABLED-P")
     :test-file "t/feature-flags-test.lisp")
    (:label "cache"
     :doc-file "docs/src/state-and-storage.md" :doc-heading "## Cache"
     :exports ("MAKE-CACHE" "MAKE-TEST-CACHE" "CACHE-GET" "CACHE-PUT")
     :test-file "t/cache-test.lisp")
    (:label "rate limiter"
     :doc-file "docs/src/concurrency-control.md" :doc-heading "## Rate Limiter"
     :exports ("MAKE-RATE-LIMITER" "MAKE-TEST-RATE-LIMITER"
               "RATE-LIMITER-ALLOW-P" "RATE-LIMITER-AVAILABLE")
     :test-file "t/rate-limiter-test.lisp")
    (:label "scheduler"
     :doc-file "docs/src/concurrency-control.md" :doc-heading "## Scheduler"
     :exports ("MAKE-SCHEDULER" "MAKE-TEST-SCHEDULER"
               "SCHEDULER-SCHEDULE" "SCHEDULER-CANCEL")
     :test-file "t/scheduler-test.lisp")
    (:label "publisher"
     :doc-file "docs/src/messaging.md" :doc-heading "## Publisher"
     :exports ("MAKE-PUBLISHER" "MAKE-TEST-PUBLISHER" "PUBLISHER-PUBLISH")
     :test-file "t/publisher-test.lisp")
    (:label "subscriber"
     :doc-file "docs/src/messaging.md" :doc-heading "## Subscriber"
     :exports ("MAKE-SUBSCRIBER" "MAKE-TEST-SUBSCRIBER" "SUBSCRIBER-POLL")
     :test-file "t/subscriber-test.lisp")
    (:label "notifier"
     :doc-file "docs/src/messaging.md" :doc-heading "## Notifier"
     :exports ("MAKE-NOTIFIER" "MAKE-TEST-NOTIFIER" "NOTIFIER-NOTIFY")
     :test-file "t/notifier-test.lisp")
    (:label "boundary composition"
     :doc-file "docs/src/composition.md" :doc-heading "## Composition"
     :exports ("MAKE-BOUNDARY-CONTEXT" "BOUNDARY-CONTEXT-GET" "BOUNDARY-CONTEXT-PRESENT-P")
     :test-file "t/context-test.lisp")
    (:label "recording"
     :doc-file "docs/src/composition.md" :doc-heading "## Composition"
     :exports ("MAKE-RECORDING-BOUNDARY" "RECORDING-BOUNDARY-CALLS" "RECORDING-BOUNDARY-INVOKE")
     :test-file "t/recording-test.lisp")
    (:label "testing helpers"
     :doc-file "docs/src/testing-helpers.md" :doc-heading "# Assertions and Testing Helpers"
     :exports ("ASSERT-RECORDED-CALL"
               "ASSERT-RECORDED-CALL-COUNT"
               "ASSERT-RECORDED-CALL-SEQUENCE"
               "BOUNDARY-CALL-PLIST")
     :test-file "t/testing-helpers-test.lisp")))
