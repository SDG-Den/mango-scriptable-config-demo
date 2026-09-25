#lang racket
(require racket/system
         json
         racket/string)

(provide (all-defined-out))

(define (mango-socket-path)
  (or (getenv "MANGO_INSTANCE_SIGNATURE")
      (error "MANGO_INSTANCE_SIGNATURE is not set")))

(define (sh-quote s)
  (format "'~a'" (regexp-replace* #rx"'" s "''")))

(define (mmsg-capture argv)
  (define tmp (path->string (make-temporary-file "mango-~a")))
  (define ret
    (system (string-append (string-join (map sh-quote (cons "mmsg" argv)) " ") " > " tmp)))
  (define text (file->string tmp))
  (delete-file tmp)
  (unless ret (error 'mango (format "mmsg failed: ~a" (string-join argv " "))))
  text)

(define (build-reply cmd out)
  (define reply
    (with-handlers ([exn:fail? (lambda (e)
                                 (error 'mango (format "reply not json for ~a: ~a" cmd out)))])
      (string->jsexpr out)))
  (when (and (hash? reply) (hash-has-key? reply 'error))
    (error 'mango (format "mango error for ~a: ~a" cmd (hash-ref reply 'error #f))))
  reply)

(define (mango-call cmd)
  (build-reply cmd (mmsg-capture (string-split cmd " "))))

(define (mango-call* argv)
  (build-reply (string-join argv " ") (mmsg-capture argv)))

(define (mango-retry cmd [attempts 50] [delay 0.1])
  (let loop ([n attempts])
    (cond
      [(<= n 0)
       (error 'mango (format "not reachable after ~a attempts: ~a" attempts cmd))]
      [(with-handlers ([exn:fail? (lambda (_) (sleep delay) #f)])
         (begin
           (mango-call cmd)
           #t))
       (mango-call cmd)]
      [else (loop (sub1 n))])))

(define (mango-get . spec)
  (mango-call (string-append "get " (string-join spec " "))))

(define (mango-set-option key value)
  (mango-call* (list "setoption" key value)))

(define (mango-dispatch function . args)
  (mango-call (string-append "dispatch " (string-join (cons function args) ","))))

(define (mango-unset-bind mode mods keysym [family "bind"])
  (mango-call* (list "unset" "bind" mode mods keysym family)))

(define (mango-unset-rule kind spec)
  (mango-call* (list "unset" kind spec)))

(define (mango-watch-first subject)
  (mango-call* (list "watch" subject)))

(define (mango-watch subject handler)
  (let loop ()
    (define event (mango-watch-first subject))
    (unless (eq? (handler event) 'stop) (loop))))

(define (mango-version)
  (hash-ref (mango-get "version") 'version))

(define (mango-monitors)
  (hash-ref (mango-get "all-monitors") 'monitors))

(define (mango-clients)
  (hash-ref (mango-get "all-clients") 'clients))

(define (mango-focused-client)
  (mango-get "focusing-client"))

(define (mango-binds)
  (hash-ref (mango-get "binds") 'binds))

(define (mango-rules)
  (hash-ref (mango-get "rules") 'rules))

(define (mango-option key)
  (hash-ref (mango-get (format "option ~a" key)) 'value))

(define (mango-options)
  (mango-get "options"))

(define mango-layout-calls (box 0))
(define (mango-bind mode mods keysym cmd)
  (mango-dispatch "setup_bind" mode mods keysym cmd))

(define (mango-rule match . props)
  (apply mango-dispatch "setup_rule" match props))

(define (mango-rule-for-class class-name . props)
  (apply mango-rule (format "class=~a" class-name) props))

(define (mango-set-layout name)
  (mango-dispatch "setlayout" name))

(define (mango-toggle-layout)
  (set-box! mango-layout-calls (add1 (unbox mango-layout-calls)))
  (mango-set-layout (if (even? (unbox mango-layout-calls)) "dwindle" "tile")))

(define (mango-borders px color)
  (list (mango-set-option "borderpx" (number->string px))
        (mango-set-option "bordercolor" color)))

(define (mango-gaps h v)
  (list (mango-set-option "gappih" (number->string h))
        (mango-set-option "gappiv" (number->string v))))

(define (mango-theme hex border-px)
  (list (mango-set-option "rootcolor" hex)
        (mango-set-option "bordercolor" hex)
        (mango-set-option "borderpx" (number->string border-px))))

(define (mango-watch-until subject predicate [timeout 5.0])
  (define deadline (+ (current-inexact-milliseconds) (* timeout 1000.0)))
  (let loop ()
    (define frame (mango-watch-first subject))
    (if (predicate frame)
        frame
        (if (>= (current-inexact-milliseconds) deadline)
            (error 'mango (format "watch-until timeout: watch ~a" subject))
            (loop)))))

(define (mango-for-each-client fn)
  (for-each fn (mango-clients)))

(define (mango-focused fn)
  (define client (mango-focused-client))
  (unless (null? (hash-ref client 'id #f))
    (fn client)))

(define (mango-options-map)
  (define raw (mango-options))
  (cond
    [(and (hash? raw) (hash-has-key? raw 'options))
     (for/hash ([(k v) (in-hash (hash-ref raw 'options))])
       (values k (if (hash? v) (hash-ref v 'value #f) v)))]
    [(and (hash? raw) (hash-has-key? raw 'option))
     (hash (hash-ref raw 'option "") (hash-ref raw 'value #f))]
    [else raw]))

(define (mango-info)
  (hash 'version (mango-version)
        'monitors (mango-monitors)
        'options (mango-options)))

(define (mango-apply-options pairs)
  (for/list ([(k v) (in-hash pairs)])
    (mango-set-option k (if (string? v) v (number->string v)))))