;;; lang/common-lisp/config.el -*- lexical-binding: t; -*-

(add-hook 'lisp-mode-hook #'rainbow-delimiters-mode)

(after! sly
  (setq inferior-lisp-program "sbcl")

  (set-popup-rules!
    '(("^\\*sly-mrepl"       :vslot 2 :quit nil :ttl nil)
      ("^\\*sly-db"          :vslot 3 :quit nil :ttl nil)
      ("^\\*sly-compilation" :vslot 4 :ttl nil)
      ("^\\*sly-inspector"   :vslot 5 :ttl nil)
      ("^\\*sly-traces"      :vslot 6 :ttl nil)))

  (set-repl-handler! 'lisp-mode #'sly-mrepl)
  (set-eval-handler! 'lisp-mode #'sly-eval-region)
  (set-lookup-handlers! 'lisp-mode
    :definition #'sly-edit-definition
    :documentation #'sly-describe-symbol)

  (sp-with-modes '(sly-mrepl-mode)
    (sp-local-pair "'" "'" :actions nil)
    (sp-local-pair "`" "`" :actions nil))

  ;;
  (defun +common-lisp|cleanup-sly-maybe ()
    "Kill processes and leftover buffers when killing the last sly buffer."
    (unless (cl-loop for buf in (delq (current-buffer) (buffer-list))
                     if (and (buffer-local-value 'sly-mode buf)
                             (get-buffer-window buf))
                     return t)
      (dolist (conn (sly--purge-connections))
        (sly-quit-lisp-internal conn 'sly-quit-sentinel t))
      (let (kill-buffer-hook kill-buffer-query-functions)
        (mapc #'kill-buffer
              (cl-loop for buf in (delq (current-buffer) (buffer-list))
                       if (buffer-local-value 'sly-mode buf)
                       collect buf)))))

  (defun +common-lisp|init-sly ()
    "Attempt to auto-start sly when opening a lisp buffer."
    (cond ((or (doom-temp-buffer-p (current-buffer))
               (sly-connected-p)))
          ((executable-find inferior-lisp-program)
           (let ((sly-auto-start 'always))
             (sly-auto-start)
             (add-hook 'kill-buffer-hook #'+common-lisp|cleanup-sly-maybe nil t)))
          ((message "WARNING: Couldn't find `inferior-lisp-program' (%s)"
                    inferior-lisp-program))))
  (add-hook 'sly-mode-hook #'+common-lisp|init-sly)

  (defun +common-lisp*refresh-sly-version (version conn)
    "Update `sly-protocol-version', which will likely be incorrect or nil due to
an issue where `load-file-name' is incorrect. Because Doom's packages are
installed through an external script (bin/doom), `load-file-name' is set to
bin/doom while packages at compile-time (not a runtime though)."
    (unless sly-protocol-version
      (setq sly-protocol-version (sly-version nil (locate-library "sly.el"))))
    (advice-remove #'sly-check-version #'+common-lisp*refresh-sly-version))
  (advice-add #'sly-check-version :before #'+common-lisp*refresh-sly-version)

  ;; FIXME Buffer/mode-local :desc's don't work yet
  (map! :map sly-mode-map
        :localleader
        :desc "Start Sly" :n "'" #'sly
        (:desc "help" :prefix "h"
          :desc "Apropos"                        :n "a" #'sly-apropos
          :desc "Who binds"                      :n "b" #'sly-who-binds
          :desc "Disassemble symbol"             :n "d" #'sly-disassemble-symbol
          :desc "Describe symbol"                :n "h" #'sly-describe-symbol
          :desc "HyperSpec lookup"               :n "H" #'sly-hyperspec-lookup
          :desc "Who macroexpands"               :n "m" #'sly-who-macroexpands
          :desc "Apropos package"                :n "p" #'sly-apropos-package
          :desc "Who references"                 :n "r" #'sly-who-references
          :desc "Who specializes"                :n "s" #'sly-who-specializes
          :desc "Who sets"                       :n "S" #'sly-who-sets
          :desc "Who calls"                      :n "<" #'sly-who-calls
          :desc "Calls who"                      :n ">" #'sly-calls-who)
        (:desc "compile" :prefix "c"
          :desc "Compile file"                   :n "c" #'sly-compile-file
          :desc "Compile/load file"              :n "C" #'sly-compile-and-load-file
          :desc "Compile defun"                  :n "f" #'sly-compile-defun
          :desc "Load file"                      :n "l" #'sly-load-file
          :desc "Remove notes"                   :n "n" #'sly-remove-notes
          :desc "Compile region"                 :n "r" #'sly-compile-region)
        (:desc "evaluate" :prefix "e"
          :desc "Evaluate buffer"                :n "b" #'sly-eval-buffer
          :desc "Evaluate last expression"       :n "e" #'sly-eval-last-expression
          :desc "Evaluate/print last expression" :n "E" #'sly-eval-print-last-expression
          :desc "Evaluate defun"                 :n "f" #'sly-eval-defun
          :desc "Undefine function"              :n "F" #'sly-undefine-function
          :desc "Evaluate region"                :n "r" #'sly-eval-region)
        (:desc "go"                              :n "g" #'+common-lisp/navigation/body)
        (:desc "macro" :prefix "m"
          :desc "Macro-expand 1 level"           :n "e" #'sly-macroexpand-1
          :desc "Macro-expand all"               :n "E" #'sly-macroexpand-all
          :desc "Macro stepper"                  :n "s" #'+common-lisp/macrostep/body)
        (:desc "repl" :prefix "r"
          :desc "Clear REPL"                     :n "c" #'sly-mrepl-clear-repl
          :desc "Quit Lisp"                      :n "q" #'sly-quit-lisp
          :desc "Restart Lisp"                   :n "r" #'sly-restart-inferior-lisp
          :desc "Sync REPL"                      :n "s" #'sly-mrepl-sync)
        (:desc "stickers" :prefix "s"
          :desc "Toggle break on sticker"        :n "b" #'sly-stickers-toggle-break-on-stickers
          :desc "Clear defun stickers"           :n "c" #'sly-stickers-clear-defun-stickers
          :desc "Clear buffer stickers"          :n "C" #'sly-stickers-clear-buffer-stickers
          :desc "Fetch sticker recordings"       :n "f" #'sly-stickers-fetch
          :desc "Replay sticker recordings"      :n "r" #'sly-stickers-replay
          :desc "Add/remove stickers"            :n "s" #'sly-stickers-dwim)
        (:desc "trace" :prefix "t"
          :desc "Toggle tracing"                 :n "t" #'sly-toggle-trace-fdefinition
          :desc "Toggle fancy tracing"           :n "T" #'sly-toggle-fancy-trace
          :desc "Un-trace all"                   :n "u" #'sly-untrace-all))

  ;; Since `evil-collection-slime' exists, but not `evil-collection-sly', we
  ;; simply copy it
  (when (featurep! :feature evil +everywhere)
    (add-hook 'sly-mode-hook #'evil-normalize-keymaps)
    (add-hook 'sly-popup-buffer-mode-hook #'evil-normalize-keymaps)
    (unless evil-move-beyond-eol
      (advice-add #'sly-eval-last-expression :around #'+common-lisp*sly-last-sexp)
      (advice-add #'sly-pprint-eval-last-expression :around #'+common-lisp*sly-last-sexp)
      (advice-add #'sly-eval-print-last-expression :around #'+common-lisp*sly-last-sexp)
      (advice-add #'sly-eval-last-expression-in-repl :around #'+common-lisp*sly-last-sexp))
    (set-evil-initial-state!
      '(sly-db-mode sly-inspector-mode sly-popup-buffer-mode sly-xref-mode)
      'normal)
    (evil-define-key 'insert sly-mrepl-mode-map
      [S-return] #'newline-and-indent)
    (evil-define-key 'normal sly-parent-map
      (kbd "C-t") #'sly-pop-find-definition-stack)
    (evil-define-key 'normal sly-db-mode-map
      (kbd "RET") 'sly-db-default-action
      (kbd "C-m") 'sly-db-default-action
      [return] 'sly-db-default-action
      [mouse-2]  'sly-db-default-action/mouse
      [follow-link] 'mouse-face
      "\C-i" 'sly-db-cycle
      "g?" 'describe-mode
      "S" 'sly-db-show-source
      "e" 'sly-db-eval-in-frame
      "d" 'sly-db-pprint-eval-in-frame
      "D" 'sly-db-disassemble
      "i" 'sly-db-inspect-in-frame
      "gj" 'sly-db-down
      "gk" 'sly-db-up
      (kbd "C-j") 'sly-db-down
      (kbd "C-k") 'sly-db-up
      "]" 'sly-db-details-down
      "[" 'sly-db-details-up
      (kbd "C-S-j") 'sly-db-details-down
      (kbd "C-S-k") 'sly-db-details-up
      "gg" 'sly-db-beginning-of-backtrace
      "G" 'sly-db-end-of-backtrace
      "t" 'sly-db-toggle-details
      "gr" 'sly-db-restart-frame
      "I" 'sly-db-invoke-restart-by-name
      "R" 'sly-db-return-from-frame
      "c" 'sly-db-continue
      "s" 'sly-db-step
      "n" 'sly-db-next
      "o" 'sly-db-out
      "b" 'sly-db-break-on-return
      "a" 'sly-db-abort
      "q" 'sly-db-quit
      "A" 'sly-db-break-with-system-debugger
      "B" 'sly-db-break-with-default-debugger
      "P" 'sly-db-print-condition
      "C" 'sly-db-inspect-condition
      "g:" 'sly-interactive-eval
      "0" 'sly-db-invoke-restart-0
      "1" 'sly-db-invoke-restart-1
      "2" 'sly-db-invoke-restart-2
      "3" 'sly-db-invoke-restart-3
      "4" 'sly-db-invoke-restart-4
      "5" 'sly-db-invoke-restart-5
      "6" 'sly-db-invoke-restart-6
      "7" 'sly-db-invoke-restart-7
      "8" 'sly-db-invoke-restart-8
      "9" 'sly-db-invoke-restart-9)
    (evil-define-key 'normal sly-inspector-mode-map
      [return] 'sly-inspector-operate-on-point
      (kbd "C-m") 'sly-inspector-operate-on-point
      [mouse-1] 'sly-inspector-operate-on-click
      [mouse-2] 'sly-inspector-operate-on-click
      [mouse-6] 'sly-inspector-pop
      [mouse-7] 'sly-inspector-next
      "gk" 'sly-inspector-pop
      (kbd "C-k") 'sly-inspector-pop
      "gj" 'sly-inspector-next
      "j" 'sly-inspector-next
      "k" 'sly-inspector-previous-inspectable-object
      "K" 'sly-inspector-describe
      "p" 'sly-inspector-pprint
      "e" 'sly-inspector-eval
      "h" 'sly-inspector-history
      "gr" 'sly-inspector-reinspect
      "gv" 'sly-inspector-toggle-verbose
      "\C-i" 'sly-inspector-next-inspectable-object
      [(shift tab)] 'sly-inspector-previous-inspectable-object ; Emacs translates S-TAB
      [backtab] 'sly-inspector-previous-inspectable-object     ; to BACKTAB on X.
      "." 'sly-inspector-show-source
      "gR" 'sly-inspector-fetch-all
      "q" 'sly-inspector-quit)
    (evil-define-key 'normal sly-mode-map
      (kbd "C-t") 'sly-pop-find-definition-stack)
    (evil-define-key 'normal sly-popup-buffer-mode-map
      "q" 'quit-window
      (kbd "C-t") 'sly-pop-find-definition-stack)
    (evil-define-key 'normal sly-xref-mode-map
      (kbd "RET") 'sly-goto-xref
      (kbd "S-<return>") 'sly-goto-xref
      "go" 'sly-show-xref
      "gj" 'sly-xref-next-line
      "gk" 'sly-xref-prev-line
      (kbd "C-j") 'sly-xref-next-line
      (kbd "C-k") 'sly-xref-prev-line
      "]" 'sly-xref-next-line
      "[" 'sly-xref-prev-line
      "gr" 'sly-recompile-xref
      "gR" 'sly-recompile-all-xrefs
      "r" 'sly-xref-retract)))
