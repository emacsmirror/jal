;;; jal-client-lsp.el --- LSP-Java integration for JAL -*- lexical-binding: t; -*-

;; Author: Saulo Toledo <saulotoledo@gmail.com>

;;; Commentary:
;; This module provides integration between JAL and lsp-java.

;;; Code:

(require 'jal)
(require 'jal-vars)
(require 'jal-known-agents)

(defvar lsp-java-vmargs)
(defvar lsp-java-java-path)
(defvar lsp-java-configuration-runtimes)
(defvar lsp-after-initialize-hook)

(defvar jal--original-lsp-java-vmargs nil
  "Stores the original value of `lsp-java-vmargs' before JAL modifies it.")
(defun jal--lsp-java-current-java-key ()
  "Return the java binary path configured for lsp-java.
Reads `lsp-java-java-path'; falls back to the first `java' on PATH
when it is unset or set to the bare string `java'."
  (let ((configured (and (bound-and-true-p lsp-java-java-path)
                         (not (string= lsp-java-java-path "java"))
                         lsp-java-java-path)))
    (or configured (executable-find "java"))))

(defun jal--lsp-java-restart ()
  "Restart lsp-java workspace if active."
  (when (and (bound-and-true-p lsp-mode)
             (fboundp 'lsp-workspace-restart)
             (fboundp 'lsp-workspaces))
    (setq lsp-java-vmargs (append (bound-and-true-p jal--original-lsp-java-vmargs) (jal-get-vmargs-with-javaagents)))
    (dolist (workspace (lsp-workspaces))
      (lsp-workspace-restart workspace))))

;;;###autoload
(defun jal-lsp-java-setup (&optional agents)
  "Configures JAL for lsp-java with AGENTS list.
AGENTS is a list where each element is either:
- (ARTIFACT-ID . PROPS)
- (ARTIFACT-ID)

PROPS is a plist with keys :params and :jar-path.
User agents override known agents by artifact-id.
If AGENTS is nil, uses the default configuration.
This function should be called in the :init for lsp-java."
  (setq jal-agents-config (jal--merge-agent-configs (or agents '())))
  (setq jal-current-java-key-function #'jal--lsp-java-current-java-key)
  (require 'lsp-java) ; Ensure lsp-java is loaded, so we can access the default lsp-java-vmargs
  (unless (bound-and-true-p jal--original-lsp-java-vmargs)
    (setq jal--original-lsp-java-vmargs (bound-and-true-p lsp-java-vmargs)))
  (setq lsp-java-vmargs (append jal--original-lsp-java-vmargs (jal-get-vmargs-with-javaagents)))
  (add-hook 'lsp-after-initialize-hook #'jal-find-and-configure-agents)
  (add-hook 'jal-agents-detected-hook #'jal--lsp-java-restart))

(provide 'jal-client-lsp)
;;; jal-client-lsp.el ends here
