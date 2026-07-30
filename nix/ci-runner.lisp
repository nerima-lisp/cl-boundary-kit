(require :asdf)

;; CL-WEAVE:RUN-ALL is called directly below regardless of COVERAGE-P, and the
;; coverage branch loads CL-BOUNDARY-KIT/TEST's sources with LOAD rather than
;; ASDF:LOAD-SYSTEM, so ASDF's own dependency resolution never runs for it;
;; load CL-WEAVE explicitly so its package exists either way.
(asdf:load-system :cl-weave)

;; Tests use CL-PROLOG/WEAVE (deftest-queries / assert-query).  Load test
;; systems interpreted so SBCL does not enter its Darwin compiler-worker stall.
(defun system-source-files (system)
  (labels ((collect (component)
             (if (typep component 'asdf:cl-source-file) (list (asdf:component-pathname component))
          (mapcan #'collect (asdf:component-children component)))))
    (collect (asdf:find-system system))))

(defun load-system-sources (system)
  (dolist (source (system-source-files system))
    (load source)))

(defun write-system-source-manifest (system manifest-path)
  (with-open-file (stream
      manifest-path
      :direction
      :output
      :if-exists
      :supersede
      :if-does-not-exist
      :create)
    (dolist (source (system-source-files system))
      (format stream "~A~%" (file-namestring source)))))

(let* ((report-path (uiop:getenv "CL_BOUNDARY_KIT_REPORT"))
       (coverage-p (uiop:getenv "CL_BOUNDARY_KIT_COVERAGE"))
       (coverage-data (uiop:getenv "CL_BOUNDARY_KIT_COVERAGE_DATA"))
       (coverage-report (uiop:getenv "CL_BOUNDARY_KIT_COVERAGE_REPORT"))
       (coverage-manifest (uiop:getenv "CL_BOUNDARY_KIT_COVERAGE_MANIFEST"))
       (test-filter (uiop:getenv "CL_WEAVE_TEST_FILTER")))
  (unless report-path
    (error "CL_BOUNDARY_KIT_REPORT is required."))
  ;; Load CL-PROLOG/WEAVE before coverage instrumentation is proclaimed below:
  ;; SB-COVER:STORE-COVERAGE-DATA is a global optimize quality, so compiling a
  ;; dependency while it is active would instrument that dependency's own
  ;; sources too. CL-PROLOG's SRC/BUILTINS/CORE.LISP would then collide on
  ;; basename with this system's own SRC/CORE.LISP in the coverage report,
  ;; which check-coverage.pl cannot disambiguate (SB-COVER's HTML reports
  ;; only carry basenames, not full paths).
  (asdf:load-system :cl-prolog/weave)
  (when coverage-p
    (unless coverage-manifest
      (error "CL_BOUNDARY_KIT_COVERAGE_MANIFEST is required for coverage runs."))
    (require :sb-cover)
    (proclaim (read-from-string "(optimize sb-cover:store-coverage-data)"))
    (funcall (read-from-string "sb-cover:reset-coverage")))
  (format *error-output* "Loading cl-boundary-kit sources.~%")
  (finish-output *error-output*)
  (if coverage-p
      (progn
        (write-system-source-manifest :cl-boundary-kit coverage-manifest)
        ;; Coverage instrumentation is a compile-time property: only code
        ;; compiled while SB-COVER:STORE-COVERAGE-DATA is proclaimed records
        ;; hits. The build phase already compiled CL-BOUNDARY-KIT's FASLs
        ;; without that proclamation, so :FORCE T is required here -- without
        ;; it ASDF finds those FASLs current and loads them unrecompiled,
        ;; producing an empty report. This is the same pattern cl-nix-forge's
        ;; batteries/coverage.nix mkCoverageReport uses.
        (asdf:load-system :cl-boundary-kit :force t))
      (asdf:load-system :cl-boundary-kit))
  (format *error-output* "Loading cl-boundary-kit test sources.~%")
  (finish-output *error-output*)
  ;; SB-COVER instrumentation is recorded per compiled form. Loading test
  ;; sources interpreted (as the non-coverage path does, to dodge SBCL's
  ;; Darwin compiler-worker stall) leaves nearly every call site inside them
  ;; unattributed, so a coverage run compiles them normally instead; the
  ;; stall has not reproduced under coverage's :force t recompile of
  ;; CL-BOUNDARY-KIT itself, which is a comparably large compile.
  (let ((sb-ext:*evaluator-mode* (if coverage-p :compile :interpret)))
    (format
      *error-output*
      "Loading cl-boundary-kit base test sources in interpreter mode.~%")
    (finish-output *error-output*)
    (load-system-sources :cl-boundary-kit/test-base)
    (format *error-output* "Loading cl-prolog weave test support.~%")
    (finish-output *error-output*)
    (asdf:load-system :cl-prolog/weave)
    (format
      *error-output*
      "Loading cl-boundary-kit Prolog test sources in interpreter mode.~%")
    (finish-output *error-output*)
    (load-system-sources :cl-boundary-kit/test-prolog))
  (format *error-output* "Running cl-weave tests.~%")
  (finish-output *error-output*)
  (ensure-directories-exist report-path)
  (let ((success-p
        (with-open-file (stream
            report-path
            :direction
            :output
            :if-exists
            :supersede
            :if-does-not-exist
            :create)
          (uiop:symbol-call
            :cl-weave
            :run-all
            :reporter
            :json
            :stream
            stream
            :name-filter
            test-filter
            :max-workers
            1
            :timeout-ms
            30000
            :coverage
            coverage-p
            :coverage-reset
            nil
            :coverage-output
            coverage-data
            :coverage-report-directory
            coverage-report
            :pass-with-no-tests
            nil))))
    (unless success-p
      (uiop:quit 1)))
  (uiop:quit 0))
