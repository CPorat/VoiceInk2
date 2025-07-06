---
description: 
globs: 
alwaysApply: false
---
# Subagent Task List Management

Guidelines for managing task lists in markdown files using Claude Code subagents to efficiently track and complete PRD implementation

## Subagent Coordination Strategy

### Task Assignment
- **Parallel execution:** Multiple subagents can work on independent sub-tasks simultaneously
- **Dependency awareness:** Subagents must check for task dependencies before starting work
- **Conflict prevention:** Only one subagent per file/component to avoid merge conflicts

### Coordination Protocol
1. **Task claiming:** Subagents must "claim" tasks by marking them as `[in-progress]` before starting
2. **Status communication:** Subagents update task status in real-time in the shared task list
3. **Dependency checking:** Before claiming a task, verify all prerequisite tasks are `[x]` completed
4. **Resource coordination:** Check if required files are currently being modified by other subagents

## Task Implementation

### Individual Subagent Workflow
- **Claim before work:** Change `[ ]` to `[in-progress]` and add your subagent identifier
- **Work completion:** Change `[in-progress]` to `[x]` when finished
- **Parent task updates:** Mark parent tasks as `[x]` only when ALL subtasks are completed
- **Handoff communication:** Leave notes for dependent tasks about implementation details

### Main Agent Oversight
- **Batch approval:** User approves groups of related sub-tasks rather than individual ones
- **Progress monitoring:** Main agent monitors overall progress and resolves conflicts
- **Quality gates:** User approval required before major milestones (e.g., completing full features)

## Task List Syntax

```markdown
- [ ] Parent Task Name
  - [in-progress:agent-1] Sub-task being worked on
  - [x] Completed sub-task
  - [ ] Available sub-task
  - [blocked:waiting-for-api] Blocked sub-task with reason
```

## Subagent Responsibilities

### Before Starting Work
1. **Scan dependencies:** Ensure prerequisite tasks are completed
2. **Check resource conflicts:** Verify target files aren't being modified
3. **Claim the task:** Update status to `[in-progress:your-id]`
4. **Communicate blockers:** If task can't start, mark as `[blocked:reason]`

### During Work
1. **Update progress:** Add implementation notes for complex tasks
2. **Flag dependencies:** Create new dependent tasks as they're discovered
3. **Coordinate changes:** Communicate with other subagents about shared components

### After Completion
1. **Mark completed:** Change to `[x]` and timestamp if needed
2. **Update parent status:** Check if parent task can now be marked complete
3. **Document deliverables:** Update "Relevant Files" section
4. **Notify dependents:** Alert other subagents of completed work

## Task List Maintenance

### Real-time Updates
- **Status synchronization:** All subagents update the shared task list immediately
- **New task discovery:** Add tasks as `[ ]` with appropriate parent/child relationships
- **Blocker resolution:** Remove `[blocked:]` status when impediments are cleared

### File Tracking
- **Comprehensive logging:** Every file created, modified, or deleted must be documented
- **Ownership tracking:** Note which subagent is responsible for each file
- **Integration points:** Highlight files that multiple subagents will interact with

## Conflict Resolution

### File Conflicts
- **Prevention first:** One subagent per file whenever possible
- **Communication channels:** Use task comments for coordination
- **Merge strategy:** Main agent resolves conflicts when unavoidable

### Task Dependencies
- **Explicit mapping:** Mark dependencies clearly in task descriptions
- **Unblocking protocol:** Completed tasks must notify all dependent tasks
- **Cascade updates:** Parent task completion triggers child task availability

## Quality Control

### Subagent Checkpoints
- **Self-validation:** Each subagent validates their work before marking complete
- **Integration testing:** Test interactions with other subagent deliverables
- **Documentation standards:** Maintain consistent code and documentation quality

### Main Agent Reviews
- **Progress audits:** Regular review of subagent work and task status
- **Integration oversight:** Ensure subagent work integrates properly
- **User communication:** Provide consolidated progress reports to user

## Example Workflow

```markdown
## Feature Implementation: User Authentication

- [ ] Authentication System
  - [x] Database schema design
  - [in-progress:auth-agent] JWT token service
  - [blocked:waiting-for-schema] User model implementation
  - [ ] Password hashing utilities
  - [ ] Login endpoint
  - [ ] Registration endpoint

- [ ] Frontend Integration  
  - [in-progress:ui-agent] Login form component
  - [ ] Authentication context
  - [ ] Route protection
```

## Relevant Files

Format: `[Status] filename.ext - Description (Owner: subagent-id)`

- [Complete] auth/schema.sql - Database tables for users (Owner: db-agent)
- [In Progress] auth/jwt-service.js - Token generation/validation (Owner: auth-agent)
- [In Progress] components/LoginForm.jsx - User login interface (Owner: ui-agent)