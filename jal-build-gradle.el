;;; jal-build-gradle.el --- Gradle detection for Java Agent Loader -*- lexical-binding: t; -*-

;; Author: Saulo Toledo <saulotoledo@gmail.com>

;;; Commentary:
;; Gradle detection logic for JAL.

;;; Code:

(require 'jal-utils)

(defun jal--gradle-write-init-script (agents-list)
  "Write a Gradle init script that lists resolved jars for AGENTS-LIST.
Returns the path to the created temp file. The script emits one line per
resolved artifact in the format:
  JAL_ARTIFACT\\tGROUP\\tARTIFACT\\tVERSION\\tFILE_PATH"
  (let* ((quoted-agents
          (mapconcat (lambda (id) (format "\"%s\"" id)) agents-list ", "))
         (init-file (make-temp-file "jal-gradle-init" nil ".gradle")))
    (with-temp-file init-file
      (insert (format
               "allprojects {
  afterEvaluate { proj ->
    def targets = [%s] as Set
    def cfg = proj.configurations.findByName('runtimeClasspath') ?:
              proj.configurations.findByName('compileClasspath')
    if (cfg) {
      try {
        cfg.resolvedConfiguration.resolvedArtifacts
          .findAll { targets.contains(it.name) }
          .each { art ->
            println \"JAL_ARTIFACT\\t${art.moduleVersion.id.group}\\t${art.name}\\t${art.moduleVersion.id.version}\\t${art.file.absolutePath}\"
          }
      } catch (Exception ignored) {}
    }
  }
}
" quoted-agents)))
    init-file))

(defun jal--gradle-parse-init-output (output)
  "Parse OUTPUT from the JAL Gradle init script.
Returns an alist of (artifact-id . (group version absolute-path)) entries."
  (let ((results '()))
    (dolist (line (split-string output "\n" t))
      (when (string-prefix-p "JAL_ARTIFACT\t" line)
        (let* ((parts (split-string line "\t" t))
               (group    (nth 1 parts))
               (artifact (nth 2 parts))
               (version  (nth 3 parts))
               (path     (nth 4 parts)))
          (when (and group artifact version path)
            (push (list artifact group version path) results)))))
    (nreverse results)))

(defun jal--gradle-detect-agents (project-root agents-list)
  "Run Gradle detection for AGENTS-LIST on PROJECT-ROOT.
Returns a list of (agent-id path version) entries."
  (let ((gradle-cmd (if (file-executable-p (expand-file-name "gradlew" project-root))
                        "./gradlew"
                      (progn
                        (jal--check-executable "gradle" "JAL: Neither ./gradlew nor gradle found")
                        "gradle")))
        (default-directory (or project-root default-directory))
        (found-agents '()))
    (message "JAL: Running Gradle dependency analysis for %d agent(s)..." (length agents-list))
    (let* ((init-file (jal--gradle-write-init-script agents-list))
           (cmd (format "%s --no-daemon -q -I %s 2>/dev/null" gradle-cmd init-file))
           (output (condition-case err
                       (with-output-to-string
                         (call-process-shell-command cmd nil standard-output nil))
                     (error
                      (warn "JAL Gradle Error: Failed to execute '%s'. Error: %S" cmd err)
                      ""))))
      (delete-file init-file)
      (let ((parsed (jal--gradle-parse-init-output output)))
        (dolist (entry parsed)
          (let* ((artifact-id (nth 0 entry))
                 (group-id    (nth 1 entry))
                 (version     (nth 2 entry))
                 (abs-path    (nth 3 entry)))
            ;; Prefer the absolute path the init script gives us; fall back to
            ;; jal--resolve-agent-path so custom :jar-path patterns still work.
            (let ((agent-path
                   (if (and abs-path (file-exists-p abs-path))
                       abs-path
                     (jal--resolve-agent-path
                      (file-name-directory abs-path)
                      group-id artifact-id version))))
              (when agent-path
                (push (list artifact-id agent-path version) found-agents))))))
      (when (null found-agents)
        (message "JAL: No agents found in Gradle dependencies."))
      (nreverse found-agents))))

(provide 'jal-build-gradle)
;;; jal-build-gradle.el ends here
