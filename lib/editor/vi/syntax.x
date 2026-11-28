; # x-lib-editor-vi -- the vi editor, as a library
;
; ## lib/editor/vi/syntax.x -- vi's syntax colouring
;
; @author [Jon Ruttan](jonruttan@gmail.com)
; @copyright 2026 Jon Ruttan
; @license MIT No Attribution (MIT-0)
;
; With the option syntax (sy) set, the screen is drawn in the colours of the
; grammar x/tool/syntax has for the file: the one its modeline names, else its
; #! line's, else its name's; syntax=NAME names one for the file being
; edited, until a file is read.  Each row on the screen
; has a row of cells beside its text, one a column: 64 plus the index of the
; column's class, or a space for none (Syntax cells).  A row is written again
; where its text or its cells differ from what the screen shows, an SGR
; sequence before each run of one class and a reset after it.
;
; Busybox's vi has no colour.  The option is off when a run starts, and with
; it off the bytes written are busybox's; :set lists it only while it is on.

(module editor/vi/editor)

(import x/tool/syntax)


(def %vi-cells ())         ; the cell rows as last drawn, beside %vi-screen
(def %vi-drawn-sy #f)      ; whether the rows were drawn in colour
(def %vi-drawn-theme ())   ; the Theme they were drawn in, nil for none

; The grammar for the file being edited, found again when the name changes.
(def %vi-grammar-name ())
(def %vi-grammar ())
(def %vi-grammar-set ())   ; the grammar :set syntax=NAME names, nil for the file's
(def %vi-grammar-set-for ()) ; the file name it was named for

; The grammar :set syntax=NAME named for the file being edited, nil for none:
; the name holds for that file alone, so another file :e reads finds its own.
(def %vi-grammar-chosen
  (fn (_) (if (eq? %vi-grammar-set-for %vi-filename) %vi-grammar-set ())))

; A run starts in the theme the user's theme file names, whatever an earlier
; run set with :set theme=NAME.
(def %vi-syntax-init!
  (fn (_)
    (set! %vi-cells ())
    (set! %vi-drawn-sy #f)
    (set! %vi-drawn-theme ())
    (set! %vi-grammar-name ())
    (set! %vi-grammar ())
    (set! %vi-grammar-set ())
    (set! %vi-grammar-set-for ())
    (Theme forget!)))

; Whether the colours on the screen are not the ones SY would draw: syntax
; turned on or off, or the theme changed.
(def %vi-colours-stale?
  (fn (_ sy)
    (match
      ((null? sy) %vi-drawn-sy)
      ((not %vi-drawn-sy) #t)
      (#t (not (eq? %vi-drawn-theme (Theme current)))))))

; the grammar to draw with, or nil when the option is off or none is the
; file's: the one :set syntax=NAME names, else the one for the file's name and
; its first and last lines, where a modeline or a #! line is
(def %vi-syntax
  (fn (_)
    (match
      ((not (%vi-opt? %vi-sy)) ())
      ((not (null? (%vi-grammar-chosen))) (%vi-grammar-chosen))
      ((null? %vi-filename) ())
      ((eq? %vi-filename %vi-grammar-name) %vi-grammar)
      (#t (do (set! %vi-grammar-name %vi-filename)
              (set! %vi-grammar (Syntax for-file %vi-filename (%vi-text-ends)))
              %vi-grammar)))))

; The text's first five lines and its last five, all of it when they meet:
; the lines vi reads a modeline in.
(def %vi-text-ends
  (fn (_)
    (def head (if (vi< 0 %vi-end) (vi+ (%vi-end-line (%vi-next-lines 0 4)) 1) 0))
    (def tail (if (vi< 0 %vi-end) (%vi-prev-lines (%vi-begin-line (vi- %vi-end 1)) 4) 0))
    (if (vi< head tail)
      (string-append (vi-bsub %vi-text 0 head) (vi-bsub %vi-text tail (vi- %vi-end tail)))
      (vi-bsub %vi-text 0 %vi-end))))

; --- the cells --------------------------------------------------------------

; The cells of the screen's bytes, from the top of the screen to the end of
; its last line, and where they start.
(def %vi-region-cells "")
(def %vi-region-at 0)

(def %vi-region!
  (fn (_ g)
    (def top %vi-screenbegin)
    (def end (vi-min (vi+ (%vi-end-screen) 1) %vi-end))
    (def len (vi-max 0 (vi- end top)))
    (set! %vi-region-at top)
    (set! %vi-region-cells
      (if (= len 0) "" (Syntax cells (g spans %vi-text top len %vi-end) top len)))))

; The cells of the row the line at SRC shows, as %vi-format-line lays out its
; text: a byte's cell for each column it shows in, from the column
; %vi-offset, COLUMNS of them.
(def %vi-format-cells
  (fn (_ src)
    (def shown
      (if (vi< src %vi-end)
        (%vi-shown-cells src (vi+ %vi-offset %vi-columns))
        ""))
    (def len (byte-len shown))
    (def row
      (if (vi< %vi-offset len)
        (vi-bsub shown %vi-offset (vi-min %vi-columns (vi- len %vi-offset)))
        ""))
    (def short (vi- %vi-columns (byte-len row)))
    (if (vi< 0 short) (string-append row (%vi-spaces short)) row)))

(def %vi-shown-cells
  (fn (_ src lim)
    (def pieces (%vi-cells-from src 0 lim ()))
    (if (null? pieces) "" (%str-concat (reverse pieces)))))

; %vi-shown-from's walk: a run of plain bytes takes its cells as they are, a
; tab or a control byte its one cell for each column it shows in
(def %vi-cells-from
  (fn (self a co lim acc)
    (def q (vi-min (%vi-plain-end a) %vi-end))
    (def n (vi-min (vi- q a) (vi- lim co)))
    (def acc2 (if (vi< 0 n) (pair (%vi-cells-at a n) acc) acc))
    (def co2 (vi+ co n))
    (def c (byte-at %vi-text q))
    (match
      ((if (vi< co2 lim) #f #t) acc2)
      ((= c #\newline) acc2)
      ((if (vi< q %vi-end) #f #t) acc2)
      (#t (let ((w (byte-len (%vi-shown-byte c co2))))
            (self (vi+ q 1) (vi+ co2 w) lim
              (pair (%vi-cell-run (%vi-cells-at q 1) w) acc2)))))))

; the N cells of the bytes at P, spaces for any outside the region
(def %vi-cells-at
  (fn (_ p n)
    (def i (vi- p %vi-region-at))
    (if (if (vi< i 0) #f (vi< (vi+ i (vi- n 1)) (byte-len %vi-region-cells)))
      (vi-bsub %vi-region-cells i n)
      (%vi-spaces n))))

(def %vi-cell-run
  (fn (self cell w)
    (if (vi< w 2) cell (string-append cell (self cell (vi- w 1))))))

; --- drawing ----------------------------------------------------------------

; the rows the screen shows, as %vi-format-rows lays them out, with each
; row's cells left in %vi-cells for the Pane
(def %vi-format-rows-sy
  (fn (_ g)
    (%vi-region! g)
    (def r (%vi-rows-sy %vi-screenbegin 0 () ()))
    (set! %vi-cells (rest r))
    (first r)))

(def %vi-rows-sy
  (fn (self tp li acc accc)
    (if (vi< li (vi- %vi-rows 1))
      (self (%vi-row-next tp) (vi+ li 1)
        (pair (%vi-format-line tp) acc) (pair (%vi-format-cells tp) accc))
      (pair (reverse acc) (reverse accc)))))

; a cell's class byte as its SGR sequence, in the theme now current
(def %vi-cell-sgr (fn (_ c) (Syntax sgr (Syntax cell-class c))))
