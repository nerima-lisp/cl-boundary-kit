;;;; examples/bootstrap.lisp
;;;;
;;;; Loaded by every examples/*.lisp file so that `sbcl --script
;;;; examples/<name>.lisp` works from a bare checkout: no Quicklisp, no
;;;; preconfigured CL_SOURCE_REGISTRY, and no ASDF registration step performed
;;;; by the caller.
;;;;
;;;; The system is loaded through cl-boundary-kit.asd rather than by loading
;;;; src/*.lisp by hand, so the component list stays in exactly one place and
;;;; examples pick up ASDF's compiled-fasl cache instead of re-reading the
;;;; whole tree as interpreted source on every run.

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
  (unless (%cl-boundary-kit-runtime-loaded-p)
    ;; Keep this checkout ahead of any same-named system a caller may have
    ;; registered, so examples always load their local sources.
    (pushnew (%cl-boundary-kit-root) asdf:*central-registry* :test #'equal)
    (asdf:load-system :cl-boundary-kit)))
