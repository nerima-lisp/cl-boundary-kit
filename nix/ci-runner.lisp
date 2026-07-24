(require :asdf)
(require :sb-cover)

(asdf:load-system :cl-weave)
(asdf:load-system :cl-prolog)
;; The test sources use CL-PROLOG/WEAVE (deftest-queries / assert-query).  This
;; runner loads test files directly rather than via the test system's
;; :depends-on, so the subsystem's package must be loaded explicitly here.
(asdf:load-system :cl-prolog/weave)
;; LOAD-SYSTEM-SOURCES / COMPILE-INSTRUMENTED-SYSTEM below load
;; CL-BOUNDARY-KIT's own component files directly rather than through
;; ASDF:LOAD-SYSTEM, so CL-BOUNDARY-KIT's :DEPENDS-ON is never resolved for
;; them; CL-LOG-KIT (used by src/logging-kit-adapter.lisp) must be loaded
;; explicitly here for the same reason as CL-WEAVE and CL-PROLOG above.
(asdf:load-system :cl-log-kit)
;; CL-PROCESS-KIT itself depends on CL-BOUNDARY-KIT (see
;; cl-boundary-kit/process-kit's comment in cl-boundary-kit.asd), so loading
;; it here plainly loads an uninstrumented CL-BOUNDARY-KIT first; the
;; COMPILE-INSTRUMENTED-SYSTEM call below then recompiles and redefines
;; CL-BOUNDARY-KIT's own functions with coverage instrumentation, which is
;; what the coverage report measures. CL-BOUNDARY-KIT/PROCESS-KIT (the
;; adapter used by t/process-kit-adapter-test.lisp) only calls those
;; functions at runtime, so it is unaffected by which definition -- plain or
;; instrumented -- was current when it was compiled.
(asdf:load-system :cl-process-kit)
(asdf:load-system :cl-boundary-kit/process-kit)
;; The test system also depends on CL-BOUNDARY-KIT/JSON (RECORDING-CALLS-TO-JSON),
;; which pulls in CL-JSON-KIT; load both here for the same source-loading reason
;; as the systems above.
(asdf:load-system :cl-json-kit)
(asdf:load-system :cl-boundary-kit/json)

(defun system-source-files (system)
  (labels ((collect (component)
             (if (typep component 'asdf:cl-source-file)
                 (list (asdf:component-pathname component))
                 (mapcan #'collect (asdf:component-children component)))))
    (collect (asdf:find-system system))))

(defun load-system-sources (system)
  (dolist (source (system-source-files system))
    (load source)))

(defun compile-instrumented-system (system)
  (let* ((sources (system-source-files system))
         (directory (merge-pathnames "cl-boundary-kit-coverage/"
                                     (uiop:temporary-directory))))
    (ensure-directories-exist directory)
    (dolist (source sources)
      (uiop:copy-file source (merge-pathnames (file-namestring source) directory)))
    (dolist (source sources)
      (load (compile-file source
                          :output-file
                          (merge-pathnames
                           (make-pathname :name (pathname-name source)
                                          :type "fasl")
                           directory))))))

(let* ((report-path (uiop:getenv "CL_BOUNDARY_KIT_REPORT"))
       (coverage-p (uiop:getenv "CL_BOUNDARY_KIT_COVERAGE"))
       (coverage-data (uiop:getenv "CL_BOUNDARY_KIT_COVERAGE_DATA"))
       (coverage-report (uiop:getenv "CL_BOUNDARY_KIT_COVERAGE_REPORT")))
  (unless report-path
    (error "CL_BOUNDARY_KIT_REPORT is required."))
  (when coverage-p
    (proclaim '(optimize sb-cover:store-coverage-data)))
  (format *error-output* "Loading cl-boundary-kit sources.~%")
  (finish-output *error-output*)
  (if coverage-p
      (compile-instrumented-system :cl-boundary-kit)
      (load-system-sources :cl-boundary-kit))
  (format *error-output* "Loading cl-boundary-kit test sources.~%")
  (finish-output *error-output*)
  (load-system-sources :cl-boundary-kit/test)
  (format *error-output* "Running cl-weave tests.~%")
  (finish-output *error-output*)
  (ensure-directories-exist report-path)
  (let ((success-p
          (with-open-file (stream report-path
                                  :direction :output
                                  :if-exists :supersede
                                  :if-does-not-exist :create)
            (cl-weave:run-all
             :reporter :json
             :stream stream
             :name-filter (uiop:getenv "CL_WEAVE_TEST_FILTER")
             :coverage coverage-p
             ;; Keep the load-time coverage that COMPILE-INSTRUMENTED-SYSTEM
             ;; already recorded: defclass/defgeneric/defparameter forms execute
             ;; as the instrumented sources load, and resetting (cl-weave's
             ;; default) would discard that and report every definition form as
             ;; unexecuted even though loading the system runs it.
             :coverage-reset nil
             :coverage-output coverage-data
             :coverage-report-directory coverage-report
             :pass-with-no-tests nil))))
    (unless success-p
      (uiop:quit 1))))

(uiop:quit 0)
