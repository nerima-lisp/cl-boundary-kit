;;;; src/dns.lisp

(in-package #:cl-boundary-kit)

(defclass dns-resolver ()
  ((resolve-fn :initarg :resolve-fn :reader dns-resolver-resolve-fn)))

(defclass test-dns-resolver (dns-resolver)
  ((hosts :initarg :hosts :reader test-dns-resolver-hosts)))

(defclass recording-dns-resolver (dns-resolver)
  ((delegate :initarg :delegate :reader recording-dns-resolver-delegate)
   (calls :initform '() :accessor %recording-dns-calls)))

(defun %validate-dns-addresses (hostname addresses)
  (unless (listp addresses)
    (error "DNS addresses for ~S must be a list: ~S" hostname addresses))
  (dolist (address addresses addresses)
    (unless (stringp address)
      (error "DNS address for ~S must be a string: ~S" hostname address))))

(defun make-dns-resolver (&key resolve-fn)
  "Create a DNS resolver boundary backed by RESOLVE-FN.

`dns-resolve` calls RESOLVE-FN with a hostname string and expects a list of
address strings back. Wire RESOLVE-FN to a real resolver at the application
edge; it is validated at construction time."
  (require-function resolve-fn "RESOLVE-FN")
  (make-instance 'dns-resolver :resolve-fn resolve-fn))

(defun make-test-dns-resolver (&key hosts)
  "Create an in-memory DNS resolver seeded from HOSTS.

HOSTS is an alist or plist mapping each hostname string to a list of address
strings. `dns-resolve` returns the mapped addresses, and signals for a hostname
that is not present, mirroring a resolution failure."
  (let ((table (make-hash-table :test 'equal)))
    (%normalize-pairs-cps
     hosts
     "HOSTS"
     (lambda (pairs)
       (dolist (pair pairs)
         (setf (gethash (require-string (car pair) "DNS hostname") table)
               (copy-list (%validate-dns-addresses (car pair) (cdr pair)))))))
    (make-instance 'test-dns-resolver :resolve-fn nil :hosts table)))

(define-recording-boundary-constructor make-recording-dns-resolver
    recording-dns-resolver dns-resolver (make-test-dns-resolver)
  "Create a DNS resolver that records lookups while delegating to DELEGATE,
which defaults to an empty `make-test-dns-resolver`."
  :resolve-fn nil)

(define-recording-call-log recording-dns-calls reset-recording-dns-calls
    (resolver recording-dns-resolver %recording-dns-calls) "DNS resolver")

(defmethod dns-resolve ((resolver dns-resolver) hostname)
  (require-string hostname "DNS hostname")
  (funcall (dns-resolver-resolve-fn resolver) hostname))

(defmethod dns-resolve ((resolver test-dns-resolver) hostname)
  (require-string hostname "DNS hostname")
  (multiple-value-bind (addresses present)
      (gethash hostname (test-dns-resolver-hosts resolver))
    (unless present
      (error "DNS resolution failed: no records for ~S" hostname))
    (copy-list addresses)))

(define-recording-delegate-method dns-resolve
    (resolver recording-dns-resolver recording-dns-resolver-delegate %recording-dns-calls)
    ((hostname) (hostname)) :resolve (list hostname)
  (require-string hostname "DNS hostname"))
