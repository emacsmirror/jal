;;; java-agent-loader-known-agents.el --- Known agents registry for JAL -*- lexical-binding: t; -*-

;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;; Author: Saulo Toledo <saulotoledo@gmail.com>

;;; Commentary:
;; This module provides a registry of commonly used Java agents with sensible defaults.

;;; Code:

(defvar jal-known-agents
  '(
     ("lombok" :jar-path "org/projectlombok/%a/%v/%a-%v.jar" :params "")
     ("opentelemetry-javaagent" :jar-path "io/opentelemetry/javaagent/%a/%v/%a-%v.jar")
     ("org.jacoco.agent" :jar-path "org/jacoco/%a/%v/%a-%v-runtime.jar"))
  "Registry of known Java agents with default configurations.
Each entry is either:
- (ARTIFACT-ID) : Use defaults
- (ARTIFACT-ID . PROPS) : Specify properties

PROPS is a plist with keys :params and :jar-path.")

(provide 'java-agent-loader-known-agents)
;;; java-agent-loader-known-agents.el ends here
