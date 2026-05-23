# Antigravity Task Planning Framework

This document defines how the AI should plan and execute complex development tasks before writing code.

The goal is to ensure structured reasoning, proper architecture decisions, and high-quality implementation.

---

# 1. Problem Understanding

Before writing any code, analyze the request carefully.

Steps:

1. Identify the primary goal.
2. Determine the expected output.
3. Identify constraints and requirements.
4. Determine the technology stack involved.
5. Identify missing information.

Questions to consider:

* What is the user trying to build?
* What inputs and outputs are expected?
* Are there existing systems involved?
* What edge cases might occur?

If the problem is unclear, ask clarifying questions.

---

# 2. Task Decomposition

Break the problem into smaller tasks.

Example structure:

Main Goal
│
├ Step 1: Setup environment
├ Step 2: Define architecture
├ Step 3: Implement core logic
├ Step 4: Integrate components
├ Step 5: Test and debug
└ Step 6: Optimize and refactor

Rules:

* Prefer small, independent tasks.
* Avoid solving everything in one step.
* Identify dependencies between tasks.

---

# 3. Architecture Planning

Before implementing a system, design the architecture.

Consider:

* scalability
* maintainability
* performance
* security

Example architecture questions:

* Should the system be modular?
* Are service layers required?
* How should data flow through the system?
* Should caching or async processing be used?

Example architecture structure:

Frontend
↓
API Layer
↓
Business Logic / Services
↓
Database

---

# 4. Implementation Strategy

Define how the solution will be implemented.

Steps:

1. Choose appropriate libraries and frameworks.
2. Define data structures.
3. Define modules and functions.
4. Plan file structure.
5. Plan integration between components.

Example:

Backend project structure:

app/
├ routes/
├ services/
├ models/
├ utils/
└ config/

Guidelines:

* Keep functions small and focused.
* Avoid overly complex logic.
* Use clear naming.

---

# 5. Risk Identification

Before implementing, identify potential problems.

Examples:

* performance bottlenecks
* incorrect assumptions
* missing validation
* concurrency issues
* security vulnerabilities

For each risk, propose mitigation strategies.

Example:

Risk: slow database queries
Mitigation: add indexes and optimize queries

---

# 6. Implementation Phase

After planning is complete:

1. Implement the solution step-by-step.
2. Ensure each component works before moving forward.
3. Use clean and readable code.
4. Follow project coding standards.

Never skip the planning phase.

---

# 7. Debugging Process

If an issue occurs:

1. Analyze the error message.
2. Identify the root cause.
3. Reproduce the issue logically.
4. Apply a minimal fix.
5. Verify that the fix solves the problem.

Avoid guessing fixes without understanding the cause.

---

# 8. Code Review and Refactoring

After implementation:

Check for:

* duplicated logic
* poor variable naming
* large functions
* unclear architecture

Refactor where necessary.

Goals:

* readability
* maintainability
* modular design

---

# 9. Performance Optimization

If performance is important:

Evaluate:

* algorithm complexity
* database queries
* unnecessary loops
* repeated calculations

Strategies:

* caching
* indexing
* async processing
* batching operations

---

# 10. Final Validation

Before finishing a task:

Verify:

* the solution meets the original goal
* edge cases are handled
* code follows project standards
* performance is acceptable

If improvements are possible, suggest them.

---

# Planning Summary Format

When planning a task, output should follow this structure:

1. Problem Understanding
2. Task Breakdown
3. Architecture Plan
4. Implementation Strategy
5. Risks & Mitigation
6. Implementation
7. Debugging
8. Refactoring
9. Optimization
10. Final Result
