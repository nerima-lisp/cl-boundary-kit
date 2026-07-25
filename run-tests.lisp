;;;; run-tests.lisp

(require :asdf)

(defun script-directory ()
  (make-pathname :name nil
                 :type nil
                 :defaults (or *load-truename*
                               *compile-file-truename*
                               (error "Unable to determine the script location"))))

(defparameter +local-test-dependencies+ '("cl-prolog" "cl-weave" "cl-log-kit" "cl-process-kit" "cl-json-kit"))

(defun parent-directory (directory)
  (uiop:ensure-directory-pathname (truename (merge-pathnames "../" directory))))

(defun system-asdf-wildcard (root system-name)
  (merge-pathnames
   (make-pathname :directory '(:relative :wild)
                  :name system-name
                  :type "asd")
   root))

(defun asdf-system-directories-under (root system-name)
  (loop for asd-file in (directory (system-asdf-wildcard root system-name))
        collect (uiop:ensure-directory-pathname
                 (make-pathname :name nil
                                :type nil
                                :defaults (truename asd-file)))))

(defun system-already-resolvable-p (system-name)
  (and (asdf:find-system system-name nil) t))

(defun local-asdf-directories (root)
  "Return ROOT plus a directory for each test dependency ASDF cannot already find.

Dependencies that already resolve are skipped rather than searched for. The
search walks up to four parent directories and globs `*/<system>.asd' under
each, which is cheap next to a handful of sibling checkouts and ruinous
anywhere else: run from a Nix store path, the first parent is /nix/store, where
one such glob takes minutes and matches every version of the dependency ever
built on the machine -- of which FIND-FIRST-DEPENDENCY-DIRECTORY would then
pick an arbitrary one. Every caller that runs from a store path (the flake's
checks and apps) sets CL_SOURCE_REGISTRY first, so for them this now costs
nothing and cannot bind a stray copy."
  (labels ((find-first-dependency-directory (directory system-name remaining-depth)
             (when (plusp remaining-depth)
               (let* ((parent (parent-directory directory))
                      (matches (asdf-system-directories-under parent system-name)))
                 (or (first matches)
                     (find-first-dependency-directory parent system-name (1- remaining-depth)))))))
    (remove-duplicates
     (cons root
           (loop for dependency in +local-test-dependencies+
                 unless (system-already-resolvable-p dependency)
                   append (let ((directory (find-first-dependency-directory root dependency 4)))
                            (when directory (list directory)))))
     :test #'equal)))

(defun source-registry-entry (directory)
  "Return a non-recursive CL_SOURCE_REGISTRY entry for DIRECTORY.

DIRECTORY always names the directory that directly contains a .asd file --
LOCAL-ASDF-DIRECTORIES derives each one from the .asd file it found -- so a
recursive `//' entry would only add work. It is not free: this registry is
exported to the environment and therefore inherited by every SBCL subprocess
the suite starts, including one per examples/*.lisp file, and each of those
would re-walk every checkout in full (.git directories included) before
finding a system that sits at the top level. Keeping the entries
non-recursive takes a fresh example process from ~7s to ~0.2s."
  (namestring directory))

(defun configure-local-source-registry (directories)
  (let* ((local-registry (format nil "~{~A~^:~}"
                                 (mapcar #'source-registry-entry directories)))
         (existing-registry (uiop:getenv "CL_SOURCE_REGISTRY"))
         (source-registry (if (and existing-registry
                                   (plusp (length existing-registry)))
                              (format nil "~A:~A"
                                      local-registry
                                      existing-registry)
                              local-registry)))
    (setf (uiop:getenv "CL_SOURCE_REGISTRY") source-registry)
    (asdf:initialize-source-registry)
    source-registry))

(let* ((root (script-directory))
       (asd-file (merge-pathnames "cl-boundary-kit.asd" root))
       (local-directories (local-asdf-directories root)))
  (configure-local-source-registry local-directories)
  (asdf:load-asd asd-file)
  (dolist (directory local-directories)
    (pushnew directory asdf:*central-registry* :test #'equal))
  (asdf:load-system "cl-boundary-kit/test")
  (unless (funcall (symbol-function
                    (find-symbol "RUN-TESTS" "CL-BOUNDARY-KIT/TEST")))
    (uiop:quit 1))
  (uiop:quit 0))
