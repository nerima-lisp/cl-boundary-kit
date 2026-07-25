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
    (t
     (let ((pairs '())
           (rest initial))
       (loop while rest do
         (unless (consp (cdr rest))
           (error "INITIAL must be an alist or plist: ~S" initial))
         (push (cons (first rest) (second rest)) pairs)
         (setf rest (cddr rest)))
       (nreverse pairs)))))

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

(define-recording-boundary-constructor make-recording-kv-store recording-kv-store kv-store (make-test-kv-store)
  "Create a key/value store that records calls while delegating to DELEGATE.

DELEGATE defaults to an empty `make-test-kv-store`."
  :get-fn nil :put-fn nil :delete-fn nil :keys-fn nil)

(define-recording-call-log recording-kv-calls reset-recording-kv-calls
    (store recording-kv-store %recording-kv-calls) "key/value store")

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
  (let ((table (test-kv-store-table store)))
    (multiple-value-bind (value present) (gethash key table)
      (if present
          (values value t)
          (values default nil)))))

(defmethod kv-put ((store test-kv-store) key value)
  (let ((table (test-kv-store-table store)))
    (setf (gethash key table) value))
  value)

(defmethod kv-delete ((store test-kv-store) key)
  ;; REMHASH already returns whether the key was present.
  (let ((table (test-kv-store-table store)))
    (remhash key table)))

(defmethod kv-keys ((store test-kv-store))
  (%sorted-hash-keys (test-kv-store-table store)))

(defmethod kv-get ((store recording-kv-store) key &optional default)
  (let ((delegate (recording-kv-store-delegate store)))
    (multiple-value-bind (value present)
        (kv-get delegate key default)
      (%record-call (%recording-kv-calls store)
        :operation :get
        :arguments (list key default)
        :result value)
      (values value present))))

(define-recording-delegate-method kv-put (store recording-kv-store recording-kv-store-delegate %recording-kv-calls)
    ((key value) (key value)) :put (list key value))

(define-recording-delegate-method kv-delete (store recording-kv-store recording-kv-store-delegate %recording-kv-calls)
    ((key) (key)) :delete (list key))

(define-recording-delegate-method kv-keys (store recording-kv-store recording-kv-store-delegate %recording-kv-calls)
    (() ()) :keys '())
