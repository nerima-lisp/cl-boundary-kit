;;;; src/secret.lisp

(in-package #:cl-boundary-kit)

(defclass secret-store ()
  ((get-fn :initarg :get-fn :reader secret-store-get-fn)
   (names-fn :initarg :names-fn :initform nil :reader secret-store-names-fn)))

(defclass test-secret-store (secret-store)
  ((table :initarg :table :reader test-secret-store-table)))

(defclass recording-secret-store (secret-store)
  ((delegate :initarg :delegate :reader recording-secret-store-delegate)
   (calls :initform '() :accessor %recording-secret-calls)))

(defun make-secret-store (&key get-fn names-fn)
  "Create a secret store boundary backed by GET-FN.

`secret-get` calls GET-FN with a name and default and expects the stored secret
plus a present-p secondary value back. `secret-names` calls the optional NAMES-FN
with no arguments and should return the configured secret names (not their
values), or signals an unsupported-operation when it is omitted. Wire the
collaborators to a real secret backend at the application edge; they are
validated at construction time."
  (require-function get-fn "GET-FN")
  (require-optional-function names-fn "NAMES-FN")
  (make-instance 'secret-store :get-fn get-fn :names-fn names-fn))

(defun make-test-secret-store (&key initial)
  "Create an in-memory secret store seeded from INITIAL.

INITIAL accepts either an alist or a plist mapping secret names to values. Keys
are compared with `equal`, and `secret-get` returns a present-p secondary value
so a stored `nil` is distinguishable from a missing secret."
  (let ((table (make-hash-table :test 'equal)))
    (dolist (pair (%normalize-kv-initial initial))
      (setf (gethash (car pair) table) (cdr pair)))
    (make-instance 'test-secret-store :get-fn nil :table table)))

(defun make-recording-secret-store (&key (delegate (make-test-secret-store)))
  "Create a secret store that records lookups while delegating to DELEGATE.

Unlike the other recording wrappers, this one deliberately never records the
returned secret value: it stores the requested name with a `:redacted` result
and omits the default argument, so secrets cannot leak into a call history that
tests or logs inspect. DELEGATE defaults to an empty `make-test-secret-store`."
  (require-instance delegate 'secret-store "DELEGATE")
  (make-instance 'recording-secret-store :get-fn nil :delegate delegate))

(defun recording-secret-calls (store)
  "Return the recorded secret store calls in call order.

Each recorded call carries the requested name and a `:redacted` result rather
than the real secret value."
  (unless (typep store 'recording-secret-store)
    (error "Unsupported secret store type: ~S" store))
  (%snapshot-recorded-calls (%recording-secret-calls store)))

(defun reset-recording-secret-calls (store)
  "Clear STORE's recorded call history and return STORE.

A recording secret store otherwise retains every call for the object's whole
lifetime; call this periodically to bound memory growth instead of only being
able to reclaim it by discarding the object."
  (unless (typep store 'recording-secret-store)
    (error "Unsupported secret store type: ~S" store))
  (setf (%recording-secret-calls store) nil)
  store)

(defmethod secret-names ((store secret-store))
  (let ((names-fn (secret-store-names-fn store)))
    (if names-fn
        (funcall names-fn)
        (unsupported-operation 'secret-names
                               "secret name enumeration is unavailable"))))

(defmethod secret-names ((store test-secret-store))
  (sort (loop for name being the hash-keys of (test-secret-store-table store)
              collect name)
        #'string<
        :key #'princ-to-string))

(defmethod secret-get ((store secret-store) name &optional default)
  (funcall (secret-store-get-fn store) name default))

(defmethod secret-get ((store test-secret-store) name &optional default)
  (multiple-value-bind (value present) (gethash name (test-secret-store-table store))
    (if present
        (values value t)
        (values default nil))))

(defmethod secret-get ((store recording-secret-store) name &optional default)
  (multiple-value-bind (value present)
      (secret-get (recording-secret-store-delegate store) name default)
    ;; Record only the name and a redacted marker: never the secret value or the
    ;; (possibly secret) default, so the history stays safe to inspect.
    (%record-call (%recording-secret-calls store)
      :operation :get
      :arguments (list name)
      :result :redacted)
    (values value present)))

(defmethod secret-names ((store recording-secret-store))
  ;; Secret NAMES are configuration keys, not the secret values, so they are safe
  ;; to record verbatim (unlike SECRET-GET's redacted result).
  (let ((result (secret-names (recording-secret-store-delegate store))))
    (%record-call (%recording-secret-calls store)
      :operation :names
      :arguments '()
      :result result)
    result))
