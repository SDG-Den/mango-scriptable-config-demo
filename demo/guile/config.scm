(use-modules (mango))

(define (data reply)
  (let ((result (assoc-ref reply "result")))
    (if result result reply)))

(define (array-length value)
  (cond ((vector? value) (vector-length value))
        ((list? value) (length value))
        (else 0)))

(define (entry-count reply)
  (let ((d (data reply)))
    (cond
      ((vector? d) (vector-length d))
      ((not (list? d)) 0)
      ((null? d) 0)
      ((pair? (car d))
       (apply + (map (lambda (entry) (array-length (cdr entry))) d)))
      (else 0))))

(define (on-focus event)
  (let* ((d (data event))
         (appid (or (assoc-ref d "appid") (assoc-ref d "app_id") "-"))
         (title (or (assoc-ref d "title") "-")))
    (display "focus -> ") (display appid) (display " | ") (display title) (newline)
    (force-output)))

(display "mango ") (display (data (retry "get version"))) (newline)

(for-each (lambda (kv) (set-option (car kv) (cdr kv)))
          '(("borderpx" . "3")
            ("gappih" . "6")
            ("gappiv" . "6")
            ("rootcolor" . "2e3440ff")
            ("focused_opacity" . "0.95")
            ("unfocused_opacity" . "0.80")))

(for-each (lambda (bind) (set-option "bind" bind))
          '("alt,Return,spawn_shell,foot"
            "alt,space,setlayout,tile"
            "alt+Shift,space,setlayout,scroller"
            "alt,Tab,focusstack,next"
            "alt+Shift,Tab,focusstack,prev"
            "Ctrl,1,view,1"
            "Ctrl,2,view,2"
            "Ctrl,3,view,3"
            "Ctrl,4,view,4"
            "alt,q,killclient"
            "alt,f,togglefullscreen"))

(set-option "mousebind" "alt,btn_left,moveresize,curmove")
(set-option "tagrule" "id:1,layout_name:tile")
(set-option "tagrule" "id:2,layout_name:scroller")
(set-option "windowrule" "title:foot,isfloating:1")
(set-option "windowrule" "appid:firefox,isfullscreen:1,tags:2")
(set-option "layerrule" "layer_name:waybar,noanim:1,noshadow:1")

(display "binds: ") (display (entry-count (get "binds"))) (newline)
(display "rules: ") (display (entry-count (get "rules"))) (newline)

(dispatch "setlayout" "tile")
(display "dispatch setlayout tile -> ok") (newline)

(display "watching all-clients (layout engine)") (newline)

(define gap-oh 10)
(define gap-ov 10)
(define gap-ih 6)
(define gap-iv 6)

(define (serpentine-slot i cols rows cw ch ox oy)
  (let* ((row (quotient i cols))
         (col (remainder i cols))
         (zcol (if (odd? row) (- cols 1 col) col)))
    (list (+ ox (* zcol (+ cw gap-ih)))
          (+ oy (* row (+ ch gap-iv)))
          cw ch)))

(define (serpentine-slots count mw mh ox oy)
  (let* ((cols (if (> count 0) (min 3 count) 1))
         (rows (if (> count 0) (ceiling (/ count cols)) 1))
         (cw (quotient (- mw (* 2 gap-oh) (* (- cols 1) gap-ih)) cols))
         (ch (quotient (- mh (* 2 gap-ov) (* (- rows 1) gap-iv)) rows)))
    (map (lambda (i) (serpentine-slot i cols rows cw ch ox oy))
         (iota count))))

(define (layout-pass)
  (let* ((mons (let ((d (data (get "all-monitors"))))
                 (let ((m (assoc-ref d "monitors")))
                   (if (vector? m) (vector->list m) m))))
         (clients (let ((d (data (get "all-clients"))))
                    (let ((cs (assoc-ref d "clients")))
                      (if (vector? cs) (vector->list cs) cs)))))
    (when (and (list? mons) (list? clients) (not (null? mons)) (not (null? clients)))
      (let* ((mon (car mons))
             (ox (or (assoc-ref mon "x") 0))
             (oy (or (assoc-ref mon "y") 0))
             (mw (assoc-ref mon "width"))
             (mh (assoc-ref mon "height"))
             (clients (sort clients (lambda (a b) (< (assoc-ref a "id") (assoc-ref b "id")))))
             (slots (serpentine-slots (length clients) mw mh
                                      (+ ox gap-oh) (+ oy gap-ov))))
        (let loop ((clients clients) (slots slots))
          (when (pair? clients)
            (let* ((c (car clients))
                   (x (car (car slots)))
                   (y (cadr (car slots)))
                   (w (caddr (car slots)))
                   (h (cadddr (car slots))))
              (let ((cx (assoc-ref c "x"))
                    (cy (assoc-ref c "y"))
                    (cw (assoc-ref c "width"))
                    (ch (assoc-ref c "height")))
                (if (not (and (eqv? cx x) (eqv? cy y) (eqv? cw w) (eqv? ch h)))
                    (begin
                      (dispatch "movewin"
                                (string-append (number->string x) "," (number->string y))
                                (string-append "client," (number->string (assoc-ref c "id"))))
                      (dispatch "resizewin"
                                (string-append (number->string w) "," (number->string h))
                                (string-append "client," (number->string (assoc-ref c "id")))))))
              (loop (cdr clients) (cdr slots)))))))))

(watch "all-clients" (lambda (event) (layout-pass)))