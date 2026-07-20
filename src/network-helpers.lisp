;;;; src/network-helpers.lisp

(in-package #:cl-boundary-kit)

(declaim (ftype (function (t t &key (:timeout t)) t) network-boundary-request))

(defun %validate-test-network-responses (responses)
  (unless (listp responses)
    (error "Test network boundary responses must be a list: ~S" responses))
  responses)

(defun %proper-list-p (value)
  (loop for tail = value then (cdr tail)
        do (cond
             ((null tail) (return t))
             ((not (consp tail)) (return nil)))))

(defun %network-sensitive-field-p (key)
  (let ((name (typecase key
                (symbol (symbol-name key))
                (string key)
                (t nil))))
    (and name
         (member name
                 '("authorization" "proxy-authorization"
                   "cookie" "set-cookie"
                   "api-key" "apikey" "x-api-key"
                   "token" "access-token" "refresh-token"
                   "password" "secret" "client-secret"
                   "body" "content" "payload")
                 :test #'string-equal))))

(defun %network-plist-p (value)
  (and (%proper-list-p value)
       (evenp (length value))
       (loop for (key nil) on value by #'cddr
             always (or (symbolp key) (stringp key)))))

(defun %network-alist-p (value)
  (and (%proper-list-p value)
       (loop for entry in value
             always (and (consp entry)
                         (or (symbolp (car entry))
                             (stringp (car entry)))))))

(defun %redact-network-plist (value)
  (loop for (key item) on value by #'cddr
        append (list key
                     (if (%network-sensitive-field-p key)
                         :redacted
                         (%redact-network-value item)))))

(defun %redact-network-alist (value)
  (mapcar (lambda (entry)
            (cons (car entry)
                  (if (%network-sensitive-field-p (car entry))
                      :redacted
                      (%redact-network-value (cdr entry)))))
          value))

(defun %redact-network-value (value)
  (cond
    ((atom value) value)
    ((%network-plist-p value) (%redact-network-plist value))
    ((%network-alist-p value) (%redact-network-alist value))
    ((%proper-list-p value) (mapcar #'%redact-network-value value))
    (t (cons (%redact-network-value (car value))
             (%redact-network-value (cdr value))))))

(defun %record-network-call (boundary request timeout result)
  (typecase boundary
    (test-network-boundary
     (%record-call (%test-network-calls boundary)
       :request request :timeout timeout :result result))
    (recording-network-boundary
     (%record-call (%recording-network-calls boundary)
       :request (funcall (recording-network-request-redactor-fn boundary) request)
       :timeout timeout
       :result (funcall (recording-network-response-redactor-fn boundary) result)))
    (t
     (error "Unsupported network boundary type: ~S" boundary))))

(defun %test-network-response (network-boundary request timeout)
  ;; No recording here: NETWORK-BOUNDARY-REQUEST applies it externally for
  ;; every :TEST/:RECORDING kind, so a recording boundary wrapping this
  ;; delegate can dispatch straight to this raw effect without re-entering
  ;; the delegate's own recording path and double-recording the call.
  (declare (ignore timeout))
  (let ((responses (test-network-boundary-responses network-boundary)))
    (unless responses
      (error "Test network boundary has no remaining responses for request ~S" request))
    (let ((response (first responses)))
      (setf (test-network-boundary-responses network-boundary) (rest responses))
      response)))
