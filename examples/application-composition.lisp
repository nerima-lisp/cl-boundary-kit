;;;; examples/application-composition.lisp
;;;;
;;;; A tiny "request handler" composed from several boundaries wired into one
;;;; boundary context, driven deterministically. It shows uuid, key/value store,
;;;; logging, metrics, clock, and context composition working together, plus an
;;;; event testing helper inspecting the captured metrics.

(load (merge-pathnames #P"bootstrap.lisp"
                       (make-pathname :name nil
                                      :type nil
                                      :defaults (or *load-truename* *compile-file-truename*))))

(let* ((clock (cl-boundary-kit:make-fake-clock :start 1000))
       (ids (cl-boundary-kit:make-sequential-uuid-source :prefix "req"))
       (store (cl-boundary-kit:make-test-kv-store))
       (logger (cl-boundary-kit:make-test-logger
                :timestamp-fn (lambda () (cl-boundary-kit:clock-now clock))))
       (metrics (cl-boundary-kit:make-test-metrics))
       (context (cl-boundary-kit:make-boundary-context
                 :clock clock :ids ids :store store
                 :logger logger :metrics metrics)))
  (flet ((handle (path)
           (let ((ids (cl-boundary-kit:boundary-context-get context :ids))
                 (store (cl-boundary-kit:boundary-context-get context :store))
                 (logger (cl-boundary-kit:boundary-context-get context :logger))
                 (metrics (cl-boundary-kit:boundary-context-get context :metrics)))
             (let ((id (cl-boundary-kit:uuid-generate ids)))
               (cl-boundary-kit:logger-info logger "handling" :id id :path path)
               (cl-boundary-kit:kv-increment store path)
               (cl-boundary-kit:metrics-increment metrics "requests")
               id))))
    (handle "/a")
    (handle "/a")
    (handle "/b")
    (format t "~&hits-a: ~A~%" (cl-boundary-kit:kv-get store "/a"))
    (format t "~&hits-b: ~A~%" (cl-boundary-kit:kv-get store "/b"))
    (format t "~&request-metrics: ~A~%"
            (cl-boundary-kit:count-events (cl-boundary-kit:recording-metric-events metrics)
                                          :name "requests"))
    (format t "~&log-count: ~A~%" (length (cl-boundary-kit:recording-log-events logger)))
    (format t "~&context-keys: ~A~%" (cl-boundary-kit:boundary-context-count context))))
