(require 'recur)
(require 'multi-methods)
(provide 'vemv.lang)

; elisp gotchas: let vs. let* · last returns a list · "Wrong type argument: commandp" -> forgot interactive
; fboundp is handy.
;(setq lexical-binding t). buffer-local.

(defmacro comm (&rest forms)
  "Comment. Doesn't evaluate its arguments, returns nil.")

(defmacro argless (&rest forms)
  "Shortcut for (lambda () (interactive) ,@forms)"
  `(lambda () (interactive) ,@forms))

(defmacro if-let (binding &rest forms)
"Usage: (if-let (x (some-computation))
                (then x)
                (else x) (else_2) ... (else_N))"
  (let ((symbol (first binding))
        (value (second binding)))
    `(let ((,symbol ,value))
       (if ,symbol
           ,@forms))))

(defmacro if-not (test &rest forms))

(defmacro when-not (test &rest forms))

(defun delay (f &optional seconds)
  "Calls f in one or SECONDS seconds."
  (run-at-time (concat (int-to-string (or seconds 1)) " seconds") nil f))

(defmacro conj! (seq item) ; Functionality doesn't require a macro - setq does as it is a special form.
  `(setq ,seq (cons ,item ,seq)))

(defmacro send! (x f &rest args)  ; Same here: functionality doesn't require a macro - setq does as it is a special form.
  "Sets x to the result of (f x args)"
  `(setq ,x (apply ,f (cons ,x (list ,@args)))))

(defmacro pos? (x)
  "(> x 0)"
  `(> ,x 0))

(defmacro neg? (x)
  "(< x 0)"
  `(< ,x 0))

(defmacro inc (n)
  `(+ ,n 1))

(defmacro dec (n)
  `(- ,n 1))

(recur-defun* vemv/take (n seq &optional acc)
  ""
  (if (and seq (pos? n))
      (recur (dec n) (rest seq) (cons (first seq) acc))
      (when (zero? n)
        (reverse acc))))

(recur-defun* vemv/drop (n seq)
  ""
  (if (pos? n)
      (recur (dec n) (rest seq))
      seq))

(recur-defun* vemv/partition (n seq &optional step acc)
  "Divides SEQ in a list of lists of N items each, at offsets STEP or N apart. ACC is an implementation detail - do not pass this parameter!"
  ;(mapc (lambda (a) (message (prin1-to-string a))) (list 'n n 'seq seq 'step step 'acc acc))
      (if seq
          (recur n (vemv/drop (or step n) seq) (if-let (taken (vemv/take n seq)) ; XXX <<<<<<<<<<< recur takes the args in mistaken order. wut!
                         (cons taken acc)
                         acc) (or step n)
                 )
        (reverse acc)))

(defun vemv/contains? (a b)
  "Whether the string B is contained in A."
  (let* ((a-list (string-to-list a))
         (b-list (string-to-list b))
         (a-parted (vemv/partition (length b-list) a-list 1)))
    (some (lambda (slice)
            (equal slice b-list))
          a-parted)))

(defun vemv/maximize ()
  "Maximize the current frame. Presumes an X-window environment."
  (interactive))

(defun vemv/hash-map (&rest kvs)
  "Makes and returns a hash table out of its arguments."
  (let ((result (make-hash-table :test 'equal)))
    (dolist (kv (vemv/partition 2 kvs))
      (puthash (first kv) (second kv) result))
    result))

(defun vemv/selected-window-number ()
  (- (string-to-int (window-number-string))))

(defun vemv/window-number-of-buffer (buffer-or-name)
  "XXX")

(defun vemv/ensure-layout ()
  "Fixes the anomalous size the minibuffer can get at times, as well as loss of the original layout proportions in general."
  (interactive)
  (vemv/maximize) (vemv/maximize)
  (delay
   (argless
    (let ((selected (vemv/selected-window-number)))
      (window-number-select 1)
      (enlarge-window-horizontally (- 33 (window-width)))
      (enlarge-window (- 47 (window-height)))
      (window-number-select selected)))))

(defun vemv/selected-region ()
  "Returns the selected region as a string. Side effects free."
  (kill-ring-save (mark) (point))
  (let ((result (substring-no-properties (car kill-ring))))
    (pop kill-ring)
    result))

(defun vemv/sexpr-content (&optional backward?)
  "Returns the content of the next (or previous, on non-nil values of BACKWARD?) sexpr, as a string.

Unlike paredit-copy-as-kill, this function will only grab one sexpr (and no more even - if they are contigous), and is side-effect free."
  (interactive)
  (save-excursion
    (push-mark)
    (if backward? (paredit-backward) (paredit-forward))

    (let ((result (vemv/selected-region)))
      (pop-mark)
      (if backward? (paredit-forward) (paredit-backward))
      result)))

(setq cljs-launched nil)
(defun vemv/send (where &optional backward? content) ; XXX can one do polymorphism in emacs? XXX send w/o intro
  "Copy the next sexp (or on non-nil backward? arg, the previous sexp) and its character trailer,
switch to the window that is assigned for REPL purposes, then it switch to the corresponding buffer (different REPLs have different buffers),
paste and simulate an intro press. Finally, go back to sender window."
  (interactive)

  (let ((content (or content
		     (if (region-active-p)
		      (vemv/selected-region)
		      (vemv/sexpr-content backward?)))))
    (if (equal where :emacs)
        (eval (read content))
        (let ((sender (selected-window)))
          (if (or (equal where :ielm) (equal where :shell)) (select-window vemv/repl2) (select-window vemv/repl1))
          (switch-to-buffer (case where
                              (:slime "*nrepl*")
                              (:ielm "*ielm*")
                              (:shell "*shell*")
                              (:cljs (if cljs-launched
                                         "cljs"
                                         (current-buffer)))))
          (if (not (and (equal where :cljs) (not cljs-launched)))
              (end-of-buffer))

          (when (and (equal where :cljs) (not cljs-launched))

            (shell "cljs")
            (paredit-mode)
            ; (delete-window)      ; (shell) pops up a window
            ;(switch-to-buffer "cljs")
            (insert "cljs")
            (ignore-errors (comint-send-input))
            (vemv/next-window)
            (shell "cljsbuild auto")
            ;(delete-window)
            ;(window-number-select 4)
            ;(switch-to-buffer "cljsbuild auto")
            (insert "cd ~/Development/needleforsoundcloud ; lein trampoline cljsbuild auto")
            (ignore-errors (comint-send-input))
            (vemv/previous-window))

          (insert content)

          (case where
            (:slime (nrepl-return))
            (:ielm (ielm-return))
            (:shell (comint-send-input))
            (:cljs (if cljs-launched (comint-send-input))))

          (if (equal where :cljs) (setq cljs-launched t)) ; XXX set for all

          (pop kill-ring)
          (end-of-buffer)
          (select-window sender)))))

(defun vemv/exit-cljs () ; XXX coupled to layout
  "Closes the ClojureScript processes. Meant to be called interactively."
  (interactive)
  (let ((sender (vemv/selected-window-number)))

    (window-number-select 3)
    (switch-to-buffer "cljs")
    (comint-interrupt-subjob)

    (window-number-select 4)
    (switch-to-buffer "cljsbuild auto")
    (comint-interrupt-subjob)

    (delay (argless (kill-buffer "cljs") (kill-buffer "cljsbuild auto")

                    (window-number-select 3) (switch-to-buffer (slime-output-buffer))
                    (window-number-select 4) (switch-to-buffer "*shell*")

                    (window-number-select sender))
           3)

    ))

; XXX infer whether the user wants to insert newlines
(defun vemv/duplicate (&optional backward?) ; XXX indentation: stuff gets inserted at the absolute beggining of line TODO backward?, for sexprs
  "Copies the current line (or sexpr, if point is at the beggining of one, or selection, if the region is active), inserting it at a new line."
  (interactive)

  (if (region-active-p)

      (progn
        (dotimes (i (- (region-end) (point)))
          (forward-char))
        (insert "\n" (vemv/selected-region) "\n"))

      (if (some (lambda (char) (equal char (vemv/current-char-at-point)))
                '("(" "[" "{" "<" "\""))
          (progn
            (let ((content (vemv/sexpr-content))
                  (whitespace (progn (comm let N the num of chars until beggining-of-line, N*" ") "")))
              (paredit-forward)
              (insert (concat "\n\n" whitespace content))
              (call-interactively 'move-end-of-line) ; XXX end of sexpr instead
              (paredit-backward)))

          (progn
            (move-beginning-of-line 1)
            (kill-line)
            (yank)
            (open-line 1)
            (next-line 1)
            (yank)
            (pop kill-ring)))))

(defun vemv/kill (&optional backward?) ; XXX kill comments FIXME can leave sexprs unmatched
  "Deletes the next (or previous, on non-nil values of BACKWARD?) sexpr or comment (if there is one).

Unlike paredit-kill, this function will only grab one sexpr (and no more, if they are contigous), and it doesn't alter the kill-ring."
  (interactive)

  (push-mark)
  (if backward? (paredit-backward) (paredit-forward))

  (let ((result (vemv/selected-region)))
    (delete-region (mark) (point))
    (while (and
            (equal " " (vemv/current-char-at-point))
            (not (equal "\n" (vemv/current-char-at-point))))
      (paredit-forward-delete))
    result))

(defun vemv/delete-backward (&optional cut?)
  "Performs a paredit-backward-delete unless the region is active, in which case the selection gets unconditionally removed.

The removed value will be pushed to the kill-ring only on non-nil values of CUT?.

Unconditionally removing code may yield semantically wrong results, i.e. leaving sexprs unmatched. I personally like this tradeoff - use with caution!"
  (interactive)

  (if (region-active-p)
      (progn (call-interactively 'kill-region)
             (if (not cut?) (pop kill-ring)))
      (paredit-backward-delete)))

(defun vemv/active-modes ()
  "Returns a list of the minor modes that are enabled in the current buffer."
  (interactive)
  (let ((active-modes))
    (mapc (lambda (mode) (condition-case nil
                             (if (and (symbolp mode) (symbol-value mode))
                                 (add-to-list 'active-modes mode))
                           (error nil) ))
          minor-mode-list)
    active-modes))

(defun vemv/next-window ()
  "Switch to the next window."
  (interactive)
  (select-window (next-window)))

(defun vemv/previous-window ()
  "Switch to the previous window."
  (interactive)
  (select-window (previous-window)))

(defun vemv/slime-popup-documentation (symbol-name) ; XXX connect if not already
  "Pops up the documentation for the symbol that is currently hovered by the point. Presumes an SLIME environment."
  (interactive (list (slime-read-symbol-name "Documentation for symbol: ")))
  (slime-eval-async `(swank:documentation-symbol ,symbol-name)
                    (lambda (result)
                      (popup-tip result :height ac-quick-help-height))))

(defun vemv/slime-window-documentation (symbol-name)
  "Displays the documentation for the symbol that is currently hovered by the point in a new window. Presumes an SLIME environment."
  (interactive (list (slime-read-symbol-name "Documentation for symbol: ")))
  (slime-documentation symbol-name)
  (delay
   (argless (vemv/next-window)
            (message "Press 'q' to close this window."))))

(defun vemv/elisp-popup-documentation ()
  "Pops up the documentation for the symbol that is currently hovered by the point. Presumes emacs-lisp-mode."
  (interactive)
  (if-let (f (function-called-at-point))
          (let ((string (ac-symbol-documentation f)))
            (cond
             ((and window-system (featurep 'pos-tip)) ;; see: `ac-pos-tip-show-quick-help'
              (pos-tip-show string 'popup-tip-face nil nil 0 popup-tip-max-width))
             ((featurep 'popup)
              (popup-tip string :height ac-quick-help-height))
             (t
              (message string))))))

(defun vemv/elisp-window-documentation ()
  "Displays the documentation for the symbol that is currently hovered by the point in a new window. Presumes emacs-lisp-mode."
  (interactive)
  (if-let (f (function-called-at-point))
          (describe-function f)))

(defun vemv/reverse (seq)
  (typecase seq
    (string (concat (reverse (string-to-list seq))))))

(defun vemv/ends-with (s ending)
  "Returns non-nil if string S ends with ENDING."
  (let ((elength (length ending)))
    (string= (substring s (- 0 elength)) ending)))

(defun vemv/starts-with (s candidate)
  "Returns non-nil if string S starts with CANDIDATE."
  (let ((clength (length candidate)))
    (if (<= clength (length s))
        (string= (substring s 0 clength) candidate))))

(defun slime-keywordify (symbol)
   "Make a keyword out of the symbol SYMBOL."
   (let ((name (downcase (symbol-name symbol))))
     (intern (if (eq ?: (aref name 0))
                 name
               (concat ":" name)))))

(defun vemv/keyword-to-string (arg)
  ":foo -> \"foo\""
  (substring (symbol-name arg) 1))

(defun vemv/string-to-keyword (arg)
  "\"foo\" -> :foo"
  (slime-keywordify (intern arg)))

(defun vemv/render-trees (dir-trees)
  (interactive)

  (let* ((p (vemv/partition 2 dir-trees))
         (head (car p))
         (rem (cdr p))
         (but_tail (butlast rem))
         (tail (car (last rem))))

    (dirtree-in-buffer (second head) "." (vemv/keyword-to-string (first head)))
    (beginning-of-buffer)
    (tree-mode-toggle-expand)
    (next-line)

    (dolist (each but_tail)
      (dirtree (second each) "." (vemv/keyword-to-string (first each)))
      (tree-mode-toggle-expand)
      (next-line))

    (dirtree (second tail) "." (vemv/keyword-to-string (first tail)))
    (tree-mode-toggle-expand)))

(defun vemv/current-line-content ()
  "Returns the content of the line at which the point is currently located. Side effects free."
  (interactive)
  (let ((result (buffer-substring-no-properties (line-beginning-position 1) (line-beginning-position 2))))
    (if (equal result "") ; abstact away EOFs
        "\n"
        result)))

(defun vemv/current-char-at-point (&optional offset)
  "Returns the character -as a string- hovered by the point, or a contiguous one, if an integer offset is specified."
  (interactive)
  (kill-ring-save (+ 1 (point) (or offset 0)) (+ (point) (or offset 0)))
  (let ((result (substring-no-properties (car kill-ring))))
    (pop kill-ring)
    result))

(defun vemv/indent ()
  "Recursively indents all the sexprs contained by the current sexpr."
  (interactive)
  (save-excursion
    (while (not (some (lambda (char) (equal char (vemv/current-char-at-point)))
		      '("(" "[" "{")))
      (beginning-of-sexp))
    (paredit-wrap-round)
    (paredit-splice-sexp-killing-backward)
    (comment "XXX move one char to the right.")))

(defun vemv/open (&optional filepath)
  "Opens a file (from FILEPATH or the user input), adding its buffer name to vemv/open_files, thus allowing the functionality of vemv/next-file-buffer and vemv/previous-file-buffer."
  (interactive)
  (select-window vemv/main_window)
  (let ((file (buffer-name (or (and filepath (find-file filepath))
                               (ido-find-file)))))
    (when (not (some (lambda (item) (equal item file)) vemv/open_file_buffers))
      (conj! vemv/open_file_buffers file))))

; XXX if scratch is not empty, include it. (?)

(defun vemv/advice-nrepl ()
  (when (vemv/contains? (buffer-name) ".clj")
    (let ((name (nrepl-current-ns)))
      (with-current-buffer "*nrepl*"
	(if (not (equal name (nrepl-current-ns)))
	    (nrepl-set-ns name))))))

(defun vemv/message-file-buffers ()
  (let ((first (car vemv/open_file_buffers))
	(rest (cdr vemv/open_file_buffers)))
    (message  "%s %s" first ; (propertize first 'face '(:background "#000000")) ; "#161616"
	     (apply 'concat (cons "| " (-interpose " | " rest))))))

(defun vemv/next-file-buffer ()
  "Switch to the next buffer that contains a file opened by the user."
  (interactive)
  (if-let (file (second vemv/open_file_buffers))
          (if (equal file (buffer-name (current-buffer)))
              (message "No more file buffers available.")
              (switch-to-buffer file)
              (setq vemv/open_file_buffers `(,@(cdr vemv/open_file_buffers) ,(car vemv/open_file_buffers)))
	      (vemv/advice-nrepl)
	      (vemv/message-file-buffers))
          (message "No more file buffers available.")))

(defun vemv/previous-file-buffer ()
  "Switch to the previous buffer that contains a file opened by the user."
  (interactive)
  (if-let (file (car (last vemv/open_file_buffers)))
          (if (equal file (buffer-name (current-buffer)))
              (message "No more file buffers available.")
              (switch-to-buffer file)
              (setq vemv/open_file_buffers `(,file ,@(butlast vemv/open_file_buffers)))
	      (vemv/advice-nrepl)
	      (vemv/message-file-buffers))
          (message "No more file buffers available.")))

(defun vemv/home ()
  "Moves the point to leftmost non-empty character in the current line."
  (interactive)
  (move-beginning-of-line 1)
  (if (not (equal last-command 'vemv/home))
      (while (some (lambda (char) (equal char (vemv/current-char-at-point)))
                   '(" " "\t"))
        (forward-char))))

(defun vemv/end () ; XXX doesn't honor region, breaks minibuffer.
  "Moves the point to rightmost non-empty character in the current line.

Comments get ignored, this is, point will only move as long as its position still belongs to the code - unless this command has been fired for the second time."
  (interactive)
  (if (equal last-command 'vemv/end)
      (call-interactively 'move-end-of-line)
      (let* ((line (vemv/current-line-content))
             (rev (vemv/reverse line))
             (line_length (length line))
             (movement (recur-let ((result 0))
                                 (if (some (lambda (char) (equal char (substring line result (inc result))))
                                           '(";" "\n"))
                                     result
                                     (recur (inc result))))))
        (move-beginning-of-line 1)
        (forward-char movement)
        ; there may exist empty space between code and comment:
        (if (pos? movement)
            (while (not (some (lambda (char) (equal char (vemv/current-char-at-point)))
                              '(" ")))
              (backward-char)))
        (comm backward-char (recur-let ((result 0))
                                  (if (or
                                       (equal result line_length)
                                       (equal " " (substring rev result (inc result))))
                                      result
                                      (recur (inc result))))))))

(defun vemv/end-of-line-code ()
  (interactive "^")
  (save-match-data
    (let* ((bolpos (progn (beginning-of-line) (point)))
           (eolpos (progn (end-of-line) (point))))
      (if (comment-search-backward bolpos t)
          (search-backward-regexp comment-start-skip bolpos 'noerror))
      (skip-syntax-backward " " bolpos))))

(defun vemv/end-of-line-or-code ()
  (interactive "^")
  (let ((here (point)))
    (vemv/end-of-line-code)
    (if (or (= here (point))
        (bolp))
        (end-of-line))))

(defun vemv/line-empty? (line)
  (or (= 0 (length line))
	    (every (lambda (char) (= char 32)) line)))

(defun vemv/delete-this-line ()
  "Deletes the entire current line regardless of its contents, and any preceding empty lines."
  (interactive)
  (cua-set-mark)
  (previous-line)
  (end-of-line)
  (call-interactively 'kill-region)
  (let ((line (buffer-substring-no-properties (line-beginning-position) (line-end-position))))
    (if (vemv/line-empty? line)
	(vemv/delete-this-line)
	(progn
	  (next-line)
	  (back-to-indentation)))))

(defun vemv/semicolon ()
  (interactive)
  (if (or (equal (vemv/current-char-at-point) ";")
	  (progn "cursor is within string" nil)) ;; XXX
      (insert ";")
      (insert ";; "))) ;; (when (and (eolp) COLUMN > 0) (insert " "))

(defun vemv/ns-form ()
  (interactive)
  (if-let (ns (clojure-find-ns))	  
	  (progn
	    (nrepl-eval-ns-form)
	    (with-current-buffer "*nrepl*"
	      (nrepl-set-ns ns)))))
