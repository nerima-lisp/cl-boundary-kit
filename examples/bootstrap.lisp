(defun %cl-boundary-kit-runtime-loaded-p ()
  (let ((symbol (and (find-package :cl-boundary-kit)
                     (find-symbol "MAKE-BOUNDARY-CONTEXT" "CL-BOUNDARY-KIT"))))
    (and symbol (fboundp symbol))))

(defun %cl-boundary-kit-root ()
  (merge-pathnames #P"../"
                   (make-pathname :name nil
                                  :type nil
                                  :defaults (or *load-truename* *compile-file-truename*))))

;; A separate top-level form from the ASDF:LOAD-SYSTEM call below: the reader
;; interns package-qualified symbols (like ASDF:LOAD-SYSTEM) as it reads a
;; form, before any of that form is evaluated, so ASDF must already exist by
;; the time the next form is *read* -- not merely by the time it later runs.
(require :asdf)

(eval-when (:compile-toplevel :load-toplevel :execute)
  #+sbcl (setf sb-ext:*evaluator-mode* :interpret)
  (unless (%cl-boundary-kit-runtime-loaded-p)
    ;; src/logging-kit-adapter.lisp below is loaded as a raw source file, not
    ;; through cl-boundary-kit.asd, but it still needs the LOG-KIT package
    ;; from the real cl-log-kit dependency; ASDF is the one piece of that
    ;; dependency's own loading this bootstrap does not reimplement by hand.
    (asdf:load-system :cl-log-kit)
    (let ((root (%cl-boundary-kit-root)))
      (dolist (path '("src/package.lisp"
                      "src/core.lisp"
                      "src/core-utilities.lisp"
                      "src/recording-boundary.lisp"
                      "src/protocols.lisp"
                      "src/filesystem-classes.lisp"
                      "src/filesystem-delete.lisp"
                      "src/filesystem-move.lisp"
                      "src/filesystem-directory-ops.lisp"
                      "src/filesystem-fakes-entries.lisp"
                      "src/filesystem-fakes-normalize.lisp"
                      "src/filesystem-fakes-helpers.lisp"
                      "src/filesystem-fakes.lisp"
                      "src/filesystem-read.lisp"
                      "src/filesystem-directory.lisp"
                      "src/filesystem-write.lisp"
                      "src/filesystem-store-cps.lisp"
                      "src/filesystem-store.lisp"
                      "src/filesystem-make.lisp"
                      "src/filesystem-recording-constructor.lisp"
                      "src/filesystem-probe.lisp"
                      "src/filesystem-path-exists.lisp"
                      "src/env-helpers.lisp"
                      "src/env-classes.lisp"
                      "src/clock.lisp"
                      "src/random.lisp"
                      "src/uuid.lisp"
                      "src/temp-path.lisp"
                      "src/args.lisp"
                      "src/host-info.lisp"
                      "src/sleeper.lisp"
                      "src/console.lisp"
                      "src/console-methods.lisp"
                      "src/system.lisp"
                      "src/kv.lisp"
                      "src/lock.lisp"
                      "src/semaphore.lisp"
                      "src/working-directory.lisp"
                      "src/dns.lisp"
                      "src/secret.lisp"
                      "src/feature-flags.lisp"
                      "src/cache.lisp"
                      "src/rate-limiter.lisp"
                      "src/scheduler.lisp"
                      "src/process.lisp"
                      "src/process-helpers.lisp"
                      "src/process-exec-capture.lisp"
                      "src/process-exec-lifecycle.lisp"
                      "src/process-exec-helpers.lisp"
                      "src/process-boundary-constructor.lisp"
                      "src/process-test-boundary.lisp"
                      "src/process-recording-boundary.lisp"
                      "src/process-recording.lisp"
                      "src/process-request.lisp"
                      "src/network-classes.lisp"
                      "src/network-helpers.lisp"
                      "src/network-constructors.lisp"
                      "src/network-test-boundary.lisp"
                      "src/network-recording-boundary.lisp"
                      "src/network-request.lisp"
                      "src/logging.lisp"
                      "src/logging-kit-adapter.lisp"
                      "src/metrics.lisp"
                      "src/publisher.lisp"
                      "src/subscriber.lisp"
                      "src/notifier.lisp"
                      "src/testing-helpers.lisp"
                      "src/testing-queries.lisp"
                      "src/testing.lisp"
                      "src/testing-events.lisp"))
        (load (merge-pathnames path root))))))
