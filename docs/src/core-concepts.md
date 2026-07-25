# Core Concepts

## Boundary

A boundary is a controlled access point to the outside world. Each boundary is
modeled explicitly instead of being hidden behind ad hoc helpers.

## Protocol

Boundaries are exposed through generic functions such as
`filesystem-read-file`, `clock-now`, and `process-boundary-run`.

## Test Double

The library includes fakes and recording variants so tests can avoid real I/O
without a mocking framework.

## Testing Helper

Use `assert-recorded-call` when you want a small assertion around a recording
boundary call history without pulling in a separate matcher library.
Use `boundary-call-plist` when you want to construct the same call shape
explicitly in a unit test.

```lisp
(let* ((filesystem (cl-boundary-kit:make-recording-filesystem
                    :delegate (cl-boundary-kit:make-filesystem
                               :write-file-fn (lambda (path content
                                                   &key if-exists if-does-not-exist external-format)
                                                (list :path path
                                                      :content content
                                                      :if-exists if-exists
                                                      :if-does-not-exist if-does-not-exist
                                                      :external-format external-format)))))
       (result (cl-boundary-kit:filesystem-store-file filesystem #P"example.txt" "hello")))
  (cl-boundary-kit:assert-recorded-call
   (cl-boundary-kit:recording-filesystem-calls filesystem)
   :write-file
   :arguments (list #P"example.txt"
                    :content "hello"
                    :if-exists nil
                    :if-does-not-exist nil
                    :external-format nil)
   :result result))
;; => (:OPERATION :WRITE-FILE
;;     :ARGUMENTS (#P"example.txt" :CONTENT "hello"
;;                 :IF-EXISTS NIL :IF-DOES-NOT-EXIST NIL :EXTERNAL-FORMAT NIL)
;;     :RESULT (:PATH #P"example.txt" :CONTENT "hello"
;;              :IF-EXISTS NIL :IF-DOES-NOT-EXIST NIL :EXTERNAL-FORMAT NIL))
```

```lisp
(cl-boundary-kit:boundary-call-plist
 :write-file
 (list #P"example.txt" :content "hello")
 :result t)
;; => (:OPERATION :WRITE-FILE
;;     :ARGUMENTS (#P"example.txt" :CONTENT "hello")
;;     :RESULT T)
```

See [Assertions and Testing Helpers](testing-helpers.md) for the full set of
recorded-call and event assertion functions.

## Boundary Context

`make-boundary-context` bundles multiple boundaries into a single object for
composition at the application edge.

`make-boundary-context` expects keyword/value pairs and rejects an odd binding
count. `boundary-context-get` also preserves an explicit stored `nil` instead of
falling back to the default.
`boundary-context-present-p` mirrors the same distinction without returning the
stored value.
Non-keyword context keys are rejected so the composition surface stays explicit.

See [Composition and Context](composition.md) for the full context API.
