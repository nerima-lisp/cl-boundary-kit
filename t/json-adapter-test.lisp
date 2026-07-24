;;;; t/json-adapter-test.lisp

(in-package #:cl-boundary-kit/test)

;; RECORDING-CALLS-TO-JSON (cl-boundary-kit/json) serializes the plist call
;; histories every RECORDING-*-CALLS reader returns. These tests pin the wire
;; shape and the boundary-value -> JSON mapping, including the tricky cases the
;; CPS converter exists for: empty argument lists, NIL results, and nesting.

(it "serializes-a-recorded-call-list-as-a-json-array-of-objects"
  (expect (recording-calls-to-json
           (list (list :operation :put :arguments (list "k" 1) :result t)))
          :to-equal "[{\"operation\":\"put\",\"arguments\":[\"k\",1],\"result\":true}]"))

(it "renders-empty-arguments-as-an-array-and-nil-result-as-null"
  ;; The distinction the converter is careful about: an empty :ARGUMENTS list is
  ;; [] (a sequence), while a NIL :RESULT is JSON null (an absent value).
  (expect (recording-calls-to-json
           (list (list :operation :flush :arguments '() :result nil)))
          :to-equal "[{\"operation\":\"flush\",\"arguments\":[],\"result\":null}]"))

(it "converts-nested-list-values-into-nested-json-arrays"
  (expect (recording-calls-to-json
           (list (list :operation :batch :arguments (list (list 1 2) (list "a"))
                       :result (list :ok))))
          :to-equal
          "[{\"operation\":\"batch\",\"arguments\":[[1,2],[\"a\"]],\"result\":[\"ok\"]}]"))

(it "serializes-an-empty-history-as-an-empty-json-array"
  (expect (recording-calls-to-json '()) :to-equal "[]"))

(it "round-trips-a-recording-boundarys-history-through-json"
  ;; End-to-end: drive a real recording boundary, then serialize whatever its
  ;; reader returns -- the adapter accepts any RECORDING-*-CALLS output.
  (let ((boundary (make-recording-boundary
                   :handler (lambda (operation &rest args)
                              (declare (ignore operation args))
                              :done))))
    (recording-boundary-invoke boundary :ping 1)
    (expect (recording-calls-to-json (recording-boundary-calls boundary))
            :to-equal "[{\"operation\":\"ping\",\"arguments\":[1],\"result\":\"done\"}]")))

(it "indents-output-when-pretty-is-requested"
  (let ((json (recording-calls-to-json
               (list (list :operation :get :arguments '() :result "v"))
               :pretty t)))
    (expect (search (string #\Newline) json) :to-be-truthy)
    (expect (search "\"operation\"" json) :to-be-truthy)))
