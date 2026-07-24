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

(defun local-asdf-directories (root)
  (labels ((find-first-dependency-directory (directory system-name remaining-depth)
             (when (plusp remaining-depth)
               (let* ((parent (parent-directory directory))
                      (matches (asdf-system-directories-under parent system-name)))
                 (or (first matches)
                     (find-first-dependency-directory parent system-name (1- remaining-depth)))))))
    (remove-duplicates
     (cons root
           (loop for dependency in +local-test-dependencies+
                 for dependency-directory = (find-first-dependency-directory root dependency 4)
                 when dependency-directory
                   collect dependency-directory))
     :test #'equal)))

(defun source-registry-entry (directory)
  (format nil "~A//" (namestring directory)))

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
