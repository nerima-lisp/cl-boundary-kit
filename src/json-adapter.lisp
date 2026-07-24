;;;; src/json-adapter.lisp

(in-package #:cl-boundary-kit)

;;; Optional cl-json-kit-backed serializer for recorded boundary call
;;; histories. Kept in the separate CL-BOUNDARY-KIT/JSON system so the core
;;; stays dependency-light: only callers that want JSON pull in cl-json-kit,
;;; the nerima-lisp dependency-free JSON reader/writer.

;;; DATA -----------------------------------------------------------------
;;; The recorded-call plist keys, in emission order, paired with their JSON
;;; member names. Kept as a table apart from the conversion LOGIC below so the
;;; emitted wire shape can be read and extended without touching any code.

(defparameter +recorded-call-json-fields+
  '((:operation . "operation")
    (:arguments . "arguments")
    (:result    . "result"))
  "Ordered (plist-key . json-member-name) spec for serializing one recorded call.")

;;; LOGIC ----------------------------------------------------------------
;;; Convert boundary values into cl-json-kit's data model. cl-json-kit refuses
;;; to guess JSON shape from Lisp types and rejects bare keywords, so every
;;; value is mapped explicitly. The recursion is continuation-passing, like the
;;; other /cps converters in this system: descending into a nested list threads
;;; one continuation rather than unwinding a call stack per element.

(defun %boundary-value->json/cps (value continuation)
  "Convert a single boundary VALUE to cl-json-kit's model and call CONTINUATION
with the result. NIL becomes JSON null; a proper list becomes a JSON array."
  ;; Order matters: NIL and T are both symbols, so their clauses precede the
  ;; general SYMBOL clause, and KEYWORD (a symbol subtype) precedes it too.
  (typecase value
    (null    (funcall continuation json-kit:+json-null+))
    ((eql t) (funcall continuation t))
    (keyword (funcall continuation (string-downcase (symbol-name value))))
    (symbol  (funcall continuation (symbol-name value)))
    (string  (funcall continuation value))
    (real    (funcall continuation value))
    (cons    (%boundary-sequence->json/cps value continuation))
    (t       (funcall continuation (princ-to-string value)))))

(defun %boundary-sequence->json/cps (list continuation)
  "Convert each element of LIST (each itself possibly nested) and call
CONTINUATION with a vector, which cl-json-kit serializes as a JSON array."
  (labels ((convert (remaining accumulated)
             (if (endp remaining)
                 (funcall continuation (coerce (nreverse accumulated) 'vector))
                 (%boundary-value->json/cps
                  (first remaining)
                  (lambda (converted)
                    (convert (rest remaining) (cons converted accumulated)))))))
    (convert list '())))

(defun %recorded-call->json-object (call)
  "Convert one recorded-call plist into a cl-json-kit ordered object, following
+RECORDED-CALL-JSON-FIELDS+. :ARGUMENTS is always rendered as an array so an
empty argument list is [] rather than null."
  (json-kit:make-json-object
   (mapcar (lambda (field)
             (destructuring-bind (key . name) field
               (cons name
                     (if (eq key :arguments)
                         (%boundary-sequence->json/cps (getf call key) #'identity)
                         (%boundary-value->json/cps (getf call key) #'identity)))))
           +recorded-call-json-fields+)))

(defun recording-calls-to-json (calls &key pretty)
  "Serialize CALLS -- a recorded-call plist list from any RECORDING-*-CALLS
reader -- as a JSON array of {operation, arguments, result} objects, and return
it as a string.

Useful for logging, snapshotting, or diffing boundary interactions. Pass
:PRETTY non-NIL to indent the output. Provided by the CL-BOUNDARY-KIT/JSON
system, which pulls in nerima-lisp's cl-json-kit."
  (json-kit:stringify
   (coerce (mapcar #'%recorded-call->json-object calls) 'vector)
   :pretty pretty))
