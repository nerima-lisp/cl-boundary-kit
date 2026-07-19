;;;; run-tests.lisp

(require :asdf)

(defun script-directory ()
  (make-pathname :name nil
                 :type nil
                 :defaults (or *load-truename*
                               *compile-file-truename*
                               (error "Unable to determine the script location"))))

(let* ((root (script-directory))
       (asd-file (merge-pathnames "cl-boundary-kit.asd" root)))
  (asdf:load-asd asd-file)
  (pushnew root asdf:*central-registry* :test #'equal)
  (asdf:load-system "cl-boundary-kit/test")
  (unless (funcall (symbol-function
                    (find-symbol "RUN-TESTS" "CL-BOUNDARY-KIT/TEST")))
    (uiop:quit 1))
  (uiop:quit 0))
