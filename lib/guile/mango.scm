(define-module (mango)
  #:use-module (ice-9 rdelim)
  #:use-module (srfi srfi-13)
  #:use-module (json parser)
  #:export (socket-path call get set-option dispatch unset-bind unset-rule retry watch))

(define (socket-path)
  (or (getenv "MANGO_INSTANCE_SIGNATURE")
      (error "MANGO_INSTANCE_SIGNATURE is not set")))

(define (open-socket)
  (let ((s (socket AF_UNIX SOCK_STREAM 0)))
    (connect s (make-socket-address AF_UNIX (socket-path)))
    s))

(define (send-line s cmd)
  (display cmd s)
  (display #\newline s)
  (force-output s))

(define (read-reply s cmd)
  (let ((line (read-line s)))
    (if (eof-object? line)
        (error "connection closed without reply: " cmd)
        (json-string->scm line))))

(define (call cmd)
  (let ((s (open-socket)))
    (dynamic-wind
      (lambda () #f)
      (lambda ()
        (send-line s cmd)
        (read-reply s cmd))
      (lambda () (close-port s)))))

(define (ensure-ok reply)
  (let ((err (assoc-ref reply "error")))
    (if err (error "mango error: " err) reply)))

(define (wait-ms ms)
  (select '() '() '() (/ ms 1000.0)))

(define (retry cmd)
  (let loop ((n 0))
    (if (< n 50)
        (let ((reply (catch #t
                       (lambda () (ensure-ok (call cmd)))
                       (lambda (key . args) #f))))
          (if reply
              reply
              (begin (wait-ms 100) (loop (1+ n)))))
        (error "mango not reachable after 50 attempts: " cmd))))

(define (get . spec)
  (ensure-ok (call (string-concatenate (list "get " (string-join spec " "))))))

(define (set-option key value)
  (ensure-ok (call (string-concatenate (list "setoption " key " " value)))))

(define (dispatch function-name . args)
  (ensure-ok
   (call (string-concatenate
          (list "dispatch " function-name
                (if (null? args)
                    ""
                    (string-append "," (string-join args ","))))))))

(define (unset-bind mode mods keysym . opt-family)
  (let ((family (if (null? opt-family) "bind" (car opt-family))))
    (ensure-ok
     (call (string-concatenate (list "unset bind " mode " " mods " " keysym " " family))))))

(define (unset-rule kind spec)
  (ensure-ok (call (string-concatenate (list "unset " kind " " spec)))))

(define (watch subject on-event)
  (let ((s (open-socket)))
    (dynamic-wind
      (lambda () #f)
      (lambda ()
        (send-line s (string-concatenate (list "watch " subject)))
        (let loop ()
          (let ((line (read-line s)))
            (unless (eof-object? line)
              (if (not (string=? line ""))
                  (on-event (ensure-ok (json-string->scm line))))
              (loop)))))
      (lambda () (close-port s)))))