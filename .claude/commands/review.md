---
name: review
description: Perform a comprehensive PR review with code analysis, best practices check, and suggestions
allowed-tools: mcp__github*__get_pull_request, Bash(git add:*), Bash(git status:*), Bash(git commit:*)
---
 Please perform a comprehensive pull request review following these steps:

1. Context
- Current git status: !`git status`
- Current git diff (staged and unstaged changes): !`git diff HEAD`
- Current branch: !`git branch --show-current`
- Recent commits: !`git log --online -10`

2. Fetch PR information
- Use Github MCP tools (`mcp__github_get_pull_requests`) to get PR details
- Get PR files changed with `mcp__github__get_pull_request_files`
- Retrieve PR diff using `mcp__github__get_pull_request_diff`
- Check existing reviews with `mcp__github__get_pull_request_reviews`
- Alternative: Use `git fetch` and `git diff origin/main...feature-branch` if needed

3. Code Analysis
- Read changed files using file reading tools
- Check code quality and style consistency
- Identify potential bugs or issues
- Review error handling and edge cases
- Evaluate performance implications
- Check for security vulnerabilities
- Run linting commands if available (`npm run lint`, etc.)

4. Best Practices Review
- Verify adherence to project conventions
- Check naming conventions and code patterns
- Review code organization and structure
- Evaluate test coverage if tests are included
- Check documentation and comments
- Verify commit message follow conventions

5. Architecture & Design
- Assess if changes align with existing architecture
- Review dependency management
- Check for code duplication
- Evaluate maintainability and scalability
- Consider backward compatibility

6. Git History Analysis
- Use `git log --online -n 10` to check recent commits
- Review commit structure and messages
- Check for clean, logical commit organization

7. Provide Feedback
- List ciritical issues that must be fixed
- Suggest improvments and optimizations
- Highlight good practices used
- Provide specific, actionable feedback with code exmaples
- Use `mcp__github__add_pull_request_review_comment_to_pending_review` for inilne comments if required

8. Summary & Actions
- Overall assessment (Approve/Requst Changes/Comment)
- Key points for the author to address
- Positive aspects of the implementation
- Optionally create/submit review using Github MCP tools if required

Available Tools:
- Github MCP: `get_pull_request`, `get_pull_request_files`, `get_pull_request_diff`, `git_pull_request_reviews`
- GIt commands: `git status`, `git diff`, `git log`, `git show`, `git fetch`
- File operations: Read files, analyze code structure
- Linting: Run project-specific lint/test commands
