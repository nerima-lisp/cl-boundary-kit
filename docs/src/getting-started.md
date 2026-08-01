# Getting Started

Clone the repository and load it with ASDF:

```lisp
(require :asdf)
(push #P"/path/to/cl-boundary-kit/" asdf:*central-registry*)
(asdf:load-system :cl-boundary-kit)
```

If you use a local-projects setup, place the repository under your ASDF source
tree and load it the same way.

## Nix

The [flake.nix](https://github.com/nerima-lisp/cl-boundary-kit/blob/main/flake.nix)
at the repository root packages `cl-boundary-kit` as a Nix flake and pins
every test dependency (SBCL, [`cl-weave`](https://github.com/nerima-lisp/cl-weave),
and [`cl-prolog`](https://github.com/nerima-lisp/cl-prolog)) so a checkout
does not require Quicklisp:

```sh
nix run .#test
```

See [Development](project/development.md) for the full set of verification
paths.

## Quick Start

```lisp
(asdf:load-system :cl-boundary-kit)

(let ((clock (cl-boundary-kit:make-fake-clock :start 1000)))
  (list (cl-boundary-kit:clock-now clock)
        (progn (cl-boundary-kit:advance-fake-clock clock 5)
               (cl-boundary-kit:clock-now clock))))
;; => (1000 1005)
```

```lisp
(let* ((delegate (cl-boundary-kit:make-filesystem
                  :write-file-fn (lambda (path content
                                      &key if-exists if-does-not-exist external-format)
                                   (list :path path
                                         :content content
                                         :if-exists if-exists
                                         :if-does-not-exist if-does-not-exist
                                         :external-format external-format))))
       (fs (cl-boundary-kit:make-recording-filesystem :delegate delegate))
       (result (cl-boundary-kit:filesystem-store-file fs #P"example.txt" "hello"
                                                      :if-exists :append
                                                      :if-does-not-exist :create
                                                      :external-format :utf-8)))
  (list :result result
        :calls (cl-boundary-kit:recording-filesystem-calls fs)))
;; => (:RESULT (:PATH #P"example.txt" :CONTENT "hello" ...)
;;     :CALLS ((:OPERATION :WRITE-FILE ...)))
```

That pattern works the same way for environment, process, network, and logging
boundaries.

Recording helpers keep both the arguments and the returned result, including
explicit `nil` results when that is what the boundary returned.
When a delegate operation fails, the recording wrappers for filesystem,
environment, process, network, and custom boundaries re-signal that failure
without adding a partial call record. Logging is slightly different:
`make-recording-logger` keeps the attempted event even if the delegate sink
signals an error, which makes sink failures inspectable in tests.

Continue with [Core Concepts](guide/core-concepts.md) to see the vocabulary
behind these calls, then browse the [Guide](guide/composition.md) for every
boundary's full API surface.
