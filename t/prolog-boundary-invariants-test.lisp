;;;; t/prolog-boundary-invariants-test.lisp
(in-package #:cl-boundary-kit/test)

(defun %prolog-binding (variable solution)
  (cdr (assoc variable solution)))

(defparameter *boundary-policy* (cl-prolog-kit:prolog
    ((boundary filesystem))
    ((boundary environment))
    ((boundary process))
    ((boundary network))
    ((boundary clock))
    ((effect filesystem read))
    ((effect filesystem write))
    ((effect environment read))
    ((effect environment write))
    ((effect process execute))
    ((effect network request))
    ((effect clock observe))
    ((recordable filesystem))
    ((recordable environment))
    ((recordable process))
    ((recordable network))
    ((permitted ?boundary ?operation)
      (boundary ?boundary)
      (effect ?boundary ?operation))
    ((observable-effect ?boundary ?operation)
      (permitted ?boundary ?operation)
      (recordable ?boundary)))
  "Facts and rules describing the effect surface of boundary objects.")

(cl-prolog-kit/weave:deftest-queries
  prolog-boundary-policy-has-declarative-invariants
  (*boundary-policy*)
  ("filesystem boundaries permit the expected operations"
    (permitted filesystem ?operation)
    :set
    (((?operation . read)) ((?operation . write))))
  ("observable request effects stay on the network boundary"
    (observable-effect ?boundary request)
    :ordered
    (((?boundary . network))))
  ("undefined clock mutations are rejected" (permitted clock mutate) :fails))

(defparameter *boundary-api-completeness* (cl-prolog-kit:prolog
    ((provides-native filesystem))
    ((provides-native environment))
    ((provides-native process))
    ((provides-native network))
    ((provides-native clock))
    ((provides-native random))
    ((provides-native uuid))
    ((provides-native temp-path))
    ((provides-native args))
    ((provides-native host-info))
    ((provides-native sleeper))
    ((provides-native console))
    ((provides-native system))
    ((provides-native kv))
    ((provides-native metrics))
    ((provides-native lock))
    ((provides-native semaphore))
    ((provides-native working-directory))
    ((provides-native dns))
    ((provides-native secret))
    ((provides-native feature-flags))
    ((provides-native cache))
    ((provides-native rate-limiter))
    ((provides-native scheduler))
    ((provides-native publisher))
    ((provides-native subscriber))
    ((provides-native notifier))
    ((provides-test filesystem))
    ((provides-test environment))
    ((provides-test process))
    ((provides-test network))
    ((provides-test random))
    ((provides-test uuid))
    ((provides-test temp-path))
    ((provides-test args))
    ((provides-test host-info))
    ((provides-test sleeper))
    ((provides-test console))
    ((provides-test system))
    ((provides-test kv))
    ((provides-test metrics))
    ((provides-test lock))
    ((provides-test semaphore))
    ((provides-test working-directory))
    ((provides-test dns))
    ((provides-test secret))
    ((provides-test feature-flags))
    ((provides-test cache))
    ((provides-test rate-limiter))
    ((provides-test scheduler))
    ((provides-test publisher))
    ((provides-test subscriber))
    ((provides-test notifier))
    ((provides-recording filesystem))
    ((provides-recording environment))
    ((provides-recording process))
    ((provides-recording network))
    ((provides-recording random))
    ((provides-recording uuid))
    ((provides-recording temp-path))
    ((provides-recording args))
    ((provides-recording host-info))
    ((provides-recording sleeper))
    ((provides-recording console))
    ((provides-recording system))
    ((provides-recording kv))
    ((provides-recording metrics))
    ((provides-recording lock))
    ((provides-recording semaphore))
    ((provides-recording working-directory))
    ((provides-recording dns))
    ((provides-recording secret))
    ((provides-recording feature-flags))
    ((provides-recording cache))
    ((provides-recording rate-limiter))
    ((provides-recording scheduler))
    ((provides-recording publisher))
    ((provides-recording subscriber))
    ((provides-recording notifier))
    ((complete-triad ?boundary)
      (provides-native ?boundary)
      (provides-test ?boundary)
      (provides-recording ?boundary)))
  "Which native/test/recording constructors each boundary kind actually
exports.")

(cl-prolog-kit/weave:deftest-queries
  boundary-api-triads-match-the-documented-asymmetry
  (*boundary-api-completeness*)
  ("every boundary except clock completes the native/test/recording triad"
    (complete-triad ?boundary)
    :set
    (((?boundary . filesystem))
      ((?boundary . environment))
      ((?boundary . process))
      ((?boundary . network))
      ((?boundary . random))
      ((?boundary . uuid))
      ((?boundary . temp-path))
      ((?boundary . args))
      ((?boundary . host-info))
      ((?boundary . sleeper))
      ((?boundary . console))
      ((?boundary . system))
      ((?boundary . kv))
      ((?boundary . metrics))
      ((?boundary . lock))
      ((?boundary . semaphore))
      ((?boundary . working-directory))
      ((?boundary . dns))
      ((?boundary . secret))
      ((?boundary . feature-flags))
      ((?boundary . cache))
      ((?boundary . rate-limiter))
      ((?boundary . scheduler))
      ((?boundary . publisher))
      ((?boundary . subscriber))
      ((?boundary . notifier))))
  ("clock is the one documented, deliberate asymmetry"
    (complete-triad clock)
    :fails))

(defun %call-with-empty-dynamic-registration (policy body)
  "Seed PLUGIN-REGISTRATION's predicates as dynamic-but-empty, then run BODY.

A predicate with zero clauses and no dynamic declaration raises an
existence error on lookup rather than simply failing. ASSERTZ-ing and
immediately RETRACT-ing a throwaway fact registers the predicate as dynamic
with an empty extension, so BODY can query it before anything real is
registered without tripping that error."
  (cl-prolog-kit:query-prolog
    policy
    '(cl-prolog-kit:assertz (registered-boundary %seed%)))
  (cl-prolog-kit:query-prolog
    policy
    '(cl-prolog-kit:assertz (registered-effect %seed% %seed%)))
  (cl-prolog-kit:query-prolog
    policy
    '(cl-prolog-kit:retract (registered-boundary %seed%)))
  (cl-prolog-kit:query-prolog
    policy
    '(cl-prolog-kit:retract (registered-effect %seed% %seed%)))
  (funcall body))

(it "runtime-plugin-registration-via-assertz-and-retract-updates-permitted-facts"
  (let ((policy (cl-prolog-kit:extend-rulebase *boundary-policy*
                  ((permitted ?boundary ?operation)
                   (registered-boundary ?boundary)
                   (registered-effect ?boundary ?operation)))))
    (%call-with-empty-dynamic-registration policy
     (lambda ()
       (expect (cl-prolog-kit:prolog-succeeds-p policy '(permitted plugin invoke))
               :to-be-null)
       (cl-prolog-kit:query-prolog policy '(cl-prolog-kit:assertz (registered-boundary plugin)))
       (cl-prolog-kit:query-prolog policy '(cl-prolog-kit:assertz (registered-effect plugin invoke)))
       (expect (cl-prolog-kit:prolog-succeeds-p policy '(permitted plugin invoke))
               :to-be-truthy)
       (cl-prolog-kit:query-prolog policy '(cl-prolog-kit:retract (registered-effect plugin invoke)))
       (expect (cl-prolog-kit:prolog-succeeds-p policy '(permitted plugin invoke))
               :to-be-null)
       ;; The original shared policy is untouched by mutating its extended copy.
       (expect (cl-prolog-kit:prolog-succeeds-p *boundary-policy* '(boundary plugin))
               :to-be-null)))))

(defparameter *boundary-policy-with-negation* (cl-prolog-kit:extend-rulebase
    *boundary-policy*
    ((clock-mutation-forbidden) (not (permitted clock mutate)))))

(it "negation-as-failure-declares-clock-mutation-forbidden"
  (expect (cl-prolog-kit:prolog-succeeds-p
           *boundary-policy-with-negation* '(clock-mutation-forbidden))
          :to-be-truthy)
  (expect (cl-prolog-kit:prolog-succeeds-p
           (cl-prolog-kit:extend-rulebase *boundary-policy-with-negation*
             ((clock-observation-forbidden) (not (permitted clock observe))))
           '(clock-observation-forbidden))
          :to-be-null))

(it
  "prolog-rulebase-extension-is-transactional"
  (let ((extended
        (cl-prolog-kit:extend-rulebase
          *boundary-policy*
          ((effect clock advance))
          ((recordable clock)))))
    (cl-prolog-kit/weave:assert-query
      *boundary-policy*
      (permitted clock advance)
      :fails)
    (cl-prolog-kit/weave:assert-query
      *boundary-policy*
      (permitted clock ?operation)
      :set
      (((?operation . observe))))
    (cl-prolog-kit/weave:assert-query
      extended
      (permitted clock ?operation)
      :set
      (((?operation . advance)) ((?operation . observe))))
    (cl-prolog-kit/weave:assert-query
      extended
      (observable-effect clock ?operation)
      :set
      (((?operation . advance)) ((?operation . observe))))))

(it
  "prolog-solutions-stream-through-cps-query-boundary"
  (let ((seen '()))
    (cl-prolog-kit:map-prolog-solutions
      (lambda (solution)
        (push (%prolog-binding '?boundary solution) seen))
      *boundary-policy*
      '(observable-effect ?boundary ?operation)
      :limit
      3)
    (expect (= 3 (length seen)) :to-be-truthy)
    (expect
      (every
        (lambda (boundary)
          (member boundary '(filesystem environment process network)))
        seen)
      :to-be-truthy)))

(it
  "prolog-occurs-check-rejects-cyclic-boundary-facts"
  (expect (null (cl-prolog-kit:unify '?boundary '(wrapped ?boundary))) :to-be-truthy))

;;; Query the text-parsed policy so atom identity matches the text goal.
(it
  "findall-aggregates-every-declared-boundary-fact-into-one-count"
  (let ((policy
        (cl-prolog-kit:consult-prolog
          "boundary(filesystem).
                  boundary(environment).
                  boundary(process).
                  boundary(network).
                  boundary(clock).")))
    (expect
      (=
        1
        (length
          (cl-prolog-kit:query-prolog
            policy
            (cl-prolog-kit:read-prolog-term
              "findall(B, boundary(B), [filesystem,environment,process,network,clock])"))))
      :to-be-truthy)))
