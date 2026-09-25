#!/usr/bin/env racket
#lang racket
(require "mango.rkt")

(define ok
  (with-handlers ([exn:fail? (lambda (_) #f)])
    (begin
      (mango-retry "get version")
      #t)))

(when (not ok)
  (error "mango not reachable"))

(displayln (format "version: ~a" (mango-version)))
(mango-set-option "borderpx" "0")
(mango-set-option "gappih" "4")
(mango-set-option "rootcolor" "1d1d2b")
(mango-set-option "animations" "off")
(mango-set-option "bind" "alt,Return,spawn_shell,foot")
(mango-dispatch "setlayout" "tile")
(displayln (format "binds: ~a" (length (mango-binds))))
(displayln (format "monitors: ~a" (length (mango-monitors))))
(mango-watch-first "all-clients")
(displayln "config done")