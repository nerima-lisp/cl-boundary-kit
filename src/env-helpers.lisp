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

(defmacro %with-environment-call ((environment operation arguments) &body body)
  ;; :TEST and :RECORDING environments both record onto their OWN calls slot
  ;; around the same BODY, which always reads ENVIRONMENT's own (possibly
  ;; delegate-copied, but never itself self-recording) collaborator
  ;; functions -- never a delegate's public ENVIRONMENT-GET/-SET/-LIST,
  ;; which would re-enter the delegate's own recording path and double-count
  ;; the call.
  `(if (or (%recording-environment-p ,environment) (%test-environment-p ,environment))
       (%recorded (,environment ,operation ,arguments)
         ,@body)
       (progn ,@body)))

(defmacro %define-recording-environment-operation (name lambda-list operation arguments direct-form &optional docstring)
  `(defun ,name ,lambda-list
     ,@(when docstring (list docstring))
     (%with-environment (environment)
       (%with-environment-call (environment ,operation ,arguments)
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

(defun %sorted-environment-entries-from-table (table)
  (let ((entries nil))
    (maphash (lambda (name value) (push (cons name value) entries)) table)
    (%sorted-environment-entries entries)))

(defun %seed-environment-bindings-cps (initial-values kont)
  ;; A hash table gives O(1) get/set/seed regardless of how many bindings a
  ;; test environment carries, instead of an alist's O(n) ASSOC scan per
  ;; lookup and O(n^2) cost to seed N initial bindings one upsert at a time.
  (%normalize-environment-values-cps
   initial-values
   (lambda (bindings)
     (let ((table (make-hash-table :test 'equal)))
       (dolist (binding bindings)
         (setf (gethash (car binding) table) (cdr binding)))
       (funcall kont table)))))

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
