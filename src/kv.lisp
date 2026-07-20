;;;; src/kv.lisp

(in-package #:cl-boundary-kit)

(defclass kv-store ()
  ((get-fn :initarg :get-fn :reader kv-store-get-fn)
   (put-fn :initarg :put-fn :reader kv-store-put-fn)
   (delete-fn :initarg :delete-fn :reader kv-store-delete-fn)
   (keys-fn :initarg :keys-fn :reader kv-store-keys-fn)))

(defclass test-kv-store (kv-store)
  ((table :initarg :table :reader test-kv-store-table)))

(defclass recording-kv-store (kv-store)
  ((delegate :initarg :delegate :reader recording-kv-store-delegate)
   (calls :initform '() :accessor %recording-kv-calls)))

(defun %normalize-kv-initial (initial)
  "Return INITIAL as a list of (key . value) pairs, accepting an alist or plist."
  (cond
    ((null initial) '())
    ((every #'consp initial)
     (mapcar (lambda (binding) (cons (car binding) (cdr binding))) initial))
    ((evenp (length initial))
     (loop for (key value) on initial by #'cddr
           collect (cons key value)))
    (t
     (error "INITIAL must be an alist or plist: ~S" initial))))

(defun make-kv-store (&key get-fn put-fn delete-fn keys-fn)
  "Create a key/value store boundary from the supplied collaborator functions.

`kv-get` calls GET-FN with a key and default and should return the stored value
plus a present-p secondary value. `kv-put` calls PUT-FN with a key and value,
`kv-delete` calls DELETE-FN with a key and should return whether the key was
present, and `kv-keys` calls KEYS-FN with no arguments and should return the
current key list. Every collaborator is validated at construction time."
  (require-function get-fn "GET-FN")
  (require-function put-fn "PUT-FN")
  (require-function delete-fn "DELETE-FN")
  (require-function keys-fn "KEYS-FN")
  (make-instance 'kv-store
                 :get-fn get-fn
                 :put-fn put-fn
                 :delete-fn delete-fn
                 :keys-fn keys-fn))

(defun make-test-kv-store (&key initial)
  "Create an in-memory key/value store seeded from INITIAL.

INITIAL accepts either an alist or a plist. Keys are compared with `equal`, so
strings and other compound keys work as expected, and `kv-keys` returns them
sorted by printed representation for reproducible tests."
  (let ((table (make-hash-table :test 'equal)))
    (dolist (pair (%normalize-kv-initial initial))
      (setf (gethash (car pair) table) (cdr pair)))
    (make-instance 'test-kv-store
                   :get-fn nil :put-fn nil :delete-fn nil :keys-fn nil
                   :table table)))

(defun make-recording-kv-store (&key (delegate (make-test-kv-store)))
  "Create a key/value store that records calls while delegating to DELEGATE.

DELEGATE defaults to an empty `make-test-kv-store`."
  (require-instance delegate 'kv-store "DELEGATE")
  (make-instance 'recording-kv-store
                 :get-fn nil :put-fn nil :delete-fn nil :keys-fn nil
                 :delegate delegate))

(defun recording-kv-calls (store)
  "Return the recorded key/value store calls in call order."
  (unless (typep store 'recording-kv-store)
    (error "Unsupported key/value store type: ~S" store))
  (%snapshot-recorded-calls (%recording-kv-calls store)))

(defun reset-recording-kv-calls (store)
  "Clear STORE's recorded call history and return STORE.

A recording key/value store otherwise retains every call for the object's whole
lifetime; call this periodically to bound memory growth instead of only being
able to reclaim it by discarding the object."
  (unless (typep store 'recording-kv-store)
    (error "Unsupported key/value store type: ~S" store))
  (setf (%recording-kv-calls store) nil)
  store)

(defmethod kv-update ((store kv-store) key function &optional default)
  ;; Derived from the protocol so it works for the native, test, and recording
  ;; variants alike; a recording store records the underlying get and put.
  (require-function function "FUNCTION")
  (kv-put store key (funcall function (kv-get store key default))))

(defmethod kv-clear ((store kv-store))
  ;; Derived from KV-KEYS + KV-DELETE, so it works across every variant.
  (dolist (key (kv-keys store))
    (kv-delete store key))
  store)

(defmethod kv-increment ((store kv-store) key &optional (delta 1))
  ;; Derived counter increment: treat an absent (or NIL) value as 0. Works across
  ;; every variant, and a recording store records the underlying get and put.
  (unless (realp delta)
    (error "KV-INCREMENT delta must be a real number: ~S" delta))
  (kv-update store key (lambda (current) (+ (or current 0) delta)) 0))

(defmethod kv-get-or-put ((store kv-store) key default-thunk)
  ;; Derived read-through: return a present value, otherwise store and return
  ;; DEFAULT-THUNK's value. Works across the native, test, and recording stores.
  (require-function default-thunk "DEFAULT-THUNK")
  (multiple-value-bind (value present) (kv-get store key)
    (if present
        value
        (let ((computed (funcall default-thunk)))
          (kv-put store key computed)
          computed))))

(defmethod kv-get ((store kv-store) key &optional default)
  (funcall (kv-store-get-fn store) key default))

(defmethod kv-put ((store kv-store) key value)
  (funcall (kv-store-put-fn store) key value))

(defmethod kv-delete ((store kv-store) key)
  (funcall (kv-store-delete-fn store) key))

(defmethod kv-keys ((store kv-store))
  (funcall (kv-store-keys-fn store)))

(defmethod kv-get ((store test-kv-store) key &optional default)
  (multiple-value-bind (value present) (gethash key (test-kv-store-table store))
    (if present
        (values value t)
        (values default nil))))

(defmethod kv-put ((store test-kv-store) key value)
  (setf (gethash key (test-kv-store-table store)) value)
  value)

(defmethod kv-delete ((store test-kv-store) key)
  ;; REMHASH already returns whether the key was present.
  (remhash key (test-kv-store-table store)))

(defmethod kv-keys ((store test-kv-store))
  (sort (loop for key being the hash-keys of (test-kv-store-table store)
              collect key)
        #'string<
        :key #'princ-to-string))

(defmethod kv-get ((store recording-kv-store) key &optional default)
  (multiple-value-bind (value present)
      (kv-get (recording-kv-store-delegate store) key default)
    (%record-call (%recording-kv-calls store)
      :operation :get
      :arguments (list key default)
      :result value)
    (values value present)))

(defmethod kv-put ((store recording-kv-store) key value)
  (let ((result (kv-put (recording-kv-store-delegate store) key value)))
    (%record-call (%recording-kv-calls store)
      :operation :put
      :arguments (list key value)
      :result result)
    result))

(defmethod kv-delete ((store recording-kv-store) key)
  (let ((result (kv-delete (recording-kv-store-delegate store) key)))
    (%record-call (%recording-kv-calls store)
      :operation :delete
      :arguments (list key)
      :result result)
    result))

(defmethod kv-keys ((store recording-kv-store))
  (let ((result (kv-keys (recording-kv-store-delegate store))))
    (%record-call (%recording-kv-calls store)
      :operation :keys
      :arguments '()
      :result result)
    result))
