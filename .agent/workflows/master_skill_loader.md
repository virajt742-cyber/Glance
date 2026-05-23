# Master Skill Loader

This file controls how Antigravity selects and loads skills dynamically.

Instead of loading every skill at startup, the AI should choose only the relevant skills based on the user's task.

---

# Skill Selection Rules

Before solving any task:

1. Analyze the user request.
2. Identify the category of the task.
3. Load only the relevant skills.
4. Ignore unrelated skills.

Never load all skills at once.

---

# Skill Categories

## Architecture & System Design

Use these skills when designing systems or planning architecture:

* backend-architect
* architecture
* architecture-patterns
* cloud-architect
* api-design-principles

---

## AI / Agent Development

Use these skills for AI tools and LLM projects:

* ai-agent-development
* ai-engineer
* agent-memory-systems
* agent-orchestration-improve-agent
* autonomous-agent-patterns
* llm-application-dev-prompt-optimize

---

## Coding Standards

Use when writing or improving code:

* clean-code
* code-reviewer
* code-refactoring-refactor-clean
* code-simplifier

---

## Debugging

Use when fixing bugs or errors:

* debugging-toolkit-smart-debug
* error-diagnostics-smart-debug
* bug-hunter
* debugging-strategies
* find-bugs

---

## Backend Development

Use for API or backend work:

* backend-architect
* async-python-patterns
* fastapi-pro
* database-architect
* database-optimizer

---

## UI / Frontend

Use for interface or design tasks:

* frontend-developer
* frontend-design
* baseline-ui
* canvas-design
* interactive-portfolio

---

## DevOps

Use for infrastructure and deployment:

* docker-expert
* deployment-engineer
* cloud-devops
* kubernetes-architect

---

# Skill Activation Strategy

For every task:

1. Identify the main category.
2. Activate only 3–6 relevant skills.
3. Solve the task using those skills.
4. Unload the skills after completion.

---

# Example

Task: "Build a Flask API"

Skills to activate:

* backend-architect
* api-design-principles
* clean-code
* database-architect

---

Task: "Debug Python code"

Skills to activate:

* debugging-toolkit-smart-debug
* error-diagnostics-smart-debug
* bug-hunter

---

Task: "Design UI dashboard"

Skills to activate:

* frontend-developer
* baseline-ui
* canvas-design
* interactive-portfolio
