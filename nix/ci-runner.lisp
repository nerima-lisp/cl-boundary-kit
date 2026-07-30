(require :asdf)

(require :sb-cover)

;; The test sources use CL-PROLOG/WEAVE (deftest-queries / assert-query).  This
;; runner loads test files directly rather than via the test system's
;; :depends-on, so the subsystem's package must be loaded explicitly here.
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
       (coverage-manifest (uiop:getenv "CL_BOUNDARY_KIT_COVERAGE_MANIFEST")))
  (unless report-path
    (error "CL_BOUNDARY_KIT_REPORT is required."))
  (when coverage-p
    (unless coverage-manifest
      (error "CL_BOUNDARY_KIT_COVERAGE_MANIFEST is required for coverage runs."))
    (proclaim (quote (optimize sb-cover:store-coverage-data)))
    (sb-cover:reset-coverage))
  (format *error-output* "Loading cl-boundary-kit sources.~%")
  (finish-output *error-output*)
  (if coverage-p
      (progn
        (asdf:load-system :cl-prolog/weave)
        (write-system-source-manifest :cl-boundary-kit coverage-manifest)
        (asdf:load-system :cl-boundary-kit :force t)
        (format *error-output* "Loading cl-boundary-kit test sources.~%")
        (finish-output *error-output*)
        (load-system-sources :cl-boundary-kit/test))
      (asdf:load-system :cl-boundary-kit/test))
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
            (cl-weave:run-all
             :reporter
             :json
             :stream
             stream
             :name-filter
             (uiop:getenv "CL_WEAVE_TEST_FILTER")
             :max-workers
             (and coverage-p 1)
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
