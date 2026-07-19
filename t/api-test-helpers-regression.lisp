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
     :readme-heading "### Filesystem"
     :exports ("MAKE-FILESYSTEM" "FILESYSTEM-READ-FILE" "MAKE-TEST-FILESYSTEM")
     :test-file "t/filesystem-test.lisp")
    (:label "environment"
     :readme-heading "### Environment"
     :exports ("MAKE-ENVIRONMENT" "ENVIRONMENT-GET" "MAKE-TEST-ENVIRONMENT")
     :test-file "t/env-test.lisp")
    (:label "clock"
     :readme-heading "### Clock"
     :exports ("MAKE-CLOCK" "CLOCK-NOW" "MAKE-FAKE-CLOCK")
     :test-file "t/clock-test.lisp")
    (:label "random"
     :readme-heading "### Random"
     :exports ("MAKE-RANDOM-SOURCE" "MAKE-DETERMINISTIC-RANDOM-SOURCE" "MAKE-TEST-RANDOM-SOURCE")
     :test-file "t/random-test.lisp")
    (:label "process"
     :readme-heading "### Process"
     :exports ("MAKE-PROCESS-BOUNDARY" "PROCESS-BOUNDARY-RUN" "MAKE-TEST-PROCESS-BOUNDARY")
     :test-file "t/process-test.lisp")
    (:label "network"
     :readme-heading "### Network"
     :exports ("MAKE-NETWORK-BOUNDARY" "NETWORK-BOUNDARY-REQUEST" "MAKE-TEST-NETWORK-BOUNDARY")
     :test-file "t/network-test.lisp")
    (:label "logging"
     :readme-heading "### Logging"
     :exports ("MAKE-LOGGER" "LOGGER-LOG" "MAKE-TEST-LOGGER")
     :test-file "t/logging-test.lisp")
    (:label "boundary composition"
     :readme-heading "### Composition"
     :exports ("MAKE-BOUNDARY-CONTEXT" "BOUNDARY-CONTEXT-GET" "BOUNDARY-CONTEXT-PRESENT-P")
     :test-file "t/context-test.lisp")
    (:label "recording"
     :readme-heading "### Composition"
     :exports ("MAKE-RECORDING-BOUNDARY" "RECORDING-BOUNDARY-CALLS" "RECORDING-BOUNDARY-INVOKE")
     :test-file "t/recording-test.lisp")
    (:label "testing helpers"
     :readme-heading "### Testing Helpers"
     :exports ("ASSERT-RECORDED-CALL"
               "ASSERT-RECORDED-CALL-COUNT"
               "ASSERT-RECORDED-CALL-SEQUENCE"
               "BOUNDARY-CALL-PLIST")
     :test-file "t/testing-helpers-test.lisp")))
