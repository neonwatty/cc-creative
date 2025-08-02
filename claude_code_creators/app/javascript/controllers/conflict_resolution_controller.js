/**
 * ConflictResolutionController - Handles real-time conflict resolution UI and logic
 * Provides visual conflict indicators, resolution options, and merge tools
 */

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "dialog", "conflictsList", "conflictItem", "previewPane", 
    "resolutionOptions", "mergedContent", "conflictDescription",
    "acceptButton", "rejectButton", "mergeButton", "autoResolveButton"
  ]

  static values = {
    documentId: Number,
    currentUser: Object,
    autoResolveEnabled: { type: Boolean, default: true },
    showLineNumbers: { type: Boolean, default: true },
    highlightChanges: { type: Boolean, default: true }
  }

  static classes = [
    "conflict", "conflictResolved", "conflictPending", 
    "changeInserted", "changeDeleted", "changeModified",
    "userCurrent", "userOther", "mergeOption"
  ]

  connect() {
    // Conflict state
    this.activeConflicts = new Map() // conflictId -> conflict data
    this.resolutionHistory = new Map() // conflictId -> resolution
    this.pendingResolutions = new Set() // conflictIds being resolved

    // UI state
    this.selectedConflict = null
    this.selectedResolution = null

    // Setup event listeners
    this.setupEventListeners()
    
    console.log("ConflictResolutionController connected")
  }

  disconnect() {
    this.cleanup()
    console.log("ConflictResolutionController disconnected")
  }

  setupEventListeners() {
    // Listen for collaboration events
    this.element.addEventListener("collaboration:conflict:detected", this.handleConflictDetected.bind(this))
    this.element.addEventListener("collaboration:conflict:resolved", this.handleConflictResolved.bind(this))
    this.element.addEventListener("collaboration:operation:applied", this.handleOperationApplied.bind(this))

    // Dialog events
    if (this.hasDialogTarget) {
      this.dialogTarget.addEventListener("click", this.handleDialogClick.bind(this))
    }

    // Keyboard shortcuts
    document.addEventListener("keydown", this.handleKeyDown.bind(this))
  }

  // Conflict management
  addConflict(conflictData) {
    const {
      conflictId,
      type,
      description,
      localChange,
      remoteChange,
      baseContent,
      conflictPosition,
      involvedUsers,
      timestamp,
      severity
    } = conflictData

    const conflict = {
      id: conflictId,
      type,
      description,
      localChange,
      remoteChange,
      baseContent,
      position: conflictPosition,
      involvedUsers: involvedUsers || [],
      timestamp: timestamp || Date.now(),
      severity: severity || "medium",
      status: "pending",
      autoResolvable: this.isAutoResolvable(conflictData)
    }

    this.activeConflicts.set(conflictId, conflict)
    this.updateConflictsList()
    this.showConflictDialog()

    // Auto-resolve if possible and enabled
    if (conflict.autoResolvable && this.autoResolveEnabledValue) {
      this.attemptAutoResolve(conflictId)
    }

    this.dispatch("conflict:added", { detail: { conflict } })
  }

  removeConflict(conflictId) {
    const conflict = this.activeConflicts.get(conflictId)
    if (conflict) {
      this.activeConflicts.delete(conflictId)
      this.pendingResolutions.delete(conflictId)
      this.updateConflictsList()

      if (this.selectedConflict?.id === conflictId) {
        this.clearSelection()
      }

      if (this.activeConflicts.size === 0) {
        this.hideConflictDialog()
      }

      this.dispatch("conflict:removed", { detail: { conflictId, conflict } })
    }
  }

  selectConflict(conflictId) {
    const conflict = this.activeConflicts.get(conflictId)
    if (!conflict) return

    this.selectedConflict = conflict
    this.updateConflictDisplay()
    this.updateResolutionOptions()
    this.generatePreview()

    this.dispatch("conflict:selected", { detail: { conflict } })
  }

  clearSelection() {
    this.selectedConflict = null
    this.selectedResolution = null
    this.clearConflictDisplay()
  }

  // Conflict resolution methods
  resolveConflict(conflictId, resolution) {
    const conflict = this.activeConflicts.get(conflictId)
    if (!conflict || this.pendingResolutions.has(conflictId)) {
      return
    }

    this.pendingResolutions.add(conflictId)
    conflict.status = "resolving"

    const resolutionData = {
      conflictId,
      strategy: resolution.strategy,
      content: resolution.content || resolution.mergedContent,
      resolvedBy: this.currentUserValue.id,
      timestamp: Date.now(),
      automatic: resolution.automatic || false
    }

    // Store resolution in history
    this.resolutionHistory.set(conflictId, resolutionData)

    // Notify parent controller
    this.dispatch("conflict:resolve", { 
      detail: { 
        conflictId, 
        resolution: resolutionData 
      } 
    })

    this.updateConflictsList()
  }

  attemptAutoResolve(conflictId) {
    const conflict = this.activeConflicts.get(conflictId)
    if (!conflict || !conflict.autoResolvable) return

    const resolution = this.generateAutoResolution(conflict)
    if (resolution) {
      this.resolveConflict(conflictId, {
        ...resolution,
        automatic: true
      })
    }
  }

  generateAutoResolution(conflict) {
    const { type, localChange, remoteChange, baseContent } = conflict

    switch (type) {
    case "insert_insert":
      // Both users inserted text at same position
      return this.resolveInsertInsertConflict(localChange, remoteChange)
      
    case "modify_modify":
      // Both users modified the same text
      return this.resolveModifyModifyConflict(localChange, remoteChange, baseContent)
      
    case "delete_modify":
      // One user deleted, another modified
      return this.resolveDeleteModifyConflict(localChange, remoteChange)
      
    case "move_modify":
      // One user moved content, another modified it
      return this.resolveMoveModifyConflict(localChange, remoteChange)
      
    default:
      return null
    }
  }

  resolveInsertInsertConflict(localChange, remoteChange) {
    // Merge both insertions, local first
    const mergedContent = localChange.content + remoteChange.content
    return {
      strategy: "merge_insertions",
      content: mergedContent
    }
  }

  resolveModifyModifyConflict(localChange, remoteChange, baseContent) {
    // Use three-way merge logic
    const merged = this.performThreeWayMerge(
      baseContent,
      localChange.content,
      remoteChange.content
    )
    
    if (merged.hasConflicts) {
      return null // Cannot auto-resolve
    }
    
    return {
      strategy: "three_way_merge",
      content: merged.result
    }
  }

  resolveDeleteModifyConflict(localChange, remoteChange) {
    // Prefer modification over deletion
    if (localChange.type === "delete") {
      return {
        strategy: "prefer_modification",
        content: remoteChange.content
      }
    } else {
      return {
        strategy: "prefer_modification",
        content: localChange.content
      }
    }
  }

  resolveMoveModifyConflict(localChange, remoteChange) {
    // Apply modification to moved content
    return {
      strategy: "apply_modification_to_moved",
      content: this.applyModificationToMoved(localChange, remoteChange)
    }
  }

  // Three-way merge implementation
  performThreeWayMerge(base, local, remote) {
    // Simplified three-way merge algorithm
    const baseLines = base.split("\n")
    const localLines = local.split("\n")
    const remoteLines = remote.split("\n")

    const result = []
    let hasConflicts = false

    // Compare line by line
    const maxLines = Math.max(baseLines.length, localLines.length, remoteLines.length)
    
    for (let i = 0; i < maxLines; i++) {
      const baseLine = baseLines[i] || ""
      const localLine = localLines[i] || ""
      const remoteLine = remoteLines[i] || ""

      if (localLine === remoteLine) {
        // Both sides agree
        result.push(localLine)
      } else if (localLine === baseLine) {
        // Only remote changed
        result.push(remoteLine)
      } else if (remoteLine === baseLine) {
        // Only local changed
        result.push(localLine)
      } else {
        // Both sides changed differently - conflict
        hasConflicts = true
        result.push("<<<<<<< Local")
        result.push(localLine)
        result.push("=======")
        result.push(remoteLine)
        result.push(">>>>>>> Remote")
      }
    }

    return {
      result: result.join("\n"),
      hasConflicts
    }
  }

  applyModificationToMoved(moveChange, modifyChange) {
    // Apply the modification to the content at its new location
    return modifyChange.content // Simplified implementation
  }

  // UI Management
  showConflictDialog() {
    if (this.hasDialogTarget) {
      this.dialogTarget.style.display = "block"
      this.dialogTarget.setAttribute("aria-hidden", "false")
    }
  }

  hideConflictDialog() {
    if (this.hasDialogTarget) {
      this.dialogTarget.style.display = "none"
      this.dialogTarget.setAttribute("aria-hidden", "true")
    }
  }

  updateConflictsList() {
    if (!this.hasConflictsListTarget) return

    const container = this.conflictsListTarget
    container.innerHTML = ""

    this.activeConflicts.forEach(conflict => {
      const conflictElement = this.createConflictListItem(conflict)
      container.appendChild(conflictElement)
    })

    // Update conflict count indicator
    this.updateConflictCount()
  }

  createConflictListItem(conflict) {
    const item = document.createElement("div")
    item.className = `conflict-item ${this.conflictClass}`
    item.dataset.conflictId = conflict.id
    item.dataset.conflictType = conflict.type
    item.dataset.conflictSeverity = conflict.severity

    if (conflict.status === "resolving") {
      item.classList.add(this.conflictPendingClass)
    }

    item.innerHTML = `
      <div class="conflict-header">
        <span class="conflict-type">${this.formatConflictType(conflict.type)}</span>
        <span class="conflict-severity severity-${conflict.severity}">${conflict.severity}</span>
        <span class="conflict-timestamp">${this.formatTimestamp(conflict.timestamp)}</span>
      </div>
      <div class="conflict-description">${conflict.description}</div>
      <div class="conflict-users">
        ${conflict.involvedUsers.map(user => `<span class="user-badge">${user.name}</span>`).join("")}
      </div>
      <div class="conflict-actions">
        <button class="btn-select" data-action="click->conflict-resolution#selectConflictFromList">Select</button>
        ${conflict.autoResolvable ? "<button class=\"btn-auto-resolve\" data-action=\"click->conflict-resolution#autoResolveFromList\">Auto-resolve</button>" : ""}
      </div>
    `

    return item
  }

  updateConflictDisplay() {
    if (!this.selectedConflict || !this.hasConflictDescriptionTarget) return

    const conflict = this.selectedConflict
    this.conflictDescriptionTarget.innerHTML = `
      <h3>Conflict Details</h3>
      <p><strong>Type:</strong> ${this.formatConflictType(conflict.type)}</p>
      <p><strong>Description:</strong> ${conflict.description}</p>
      <p><strong>Position:</strong> Line ${conflict.position?.line || "Unknown"}</p>
      <p><strong>Severity:</strong> ${conflict.severity}</p>
      <p><strong>Involved Users:</strong> ${conflict.involvedUsers.map(u => u.name).join(", ")}</p>
    `
  }

  clearConflictDisplay() {
    if (this.hasConflictDescriptionTarget) {
      this.conflictDescriptionTarget.innerHTML = ""
    }
    if (this.hasPreviewPaneTarget) {
      this.previewPaneTarget.innerHTML = ""
    }
  }

  updateResolutionOptions() {
    if (!this.selectedConflict || !this.hasResolutionOptionsTarget) return

    const conflict = this.selectedConflict
    const container = this.resolutionOptionsTarget

    container.innerHTML = `
      <h4>Resolution Options</h4>
      <div class="resolution-option">
        <input type="radio" name="resolution" value="accept_local" id="accept_local">
        <label for="accept_local">Accept My Changes</label>
      </div>
      <div class="resolution-option">
        <input type="radio" name="resolution" value="accept_remote" id="accept_remote">
        <label for="accept_remote">Accept Their Changes</label>
      </div>
      <div class="resolution-option">
        <input type="radio" name="resolution" value="merge_manual" id="merge_manual">
        <label for="merge_manual">Manual Merge</label>
      </div>
      ${conflict.autoResolvable ? `
        <div class="resolution-option">
          <input type="radio" name="resolution" value="auto_merge" id="auto_merge" checked>
          <label for="auto_merge">Automatic Merge</label>
        </div>
      ` : ""}
    `

    // Add event listeners to radio buttons
    container.querySelectorAll("input[name=\"resolution\"]").forEach(radio => {
      radio.addEventListener("change", this.handleResolutionChange.bind(this))
    })
  }

  generatePreview() {
    if (!this.selectedConflict || !this.hasPreviewPaneTarget) return

    const conflict = this.selectedConflict
    const resolution = this.selectedResolution

    let previewContent = ""

    if (resolution) {
      switch (resolution) {
      case "accept_local":
        previewContent = this.generateLocalPreview(conflict)
        break
      case "accept_remote":
        previewContent = this.generateRemotePreview(conflict)
        break
      case "merge_manual":
        previewContent = this.generateMergePreview(conflict)
        break
      case "auto_merge":
        previewContent = this.generateAutoMergePreview(conflict)
        break
      }
    } else {
      previewContent = this.generateConflictPreview(conflict)
    }

    this.previewPaneTarget.innerHTML = previewContent
  }

  generateConflictPreview(conflict) {
    return `
      <div class="conflict-preview">
        <h4>Conflict Preview</h4>
        <div class="change-comparison">
          <div class="local-change ${this.userCurrentClass}">
            <h5>Your Changes:</h5>
            <pre>${this.escapeHtml(conflict.localChange.content)}</pre>
          </div>
          <div class="remote-change ${this.userOtherClass}">
            <h5>Their Changes:</h5>
            <pre>${this.escapeHtml(conflict.remoteChange.content)}</pre>
          </div>
        </div>
      </div>
    `
  }

  generateLocalPreview(conflict) {
    return `
      <div class="resolution-preview">
        <h4>Resolution Preview - Accept Your Changes</h4>
        <pre class="${this.userCurrentClass}">${this.escapeHtml(conflict.localChange.content)}</pre>
      </div>
    `
  }

  generateRemotePreview(conflict) {
    return `
      <div class="resolution-preview">
        <h4>Resolution Preview - Accept Their Changes</h4>
        <pre class="${this.userOtherClass}">${this.escapeHtml(conflict.remoteChange.content)}</pre>
      </div>
    `
  }

  generateMergePreview(conflict) {
    const merged = this.performThreeWayMerge(
      conflict.baseContent,
      conflict.localChange.content,
      conflict.remoteChange.content
    )

    return `
      <div class="resolution-preview">
        <h4>Manual Merge Preview</h4>
        <textarea class="merge-editor" rows="10" cols="80">${this.escapeHtml(merged.result)}</textarea>
        <div class="merge-help">
          <p>Edit the content above to resolve conflicts manually.</p>
          <p>Conflict markers: &lt;&lt;&lt;&lt;&lt;&lt;&lt; ======= &gt;&gt;&gt;&gt;&gt;&gt;&gt;</p>
        </div>
      </div>
    `
  }

  generateAutoMergePreview(conflict) {
    const resolution = this.generateAutoResolution(conflict)
    if (!resolution) {
      return "<div class=\"error\">Auto-merge not possible for this conflict</div>"
    }

    return `
      <div class="resolution-preview">
        <h4>Auto-Merge Preview</h4>
        <pre class="merged-content">${this.escapeHtml(resolution.content)}</pre>
        <div class="merge-strategy">Strategy: ${resolution.strategy}</div>
      </div>
    `
  }

  // Event handlers
  handleConflictDetected(event) {
    const { conflict } = event.detail
    this.addConflict(conflict)
  }

  handleConflictResolved(event) {
    const { conflictId } = event.detail
    this.removeConflict(conflictId)
  }

  handleOperationApplied(event) {
    // Check if any conflicts are now resolved
    const { operation } = event.detail
    this.checkForResolvedConflicts(operation)
  }

  handleDialogClick(event) {
    if (event.target === this.dialogTarget) {
      // Clicked outside dialog content
      event.preventDefault()
    }
  }

  handleKeyDown(event) {
    if (!this.hasDialogTarget || this.dialogTarget.style.display === "none") return

    switch (event.key) {
    case "Escape":
      this.hideConflictDialog()
      break
    case "Enter":
      if (event.ctrlKey || event.metaKey) {
        this.resolveSelectedConflict()
      }
      break
    }
  }

  handleResolutionChange(event) {
    this.selectedResolution = event.target.value
    this.generatePreview()
  }

  // Action methods (called from HTML)
  selectConflictFromList(event) {
    const conflictId = event.target.closest(".conflict-item").dataset.conflictId
    this.selectConflict(conflictId)
  }

  autoResolveFromList(event) {
    const conflictId = event.target.closest(".conflict-item").dataset.conflictId
    this.attemptAutoResolve(conflictId)
  }

  acceptLocal() {
    if (this.selectedConflict) {
      this.resolveConflict(this.selectedConflict.id, {
        strategy: "accept_local",
        content: this.selectedConflict.localChange.content
      })
    }
  }

  acceptRemote() {
    if (this.selectedConflict) {
      this.resolveConflict(this.selectedConflict.id, {
        strategy: "accept_remote",
        content: this.selectedConflict.remoteChange.content
      })
    }
  }

  manualMerge() {
    if (this.selectedConflict && this.hasPreviewPaneTarget) {
      const mergeEditor = this.previewPaneTarget.querySelector(".merge-editor")
      if (mergeEditor) {
        this.resolveConflict(this.selectedConflict.id, {
          strategy: "manual_merge",
          content: mergeEditor.value
        })
      }
    }
  }

  autoResolve() {
    if (this.selectedConflict) {
      this.attemptAutoResolve(this.selectedConflict.id)
    }
  }

  resolveSelectedConflict() {
    if (!this.selectedConflict || !this.selectedResolution) return

    switch (this.selectedResolution) {
    case "accept_local":
      this.acceptLocal()
      break
    case "accept_remote":
      this.acceptRemote()
      break
    case "merge_manual":
      this.manualMerge()
      break
    case "auto_merge":
      this.autoResolve()
      break
    }
  }

  closeDialog() {
    this.hideConflictDialog()
  }

  // Utility methods
  isAutoResolvable(conflictData) {
    const { type, localChange, remoteChange } = conflictData

    // Define which conflict types can be auto-resolved
    const autoResolvableTypes = [
      "insert_insert",
      "delete_modify",
      "move_modify"
    ]

    if (!autoResolvableTypes.includes(type)) {
      return false
    }

    // Additional checks based on content
    if (type === "modify_modify") {
      // Only auto-resolvable if changes don't overlap
      return !this.changesOverlap(localChange, remoteChange)
    }

    return true
  }

  changesOverlap(change1, change2) {
    // Check if two changes overlap in their affected ranges
    const range1 = { start: change1.position, end: change1.position + change1.length }
    const range2 = { start: change2.position, end: change2.position + change2.length }

    return range1.start < range2.end && range2.start < range1.end
  }

  formatConflictType(type) {
    const typeMap = {
      "insert_insert": "Concurrent Insertions",
      "modify_modify": "Concurrent Modifications",
      "delete_modify": "Delete vs Modify",
      "move_modify": "Move vs Modify",
      "move_delete": "Move vs Delete"
    }

    return typeMap[type] || type
  }

  formatTimestamp(timestamp) {
    return new Date(timestamp).toLocaleTimeString()
  }

  updateConflictCount() {
    const count = this.activeConflicts.size
    this.dispatch("conflict:count:changed", { detail: { count } })
  }

  checkForResolvedConflicts(operation) {
    // Implementation would check if the operation resolves any existing conflicts
    // This is a simplified version
    this.activeConflicts.forEach((conflict, conflictId) => {
      if (this.operationResolvesConflict(operation, conflict)) {
        this.removeConflict(conflictId)
      }
    })
  }

  operationResolvesConflict(operation, conflict) {
    // Simplified check - in reality this would be more sophisticated
    return operation.position === conflict.position && 
           operation.type === "replace"
  }

  escapeHtml(text) {
    const div = document.createElement("div")
    div.textContent = text
    return div.innerHTML
  }

  // Public API
  getActiveConflicts() {
    return Array.from(this.activeConflicts.values())
  }

  getConflictCount() {
    return this.activeConflicts.size
  }

  hasUnresolvedConflicts() {
    return this.activeConflicts.size > 0
  }

  // Cleanup
  cleanup() {
    this.activeConflicts.clear()
    this.resolutionHistory.clear()
    this.pendingResolutions.clear()
    this.selectedConflict = null
    this.selectedResolution = null
  }
}