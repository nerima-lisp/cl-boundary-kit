(in-package #:cl-boundary-kit)

(defmacro %with-environment ((environment) &body body)
  `(let ((,environment (require-instance ,environment 'env-boundary "ENVIRONMENT")))
     ,@body))

(defmacro %recorded ((environment operation arguments) &body body)
  `(let ((result (progn ,@body)))
     (%record-call (%environment-calls ,environment)
       :operation ,operation
       :arguments ,arguments
       :result result)
     result))

(defmacro %with-environment-call ((environment operation arguments) recording-body &body body)
  `(cond
     ((%recording-environment-p ,environment)
      (%recorded (,environment ,operation ,arguments)
        ,recording-body))
     (t
      (let ((result (progn ,@body)))
        (if (%test-environment-p ,environment)
            (%recorded (,environment ,operation ,arguments) result)
            result)))))

(defmacro %define-recording-environment-operation (name lambda-list operation arguments recording-form direct-form &optional docstring)
  `(defun ,name ,lambda-list
     ,@(when docstring (list docstring))
     (%with-environment (environment)
       (%with-environment-call (environment ,operation ,arguments)
           ,recording-form
         ,direct-form))))

(defmacro %define-plist-constructor (name docstring implementation)
  `(defun ,name (&rest options)
     ,docstring
     (,implementation options)))

(defun %make-env-boundary (&key kind get-fn set-fn list-fn delegate)
  (make-instance 'env-boundary
                 :kind kind
                 :get-fn get-fn
                 :set-fn set-fn
                 :list-fn list-fn
                 :delegate delegate))

(defun %sorted-environment-entries (entries)
  (sort (copy-list entries) #'string< :key #'car))

(defun %split-environment-entry-cps (entry kont)
  (let ((separator (position #\= entry)))
    (if separator
        (funcall kont
                 (cons (subseq entry 0 separator)
                       (subseq entry (1+ separator))))
        (funcall kont (cons entry "")))))

(defun %native-environment-get (name)
  #+sbcl
  (sb-ext:posix-getenv name)
  #-sbcl
  (declare (ignore name))
  #-sbcl
  nil)

(defun %native-environment-entries ()
  #+sbcl
  (sb-ext:posix-environ)
  #-sbcl
  nil)

(defun %native-environment-list ()
  (let ((entries nil))
    (dolist (entry (%native-environment-entries)
             (%sorted-environment-entries (nreverse entries)))
      (%split-environment-entry-cps
       entry
       (lambda (binding)
         (push binding entries))))))

(defun %plist-ref-values (plist key default)
  (loop for rest on plist by #'cddr
        do (cond
             ((null rest)
              (return (values default nil)))
             ((null (cdr rest))
              (error "Option list ended after ~S." (car rest)))
             ((eq (car rest) key)
              (return (values (cadr rest) t))))
        finally (return (values default nil))))

(defun %normalize-environment-values-cps (initial-values kont)
  (cond
    ((null initial-values)
     (funcall kont nil))
    ((every #'consp initial-values)
     (funcall kont initial-values))
    (t
     (let ((entries nil))
       (loop for rest on initial-values by #'cddr
             do (when (null (cdr rest))
                  (error "INITIAL-VALUES must be an alist or plist: ~S" initial-values))
             do (push (cons (car rest) (cadr rest)) entries))
       (funcall kont (nreverse entries))))))

(defun %environment-entry-cell (entries name)
  (assoc name entries :test #'equal))

(defun %upsert-environment-entry (entries name value)
  (let ((cell (%environment-entry-cell entries name)))
    (if cell
        (progn
          (setf (cdr cell) value)
          entries)
        (acons name value entries))))

(defun %seed-environment-bindings-cps (initial-values kont)
  (%normalize-environment-values-cps
   initial-values
   (lambda (bindings)
     (let ((entries nil))
       (dolist (binding bindings)
         (setf entries
               (%upsert-environment-entry entries (car binding) (cdr binding))))
       (funcall kont entries)))))

(defun %environment-values (getter name)
  (multiple-value-list (funcall getter name)))

(defun %environment-value-from-call (values default)
  (cond
    ((null values) default)
    ((cdr values)
     (if (second values)
         (first values)
         default))
    ((null (first values)) default)
    (t (first values))))

(defun %environment-presence-from-call (values)
  (cond
    ((null values) nil)
    ((cdr values) (second values))
    (t (not (null (first values))))))

(defun %test-environment-p (environment)
  (eq (environment-kind environment) :test))

(defun %recording-environment-p (environment)
  (eq (environment-kind environment) :recording))
