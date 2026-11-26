; # x-lib-editor-vi -- the vi editor, as a library
;
; ## tests/harness.x -- what the spec harness adds to the dialect
;
; @author [Jon Ruttan](jonruttan@gmail.com)
; @copyright 2026 Jon Ruttan
; @license MIT No Attribution (MIT-0)
;
; The bundle kit's generator writes tests/lib/harness.gen.x: the dialect
; bundle.xon declares, the bundle's lib/ on the import path, then this file.
; The vi specs came from x-coreutils with their fixtures; what they reach
; from there is given here under the same names, on the platform's calls.

(import x/sys/file)
(import x/sys/proc)
(import x/core/doors str-byte-ref str-byte-len str-make)
(import editor/vi/editor Vi vi% vi& vi+ vi- vi-bsub vi-bundle-version vi-dim vi-in?
  vi-init-g! vi-init-text-buffer! vi-key-down vi-key-end vi-key-home
  vi-key-page-down vi-key-page-up vi-key-up vi-max vi-min vi-num-from
  vi-ptr-set! vi-sequences vi-str->ptr vi-typed vi-version-at vi/ vi<)

(def byte-at str-byte-ref)
(def byte-len str-byte-len)
(def string-append (fn (_ . ss) (%str-concat ss)))
(def proc-run (fn (_ argv) (Proc run! argv)))
(def file-write-all (fn (_ path text) (File write-all path text)))
(def file-exists? (fn (_ path) (File exists? path)))
(def file-read-all (fn (_ path) (File read-all path)))
(def cu-int->str (fn (_ n) (Str8 str n)))
(def substring (fn (_ s a b) (Str8 sub a (- b a) s)))
(def string=? (fn (_ a b) (str=? a b)))
(def str-make-raw str-make)
(def map (fn (_ f l) (List map f l)))
(def reverse (fn (_ l) (List reverse l)))
(def length (fn (_ l) (List length l)))
; any number of lists: List append takes two
(def append
  (fn (_ a b . more)
    (if (null? more) (List append a b)
      (List fold (fn (_ acc l) (List append acc l)) (List append a b) more))))
