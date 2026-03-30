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

(defun jal--lsp-java-candidate-from-runtime (runtime)
  "Return an executable java path from a RUNTIME plist, or nil."
  (when-let ((home (plist-get runtime :path)))
    (let ((bin (expand-file-name "bin/java" home)))
      (if (file-executable-p bin) bin home))))

(defun jal--lsp-java-collect-candidates (current-path)
  "Return a deduplicated list of java executables to offer for selection.
Starts from CURRENT-PATH, adds system java if available, then
harvests paths from `lsp-java-configuration-runtimes'."
  (let* ((candidates (list current-path))
         (candidates (if (and (not (string= current-path "java"))
                              (executable-find "java"))
                         (append candidates '("java"))
                       candidates))
         (candidates (if-let ((runtimes (bound-and-true-p lsp-java-configuration-runtimes)))
                         (append candidates
                                 (delq nil (mapcar #'jal--lsp-java-candidate-from-runtime runtimes)))
                       candidates)))
    (delete-dups (copy-sequence candidates))))

(defun jal--lsp-java-apply-selection (chosen current-path)
  "Set `lsp-java-java-path' to CHOSEN and restart LSP if needed.
unless it equals CURRENT-PATH."
  (setq lsp-java-java-path chosen)
  (if (string= chosen current-path)
      (message "JAL: Java version unchanged (%s)." chosen)
    (message "JAL: Switching to Java at '%s'. Restarting LSP..." chosen)
    (jal--lsp-java-restart)))

;;;###autoload
(defun jal-lsp-java-switch-java-version ()
  "Interactively switch the Java version used by lsp-java."
  (interactive)
  (require 'lsp-java)
  (let* ((current-path (or (bound-and-true-p lsp-java-java-path) "java"))
         (candidates (jal--lsp-java-collect-candidates current-path)))
    (if (< (length candidates) 2)
        (message "JAL: No alternative Java versions found; the only available option is: %s" current-path)
      (let ((chosen (completing-read
                     (format "Switch Java version (current: %s): " current-path)
                     candidates nil t)))
        (jal--lsp-java-apply-selection chosen current-path)))))

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
