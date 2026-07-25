# Cookbook

`cl-boundary-kit` keeps the public API small, so the most useful guidance is
pattern-oriented rather than framework-oriented. This document captures a few
supported usage flows that are clearer when shown as end-to-end snippets.

## Compose Boundaries At The Application Edge

Use `make-boundary-context` to wire concrete boundaries in one place, then pass
that context into the part of your application that needs external effects.

```lisp
(let* ((context (cl-boundary-kit:make-boundary-context
                 :clock (cl-boundary-kit:make-fake-clock :start 7)
                 :filesystem (cl-boundary-kit:make-filesystem)))
       (clock (cl-boundary-kit:boundary-context-get context :clock))
       (filesystem (cl-boundary-kit:boundary-context-get context :filesystem)))
  (declare (ignore filesystem))
  (format t "~&clock: ~A~%" (cl-boundary-kit:clock-now clock)))
```

This keeps application code from constructing boundaries ad hoc in the middle
of business logic. See [Composition and Context](composition.md) for the full
context API.

## Assert On Recorded Boundary Calls

Use a recording boundary when you want to inspect the exact arguments and
delegate result without reaching into host resources.

```lisp
(let* ((filesystem (cl-boundary-kit:make-recording-filesystem
                    :delegate (cl-boundary-kit:make-filesystem
                               :write-file-fn (lambda (path content
                                                   &key if-exists if-does-not-exist external-format)
                                                (declare (ignore path content if-exists if-does-not-exist external-format))
                                                :written))))
       (result (cl-boundary-kit:filesystem-store-file filesystem #P"example.txt" "hello"
                                                      :if-exists :append
                                                      :if-does-not-exist :create
                                                      :external-format :utf-8)))
  (cl-boundary-kit:assert-recorded-call
   (cl-boundary-kit:recording-filesystem-calls filesystem)
   :write-file
   :arguments (list #P"example.txt"
                    :content "hello"
                    :if-exists :append
                    :if-does-not-exist :create
                    :external-format :utf-8)
   :result result)
  (format t "~&recorded: ~S~%"
          (cl-boundary-kit:recording-filesystem-calls filesystem))
  (let ((calls (list (cl-boundary-kit:boundary-call-plist :get (list "HOME") :result "/tmp")
                     (cl-boundary-kit:boundary-call-plist :set (list "HOME" :value "/srv") :result t))))
    (cl-boundary-kit:assert-recorded-call-count calls :get 1 :arguments (list "HOME"))
    (cl-boundary-kit:assert-recorded-call-sequence
     calls
     (list '(:operation :get :result "/tmp")
           '(:operation :set :result t)))))
```

This pattern is usually a better fit than a mocking framework because it keeps
the observable contract in plain data.

When you care about repeated calls or ordered multi-step workflows, prefer the
built-in helpers over hand-written `length`, `first`, and `equal` chains. See
[Assertions and Testing Helpers](testing-helpers.md) for the full set.

## Handle Unsupported Operations Explicitly

If a host-specific capability is intentionally unavailable, the library signals
`unsupported-boundary-operation` instead of inventing a fallback.

```lisp
(let ((environment (cl-boundary-kit:make-environment)))
  (handler-case
      (cl-boundary-kit:environment-set environment "FEATURE_FLAG" "enabled")
    (cl-boundary-kit:unsupported-boundary-operation (condition)
      (format t "~&operation: ~S~%"
              (cl-boundary-kit:unsupported-boundary-operation-operation condition))
      (format t "~&detail: ~A~%"
              (cl-boundary-kit:unsupported-boundary-operation-detail condition)))))
```

This keeps unsupported behavior visible in tests and production wiring. See
[Conditions](composition.md#conditions) for the underlying protocol.
