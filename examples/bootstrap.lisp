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

;; cl-boundary-kit.asd depends on cl-log-kit, and src/logging-kit-adapter.lisp
;; needs its LOG-KIT package. A checkout that was cloned next to its sibling
;; repositories has no reason to also have them registered with ASDF, so look
;; for them the same way run-tests.lisp does before asking ASDF to load
;; anything.
(defparameter +cl-boundary-kit-example-dependencies+ '("cl-log-kit"))

(defparameter +cl-boundary-kit-dependency-search-depth+ 4)

(defun %cl-boundary-kit-parent-directory (directory)
  (uiop:ensure-directory-pathname (truename (merge-pathnames #P"../" directory))))

(defun %cl-boundary-kit-system-directory (root system-name)
  "Return the directory of a SYSTEM-NAME.asd found one level under ROOT, if any."
  (let ((matches (directory (merge-pathnames
                             (make-pathname :directory '(:relative :wild)
                                            :name system-name
                                            :type "asd")
                             root))))
    (when matches
      (uiop:ensure-directory-pathname
       (make-pathname :name nil :type nil :defaults (truename (first matches)))))))

(defun %cl-boundary-kit-find-dependency-directory (directory system-name depth)
  (when (plusp depth)
    (let ((parent (%cl-boundary-kit-parent-directory directory)))
      (or (%cl-boundary-kit-system-directory parent system-name)
          (%cl-boundary-kit-find-dependency-directory parent system-name (1- depth))))))

(defun %cl-boundary-kit-resolvable-p (system-name)
  (and (asdf:find-system system-name nil) t))

(defun %cl-boundary-kit-dependency-directories (root)
  "Return directories that make +CL-BOUNDARY-KIT-EXAMPLE-DEPENDENCIES+ resolvable.
Dependencies ASDF can already find are skipped, so a caller that configured a
registry beforehand (Nix, run-tests.lisp, a REPL) pays nothing here -- in
particular no wildcard scan of a parent directory, which under a Nix store path
would mean globbing the whole store."
  (remove-duplicates
   (loop for dependency in +cl-boundary-kit-example-dependencies+
         unless (%cl-boundary-kit-resolvable-p dependency)
           append (let ((directory (%cl-boundary-kit-find-dependency-directory
                                    root dependency
                                    +cl-boundary-kit-dependency-search-depth+)))
                    (when directory (list directory))))
   :test #'equal))

(defun %cl-boundary-kit-configure-source-registry (directories)
  "Add DIRECTORIES to ASDF's source registry without discarding existing configuration.
Uses :INHERIT-CONFIGURATION rather than mutating CL_SOURCE_REGISTRY so that a
caller that already configured ASDF (run-tests.lisp, a REPL, or Nix) keeps its
own entries and stays authoritative on conflicts."
  (asdf:initialize-source-registry
   `(:source-registry
     ,@(mapcar (lambda (directory) (list :directory directory)) directories)
     :inherit-configuration)))

(defun %cl-boundary-kit-report-missing-dependency (condition)
  "Re-signal CONDITION with the one thing the ASDF message does not say: what to do.
A checkout cloned on its own has no sibling cl-log-kit to find, and ASDF's
`Component :CL-LOG-KIT not found' gives no hint that running the example needs
one more checkout or a source registry."
  (error "~A~2%~
          cl-boundary-kit depends on cl-log-kit, which is not in ASDF's source ~
          registry.~%~
          examples/bootstrap.lisp looks for it in a sibling directory of this ~
          checkout (../cl-log-kit/ and up to ~D levels above), so either:~%~
          ~2T- clone https://github.com/nerima-lisp/cl-log-kit next to this ~
          checkout, or~%~
          ~2T- point CL_SOURCE_REGISTRY at an existing checkout, or~%~
          ~2T- run the examples through the pinned Nix environment: nix run .#test~%"
         condition +cl-boundary-kit-dependency-search-depth+))

(eval-when (:compile-toplevel :load-toplevel :execute)
  (unless (%cl-boundary-kit-runtime-loaded-p)
    (let* ((root (%cl-boundary-kit-root))
           (dependencies (%cl-boundary-kit-dependency-directories root)))
      ;; This checkout goes on *CENTRAL-REGISTRY*, not into the source-registry
      ;; form below, because SYSDEF-CENTRAL-REGISTRY-SEARCH runs ahead of
      ;; SYSDEF-SOURCE-REGISTRY-SEARCH. The dependency search returns whichever
      ;; directory happens to hold a matching .asd, and if that directory also
      ;; carries a cl-boundary-kit.asd -- a vendored tree, a scratch copy --
      ;; registering it could otherwise shadow the very checkout the example
      ;; was started from. The example must run against its own sources.
      (pushnew root asdf:*central-registry* :test #'equal)
      (when dependencies
        (%cl-boundary-kit-configure-source-registry dependencies)))
    (handler-case (asdf:load-system :cl-boundary-kit)
      (asdf:missing-component (condition)
        (%cl-boundary-kit-report-missing-dependency condition)))))
