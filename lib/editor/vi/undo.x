; # x-lib-editor-vi -- the vi editor, as a library
;
; ## lib/editor/vi/undo.x -- vi's undo and its . command
;
; @author [Jon Ruttan](jonruttan@gmail.com)
; @copyright 2026 Jon Ruttan
; @license MIT No Attribution (MIT-0)
;
; u and ., each busybox's (editors/vi.c, with FEATURE_VI_UNDO, its queue,
; and FEATURE_VI_DOT_CMD).  The undo stack is editor/undo's Undo: every
; change to the text says how it may be undone, and the change count busybox
; shows is the stack's height.  What u says, and where it leaves the cursor,
; are here.
;
; . replays the keys of the last command that changed the text: from the
; command's own key to the end of it, as typed, with its count before them.

(module editor/vi/editor)

; --- the undo stack ---------------------------------------------------------

; The stack and its queue are the Undo's, editor/undo; what a u says, and
; where it leaves the cursor, are vi's.

; how a change may be undone, as the callers say it
(def %vi-no-undo (Undo none))
(def %vi-allow-undo (Undo alone))
(def %vi-allow-undo-chain (Undo chain))
(def %vi-allow-undo-queued (Undo queued))

; the records' types
(def %vi-u-ins (Undo ins))
(def %vi-u-del (Undo del))
(def %vi-u-ins-chain (Undo ins-chain))
(def %vi-u-del-chain (Undo del-chain))
(def %vi-u-ins-queued (Undo ins-queued))
(def %vi-u-del-queued (Undo del-queued))

; busybox's vi_main: the text and its undo, once a run
(def %vi-undo-init!
  (fn (_)
    (set! %vi-buf (Buffer make))
    (set! %vi-u (Undo make %vi-buf))
    (set! %vi-mod 0)
    (set! %vi-queued #f)
    (set! %vi-lc-version -1)
    (%vi-sync!)))

; Each push answers the change count, which vi keeps.  A commit is asked on
; every motion key, so it is sent only when something was queued since the
; last one.
(def %vi-queued #f)
(def %vi-undo-flush! (fn (_) (%vi-u flush!)))
(def %vi-undo-push!
  (fn (_ src len type)
    (if (if (= type %vi-u-ins-queued) #t (= type %vi-u-del-queued)) (set! %vi-queued #t) ())
    (set! %vi-mod (%vi-u push! src len type))))
(def %vi-undo-push-insert!
  (fn (_ p len undo)
    (if (= undo %vi-allow-undo-queued) (set! %vi-queued #t) ())
    (set! %vi-mod (%vi-u push-insert! p len undo))))
(def %vi-undo-push-delete!
  (fn (_ p len undo)
    (if (= undo %vi-allow-undo-queued) (set! %vi-queued #t) ())
    (set! %vi-mod (%vi-u push-delete! p len undo))))
(def %vi-undo-queue-commit!
  (fn (_)
    (if %vi-queued
      (do (set! %vi-queued #f) (set! %vi-mod (%vi-u commit!)))
      ())))

; --- u ----------------------------------------------------------------------

; busybox's undo_pop: the newest record undone, and the ones chained under
; it, each told on the status line; the last, not chained, leaves the cursor
; at its start.  A chain that runs off the stack, or a stack with nothing on
; it, says so.
(def %vi-undo-pop!
  (fn (_)
    (def done (%vi-u pop!))
    (set! %vi-queued #f)
    (set! %vi-mod (%vi-u modified))
    (%vi-sync!)
    (List map (fn (_ e) (%vi-undo-told e)) done)
    (if (if (null? done) #t (Undo chained? (first (List last done))))
      (%vi-status-line! "Already at oldest change")
      (%vi-undo-landed (List last done)))))

(def %vi-undo-told
  (fn (_ e)
    (def type (first e))
    (def start (first (rest e)))
    (def len (first (rest (rest e))))
    (def count (first (rest (rest (rest e)))))
    (match
      ((Undo deletion? type) (%vi-undo-said "restored" len start count))
      ((if (= type %vi-u-ins) #t (= type %vi-u-ins-chain))
        (%vi-undo-said "deleted" len start count))
      (#t ()))))

(def %vi-undo-landed
  (fn (_ e)
    (def type (first e))
    (if (if (= type %vi-u-del) #t (= type %vi-u-ins))
      (do (set! %vi-dot (first (rest e))) (%vi-refresh! #f))
      ())))

(def %vi-undo-said
  (fn (_ what len start count)
    (%vi-status-line!
      (%str-concat
        (list "Undo [" (%vi-num->str count) "] " what " " (%vi-num->str len)
              " chars at position " (%vi-num->str start))))))

; --- . ----------------------------------------------------------------------

; busybox's modifying_cmds: the commands . can repeat
(def %vi-modifying-cmds
  (list #\a #\A #\c #\C #\d #\D #\i #\I #\J #\o #\O #\p #\P #\r #\R #\s
        #\x #\X #\< #\> #\~))
(def %vi-lmc-max 128)       ; busybox's MAX_INPUT_LEN, its buffer's size

(def %vi-adding2q #f)       ; keys are being kept for .
(def %vi-lmc ())            ; the keys kept, newest first
(def %vi-lmc-len 0)
(def %vi-dotcnt 0)          ; the count . gives the command
(def %vi-ioq ())            ; keys . has yet to replay and a NUL, or nil

(def %vi-dot-init!
  (fn (_)
    (set! %vi-adding2q #f)
    (set! %vi-lmc ())
    (set! %vi-lmc-len 0)
    (set! %vi-dotcnt 0)
    (set! %vi-ioq ())))

; busybox's check before do_cmd: a command that changes the text, typed (not
; replayed) in command mode, starts a new record of keys
(def %vi-dot-watch!
  (fn (_ c)
    (if (match
          (%vi-adding2q #f)
          ((if (null? %vi-ioq) #f #t) #f)
          ((if (= %vi-cmd-mode 0) #f #t) #f)
          ((if (vi< 0 c) (vi< c #\delete) #f) (%vi-one-of? c %vi-modifying-cmds))
          (#t #f))
      (%vi-start-new-cmd-q! c)
      ())))

; busybox's start_new_cmd_q
(def %vi-start-new-cmd-q!
  (fn (_ c)
    (set! %vi-dotcnt (if (= %vi-cmdcnt 0) 1 %vi-cmdcnt))
    (set! %vi-lmc (list c))
    (set! %vi-lmc-len 1)
    (set! %vi-adding2q #t)))

; a key read while keeping: kept, unless the buffer is full, which forgets
; the command; busybox keeps each key as a byte
(def %vi-lmc-keep!
  (fn (_ c)
    (if (vi< %vi-lmc-len (vi- %vi-lmc-max 2))
      (do (set! %vi-lmc (pair (vi& c 255) %vi-lmc)) (set! %vi-lmc-len (vi+ %vi-lmc-len 1)))
      (do (set! %vi-adding2q #f) (set! %vi-lmc-len 0)))))

; the next key . replays, or nil when there is none.  The replay ends at a
; NUL, as busybox's string does, and is not over until the NUL is read: the
; last key replayed does not start a new record.
(def %vi-ioq-next!
  (fn (_)
    (if (null? %vi-ioq) () (%vi-ioq-take! (first %vi-ioq)))))
(def %vi-ioq-take!
  (fn (_ c)
    (set! %vi-ioq (if (= c #\null) () (rest %vi-ioq)))
    (if (= c #\null) () c)))

; .: the kept keys given back to be read again, a count before them -- the
; one typed now, or the one the command had
(def %vi-cmd-dot
  (fn (_)
    (if (= %vi-lmc-len 0) ()
      (do (if (= %vi-cmdcnt 0) () (set! %vi-dotcnt %vi-cmdcnt))
          (set! %vi-ioq
            (List append (%vi-bytes-of (%vi-num->str %vi-dotcnt) 0)
              (List append (reverse %vi-lmc) (list 0))))))))
