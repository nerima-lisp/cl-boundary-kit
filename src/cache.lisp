;;;; src/cache.lisp

(in-package #:cl-boundary-kit)

(defclass cache ()
  ((get-fn :initarg :get-fn :reader cache-get-fn)
   (put-fn :initarg :put-fn :reader cache-put-fn)
   (evict-fn :initarg :evict-fn :reader cache-evict-fn)
   (clear-fn :initarg :clear-fn :initform nil :reader cache-clear-fn)))

(defclass test-cache (cache)
  ((table :initarg :table :reader test-cache-table)
   (now-fn :initarg :now-fn :reader test-cache-now-fn)))

(defclass recording-cache (cache)
  ((delegate :initarg :delegate :reader recording-cache-delegate)
   (calls :initform '() :accessor %recording-cache-calls)))

(defun %validate-cache-ttl (ttl)
  (when ttl
    (unless (and (realp ttl) (> ttl 0))
      (error "Cache TTL must be a positive real number or NIL: ~S" ttl)))
  ttl)

(defun make-cache (&key get-fn put-fn evict-fn clear-fn)
  "Create a cache boundary from the supplied collaborator functions.

`cache-get` calls GET-FN with a key and default and should return the cached
value plus a present-p secondary value. `cache-put` calls PUT-FN with a key,
value, and TTL (NIL for no expiry). `cache-evict` calls EVICT-FN with a key and
should return whether the key was present. `cache-clear` calls the optional
CLEAR-FN with no arguments, or signals an unsupported-operation when it is
omitted. Every supplied collaborator is validated at construction time."
  (require-function get-fn "GET-FN")
  (require-function put-fn "PUT-FN")
  (require-function evict-fn "EVICT-FN")
  (require-optional-function clear-fn "CLEAR-FN")
  (make-instance 'cache :get-fn get-fn :put-fn put-fn :evict-fn evict-fn :clear-fn clear-fn))

(defun make-test-cache (&key (now-fn (lambda () 0)) initial)
  "Create an in-memory cache with time-to-live support.

NOW-FN returns the current time; entries stored with a TTL expire once
NOW-FN passes their expiry, at which point `cache-get` treats them as absent and
drops them. INITIAL seeds non-expiring entries from an alist or plist. Keys are
compared with `equal`. Pass `(lambda () (clock-now a-clock))` as NOW-FN to drive
expiry from a fake clock."
  (require-function now-fn "NOW-FN")
  (let ((table (make-hash-table :test 'equal)))
    (%normalize-pairs-cps
     initial
     "INITIAL"
     (lambda (pairs)
       (dolist (pair pairs)
         (setf (gethash (car pair) table) (cons (cdr pair) nil)))))
    (make-instance 'test-cache :get-fn nil :put-fn nil :evict-fn nil
                               :table table :now-fn now-fn)))

(define-recording-boundary-constructor make-recording-cache recording-cache cache (make-test-cache)
  "Create a cache that records calls while delegating to DELEGATE, which defaults
to an empty `make-test-cache`."
  :get-fn nil :put-fn nil :evict-fn nil)

(define-recording-call-log recording-cache-calls reset-recording-cache-calls
    (cache recording-cache %recording-cache-calls) "cache")

(defmethod cache-fetch ((cache cache) key thunk &key ttl)
  ;; Read-through / memoize, derived from the protocol so it works for the
  ;; native, test, and recording variants alike. A present cached value is
  ;; returned without calling THUNK; otherwise THUNK computes it and it is stored
  ;; with the optional TTL.
  (require-function thunk "THUNK")
  (multiple-value-bind (value present) (cache-get cache key)
    (if present
        value
        (let ((computed (funcall thunk)))
          (cache-put cache key computed :ttl ttl)
          computed))))

(defmethod cache-clear ((cache cache))
  (let ((clear-fn (cache-clear-fn cache)))
    (if clear-fn
        (progn (funcall clear-fn) cache)
        (unsupported-operation 'cache-clear "cache clear is unavailable"))))

(defmethod cache-get ((cache cache) key &optional default)
  (funcall (cache-get-fn cache) key default))

(defmethod cache-put ((cache cache) key value &key ttl)
  (%validate-cache-ttl ttl)
  (funcall (cache-put-fn cache) key value ttl))

(defmethod cache-evict ((cache cache) key)
  (funcall (cache-evict-fn cache) key))

(defmethod cache-get ((cache test-cache) key &optional default)
  (let ((table (test-cache-table cache)))
    (multiple-value-bind (entry present) (gethash key table)
      (if (not present)
          (values default nil)
          (let ((expiry (cdr entry))
                (now (funcall (test-cache-now-fn cache))))
            (if (and expiry (>= now expiry))
                ;; Expired: drop it and report absent.
                (progn (remhash key table)
                       (values default nil))
                (values (car entry) t)))))))

(defmethod cache-put ((cache test-cache) key value &key ttl)
  (%validate-cache-ttl ttl)
  (let ((expiry (and ttl (+ (funcall (test-cache-now-fn cache)) ttl))))
    (setf (gethash key (test-cache-table cache)) (cons value expiry))
    value))

(defmethod cache-evict ((cache test-cache) key)
  (remhash key (test-cache-table cache)))

(defmethod cache-clear ((cache test-cache))
  (clrhash (test-cache-table cache))
  cache)

(define-recording-delegate-present-method cache-get
    (cache recording-cache recording-cache-delegate %recording-cache-calls)
    ((key &optional default) (key default)) :get (list key default))

(define-recording-delegate-method cache-put
    (cache recording-cache recording-cache-delegate %recording-cache-calls)
    ((key value &key ttl) (key value :ttl ttl)) :put (list key value ttl)
  (%validate-cache-ttl ttl))

(define-recording-delegate-method cache-evict
    (cache recording-cache recording-cache-delegate %recording-cache-calls)
    ((key) (key)) :evict (list key))

(defmethod cache-clear ((cache recording-cache))
  (cache-clear (recording-cache-delegate cache))
  (%record-call (%recording-cache-calls cache)
    :operation :clear
    :arguments '()
    :result t)
  cache)
