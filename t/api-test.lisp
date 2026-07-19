;;;; t/api-test.lisp

(in-package #:cl-boundary-kit/test)

(defparameter *expected-public-api-symbol-names*
  '("ADVANCE-FAKE-CLOCK"
    "BOUNDARY-CONTEXT-PRESENT-P"
    "BOUNDARY-CONTEXT-GET"
    "CLOCK-MONOTONIC"
    "CLOCK-NOW"
    "ENVIRONMENT-GET"
    "ENVIRONMENT-PRESENT-P"
    "ENVIRONMENT-LIST"
    "ENVIRONMENT-SET"
    "FILESYSTEM-LIST-DIRECTORY"
    "FILESYSTEM-PATH-EXISTS-P"
    "FILESYSTEM-PROBE-FILE"
    "FILESYSTEM-READ-FILE"
    "FILESYSTEM-STORE-FILE"
    "LOGGER-LOG"
    "MAKE-BOUNDARY-CONTEXT"
    "MAKE-CLOCK"
    "MAKE-DETERMINISTIC-RANDOM-SOURCE"
    "MAKE-ENVIRONMENT"
    "MAKE-FAKE-CLOCK"
    "MAKE-FILESYSTEM"
    "MAKE-LOGGER"
    "MAKE-NETWORK-BOUNDARY"
    "MAKE-PROCESS-BOUNDARY"
    "MAKE-RANDOM-SOURCE"
    "MAKE-RECORDING-BOUNDARY"
    "MAKE-RECORDING-ENVIRONMENT"
    "MAKE-RECORDING-FILESYSTEM"
    "MAKE-RECORDING-LOGGER"
    "MAKE-RECORDING-NETWORK-BOUNDARY"
    "MAKE-RECORDING-PROCESS-BOUNDARY"
    "MAKE-TEST-ENVIRONMENT"
    "MAKE-TEST-FILESYSTEM"
    "MAKE-TEST-LOGGER"
    "MAKE-TEST-NETWORK-BOUNDARY"
    "MAKE-TEST-PROCESS-BOUNDARY"
    "MAKE-TEST-RANDOM-SOURCE"
    "NETWORK-BOUNDARY-REQUEST"
    "PROCESS-BOUNDARY-RUN"
    "RANDOM-SOURCE-RANDOM"
    "ASSERT-RECORDED-CALL"
    "ASSERT-RECORDED-CALL-COUNT"
    "ASSERT-RECORDED-CALL-SEQUENCE"
    "BOUNDARY-CALL-PLIST"
    "RECORDING-BOUNDARY-CALLS"
    "RECORDING-BOUNDARY-INVOKE"
    "RECORDING-ENVIRONMENT-CALLS"
    "RECORDING-FILESYSTEM-CALLS"
    "RECORDING-LOG-EVENTS"
    "RECORDING-NETWORK-CALLS"
    "RECORDING-PROCESS-CALLS"
    "UNSUPPORTED-BOUNDARY-OPERATION"
    "UNSUPPORTED-BOUNDARY-OPERATION-DETAIL"
    "UNSUPPORTED-BOUNDARY-OPERATION-OPERATION"))

(it "public-api-is-exported-intentionally"
  (let ((actual (exported-symbol-names)))
    (assert-string-set-equal *expected-public-api-symbol-names* actual)))

(it "readme-api-overview-covers-the-exported-surface"
  (let* ((documented (mapcar #'string-upcase
                             (readme-api-overview-symbol-names)))
         (actual (exported-symbol-names)))
    (assert-string-set-equal documented actual)))

(it "exported-public-symbols-have-runtime-documentation"
  (expect (null (exported-symbol-documentation-missing-entries)) :to-be-truthy))
