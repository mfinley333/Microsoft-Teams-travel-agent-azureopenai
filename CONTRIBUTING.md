# Contributing to Travel Agent Bot

Thank you for your interest in contributing to the Travel Agent Bot project! ??

## ?? How to Contribute

We welcome contributions in the form of:
- ?? Bug reports
- ? Feature requests
- ?? Documentation improvements
- ?? Code contributions
- ?? Test coverage improvements

## ?? Getting Started

### 1. Fork and Clone

1. Fork this repository on GitHub
2. Clone your fork locally:
```bash
git clone https://github.com/YOUR_USERNAME/travel-agent.git
cd travel-agent
```

### 2. Set Up Development Environment

Follow the setup instructions in [README.md](README.md):
- Install .NET 9 SDK
- Install Microsoft 365 Agents Toolkit
- Configure Azure OpenAI access
- Set up environment variables

### 3. Create a Branch

Create a feature branch for your work:
```bash
git checkout -b feature/your-feature-name
# or
git checkout -b fix/issue-number-description
```

Branch naming conventions:
- `feature/` - New features
- `fix/` - Bug fixes
- `docs/` - Documentation updates
- `refactor/` - Code refactoring
- `test/` - Test improvements

## ?? Development Guidelines

### Code Style

- Follow [C# Coding Conventions](https://learn.microsoft.com/en-us/dotnet/csharp/fundamentals/coding-style/coding-conventions)
- Use meaningful variable and method names
- Add XML documentation comments for public APIs:
```csharp
/// <summary>
/// Brief description of what this method does.
/// </summary>
/// <param name="paramName">Description of parameter</param>
/// <returns>Description of return value</returns>
public string MethodName(string paramName)
{
    // implementation
}
```

### Code Standards

- ? Use `async`/`await` for asynchronous operations
- ? Handle exceptions appropriately
- ? Add logging for important operations
- ? Validate input parameters
- ? Use dependency injection
- ? Follow SOLID principles

### Testing

- Add unit tests for new functionality
- Ensure all existing tests pass:
```bash
dotnet test
```
- Test manually in Teams before submitting

### Documentation

- Update README.md if adding new features
- Add inline comments for complex logic
- Update API documentation
- Include screenshots for UI changes

## ?? Security

### Never Commit Secrets

Before committing, always check:

```bash
# Verify no secrets are staged
git status

# Search for potential secrets
git diff --staged | grep -i "secret\|api[_-]key\|password"
```

### Files to Never Commit

These are already in `.gitignore`:
- `M365Agent/env/.env.*.user`
- `M365Agent/env/.env.local*`
- `TravelAgent/appsettings.Development.json`
- Any file with `crypto_*` values

### Reporting Security Issues

If you discover a security vulnerability:
1. **DO NOT** open a public issue
2. Email the maintainers directly (see README for contact)
3. Include details about the vulnerability
4. Wait for a response before disclosing publicly

## ?? Pull Request Process

### 1. Before Submitting

- [ ] Code builds without errors
- [ ] All tests pass
- [ ] No secrets are committed
- [ ] Code follows style guidelines
- [ ] Documentation is updated
- [ ] Commits are meaningful and well-organized

### 2. Commit Messages

Write clear commit messages:

```
Add feature to calculate travel budget

- Add TravelBudgetCalculator class
- Integrate with Azure OpenAI for cost estimates
- Add unit tests for budget calculations
- Update documentation

Closes #123
```

Format:
- First line: Brief description (50 chars max)
- Blank line
- Detailed description with bullet points
- Reference issue numbers

### 3. Create Pull Request

1. Push your branch to your fork:
```bash
git push origin feature/your-feature-name
```

2. Go to GitHub and click **New Pull Request**

3. Fill in the PR template:
   - **Title**: Clear, concise description
   - **Description**: What changes were made and why
   - **Issue**: Link to related issue(s)
   - **Testing**: How you tested the changes
   - **Screenshots**: If applicable

4. Request review from maintainers

### 4. Code Review

- Respond to feedback promptly
- Make requested changes
- Push updates to your branch (PR will update automatically)
- Re-request review after making changes

### 5. Merging

- Maintainers will merge after approval
- Squash commits if needed
- Delete branch after merge

## ?? Reporting Bugs

When reporting bugs, include:

1. **Description**: Clear description of the bug
2. **Steps to Reproduce**:
   ```
   1. Go to '...'
   2. Click on '...'
   3. See error
   ```
3. **Expected Behavior**: What should happen
4. **Actual Behavior**: What actually happens
5. **Environment**:
   - OS: Windows 11
   - .NET Version: 9.0
   - Browser: Edge
6. **Logs**: Include relevant error messages or logs
7. **Screenshots**: If applicable

## ? Requesting Features

For feature requests, provide:

1. **Use Case**: Why is this feature needed?
2. **Proposed Solution**: How should it work?
3. **Alternatives**: Other solutions you've considered
4. **Additional Context**: Screenshots, mockups, examples

## ?? Resources

- [.NET Documentation](https://learn.microsoft.com/en-us/dotnet/)
- [Azure OpenAI Documentation](https://learn.microsoft.com/en-us/azure/ai-services/openai/)
- [Microsoft Teams Platform](https://learn.microsoft.com/en-us/microsoftteams/platform/)
- [Microsoft 365 Agents Toolkit](https://learn.microsoft.com/en-us/microsoftteams/platform/toolkit/teams-toolkit-fundamentals)

## ?? Communication

- **Questions**: Open a [Discussion](https://github.com/YOUR_USERNAME/travel-agent/discussions)
- **Bugs**: Open an [Issue](https://github.com/YOUR_USERNAME/travel-agent/issues)
- **Ideas**: Start a [Discussion](https://github.com/YOUR_USERNAME/travel-agent/discussions)

## ?? Code of Conduct

### Our Pledge

We are committed to providing a welcoming and inspiring community for all.

### Our Standards

? **Do:**
- Be respectful and constructive
- Welcome newcomers
- Give and accept constructive feedback gracefully
- Focus on what is best for the community

? **Don't:**
- Use inappropriate language or imagery
- Troll, insult, or make derogatory comments
- Harass others publicly or privately
- Publish others' private information

### Enforcement

Violations can be reported to the maintainers. All reports will be reviewed and investigated.

## ??? Recognition

Contributors will be recognized in:
- README.md contributors section
- Release notes
- Project documentation

## ? Questions?

If you have questions about contributing:
1. Check existing [Discussions](https://github.com/YOUR_USERNAME/travel-agent/discussions)
2. Review this document again
3. Open a new Discussion

---

**Thank you for contributing! ??**

Your contributions make this project better for everyone.
