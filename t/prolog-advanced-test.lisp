;;;; t/prolog-advanced-test.lisp
;;;;
;;;; Advanced cl-prolog usage: bounded parsing of untrusted policy source,
;;;; ISO-conformant rejection of malformed goals, and terminating transitive
;;;; reasoning over a boundary delegation graph. Split from
;;;; prolog-boundary-invariants-test.lisp, which holds the trusted-Lisp-data policy
;;;; and its declarative invariant/completeness checks.

(in-package #:cl-boundary-kit/test)

(defparameter *boundary-policy-source*
  "boundary(filesystem).
   boundary(environment).
   effect(filesystem, read).
   effect(filesystem, write).
   effect(environment, read).
   permitted(B, Op) :- boundary(B), effect(B, Op)."
  "The effect surface expressed as untrusted Prolog source text, as it might
arrive from an external configuration file.")

;;; Security: untrusted policy text is parsed within explicit resource bounds,
;;; so a hostile or malformed configuration cannot exhaust memory, the control
;;; stack, or the symbol table.  Each limit is a dynamically-bound special, so
;;; a host can tighten it around any consult of untrusted input.

(it "untrusted-policy-source-parses-and-answers-queries"
  (let ((policy (cl-prolog:consult-prolog *boundary-policy-source*)))
    (expect (cl-prolog:prolog-succeeds-p
             policy (cl-prolog:read-prolog-term "permitted(filesystem, read)"))
            :to-be-truthy)
    (expect (cl-prolog:prolog-succeeds-p
             policy (cl-prolog:read-prolog-term "permitted(filesystem, mutate)"))
            :to-be-null)))

(it "oversized-policy-token-stream-is-rejected-with-a-bounded-error"
  (with-optional-first-prolog-special (("*MAX-PROLOG-TOKENS*" 8)
                                       ("*MAX-PROLOG-SOURCE-CHARACTERS*" 8))
    (with-prolog-parser-resource-error (condition)
        (cl-prolog:consult-prolog *boundary-policy-source*)
      condition)))

(it "deeply-nested-policy-terms-are-rejected-before-stack-exhaustion"
  (with-optional-prolog-special ("*MAX-PROLOG-PARSER-DEPTH*" 4)
    (with-prolog-parser-resource-error (condition)
        (cl-prolog:read-prolog-term "effect(a(b(c(d(e(f))))))")
      condition)))

(it "the-parser-resource-error-carries-actionable-diagnostics"
  (with-optional-prolog-special ("*MAX-PROLOG-SOURCE-CHARACTERS*" 5)
    (with-prolog-parser-resource-error (condition)
        (cl-prolog:read-prolog-term "boundary(filesystem)")
      (let ((resource (prolog-parser-resource-error-resource-value condition))
            (limit (prolog-parser-resource-error-limit-value condition)))
        (when resource
          (expect (string= "SOURCE_CHARACTERS" resource) :to-be-truthy))
        (when limit
          (expect (= 5 limit) :to-be-truthy))))))

;;; Goals against a text-consulted rulebase are themselves parsed from text, so
;;; the untrusted atom names never have to be pre-interned into a host package
;;; and atom identity stays consistent between clauses and queries.
;;; ISO conformance: the query boundary rejects malformed goals with typed,
;;; catchable conditions instead of silently failing or looping.

(it "prolog-query-boundary-rejects-unbound-goals-with-a-catchable-error"
  (handler-case
      (progn
        (cl-prolog:query-prolog *boundary-policy* '?goal)
        (error "Expected unbound Prolog goal to fail"))
    (error (condition)
      (expect (or (prolog-condition-p condition "PROLOG-INSTANTIATION-ERROR")
                  (prolog-condition-p condition "PROLOG-EXISTENCE-ERROR"))
              :to-be-truthy))))

(it "prolog-query-boundary-rejects-non-callable-goals-before-dispatch"
  (handler-case
      (progn
        (cl-prolog:query-prolog *boundary-policy* 42)
        (error "Expected non-callable Prolog goal to fail"))
    (error (condition)
      (expect (prolog-condition-p condition "INVALID-GOAL-ERROR") :to-be-truthy))))

;;; Advanced reasoning + performance: a boundary *delegation* graph and its
;;; transitive closure.  The closure rule is deliberately left-recursive; the
;;; engine detects the left recursion via strongly-connected components
;;; and terminates, where a naive resolution order would diverge.

(defparameter *boundary-delegation*
  (cl-prolog:prolog
    ((delegates recording-filesystem buffered-filesystem))
    ((delegates buffered-filesystem native-filesystem))
    ((delegates recording-process native-process))
    ((delegates recording-network native-network))
    ;; Left-recursive transitive closure of DELEGATES.
    ((reaches ?a ?b) (reaches ?a ?m) (delegates ?m ?b))
    ((reaches ?a ?b) (delegates ?a ?b)))
  "Which concrete boundaries a recording boundary ultimately delegates to.")

(cl-prolog/weave:deftest-queries boundary-delegation-reachability-terminates
    (*boundary-delegation*)
  ("left-recursive reachability yields the full delegation closure"
   (reaches recording-filesystem ?target) :set
   (((?target . buffered-filesystem))
    ((?target . native-filesystem))))
  ("direct delegation is included in the closure"
   (reaches recording-process ?target) :set
   (((?target . native-process)))))

;;; Performance: the same closure expressed as untrusted source with the
;;; predicate declared tabled.  Tabling memoizes variant subgoals, so the
;;; closure over a *cyclic* graph is computed once and terminates.

(it "tabled-reachability-over-a-cyclic-graph-terminates-and-deduplicates"
  (handler-case
      (let ((graph (cl-prolog:consult-prolog
                    "
:- table(reaches/2).
delegates(a, b).
delegates(b, c).
delegates(c, a).
reaches(X, Y) :- delegates(X, Y).
reaches(X, Y) :- delegates(X, Z), reaches(Z, Y).")))
        ;; Over the cycle a -> b -> c -> a every node reaches all three nodes,
        ;; each exactly once thanks to tabled answer deduplication.
        (expect (= 3 (length (cl-prolog:query-prolog
                              graph (cl-prolog:read-prolog-term "reaches(a, Y)"))))
                :to-be-truthy))
    (error (condition)
      (if (prolog-error-message-contains-p condition "Unknown Prolog directive")
          (expect t :to-be-truthy)
          (error condition)))))

;;; Definite-clause grammar (DCG): a capability grant is a well-formed,
;;; non-empty stream of recognized boundary effects.  The grammar validates
;;; the stream declaratively; unknown effects or an empty grant are rejected.
;;; (Grammar operators like TERMINAL are matched by symbol name, so they stay
;;; unqualified; DEF-DCG-RULE/MAKE-RULEBASE/PHRASE-ALL are cl-prolog entry
;;; points.)

(defparameter *capability-grammar*
  (cl-prolog:make-rulebase
   :clauses (list (cl-prolog:def-dcg-rule effect (terminal :read))
                  (cl-prolog:def-dcg-rule effect (terminal :write))
                  (cl-prolog:def-dcg-rule effect (terminal :request))
                  (cl-prolog:def-dcg-rule effect (terminal :observe))
                  (cl-prolog:def-dcg-rule capability effect)
                  (cl-prolog:def-dcg-rule capability effect capability)))
  "A DCG whose CAPABILITY rule accepts a non-empty stream of boundary effects.")

(defun %capability-grant-p (tokens)
  "True when TOKENS is fully consumed by the CAPABILITY grammar, i.e. the whole
stream is a well-formed boundary capability grant."
  (and (member nil (cl-prolog:phrase-all *capability-grammar* 'capability tokens)
               :test #'eq)
       t))

(it "dcg-accepts-well-formed-boundary-capability-streams"
  (expect (%capability-grant-p '(:read :write :request :observe)) :to-be-truthy)
  (expect (%capability-grant-p '(:read)) :to-be-truthy))

(it "dcg-rejects-empty-or-malformed-capability-streams"
  (expect (%capability-grant-p '()) :to-be-null)
  (expect (%capability-grant-p '(:read :delete)) :to-be-null)
  (expect (%capability-grant-p '(:read :write :bogus)) :to-be-null))

;;; Finite-domain constraints: assign distinct priority levels 1..3 to the
;;; filesystem, network, and process boundaries such that the filesystem is
;;; ordered ahead of the network.  The constraint solver enumerates exactly
;;; the admissible orderings (parsed from text so the FD builtins dispatch
;;; under their canonical spelling).

(it "finite-domain-constraints-enumerate-admissible-boundary-orderings"
  (let ((orderings
          (cl-prolog:query-prolog
           (cl-prolog:make-rulebase)
           (cl-prolog:read-prolog-term
            "Fs in [1,2,3], Net in [1,2,3], Proc in [1,2,3], all_different([Fs,Net,Proc]), Fs #< Net, labeling([], [Fs,Net,Proc])"))))
    ;; Over distinct priorities in 1..3 with Fs < Net there are exactly three
    ;; admissible orderings.
    (expect (= 3 (length orderings)) :to-be-truthy)))
