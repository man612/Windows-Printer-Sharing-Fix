# Contributing to Windows Printer Sharing Fix

Thank you for your interest in improving this project! Contributions help make this utility more reliable for everyone.

## Guidelines

- Keep the Batch script compatible with Windows 7 through Windows 11 where practical.
- Add version checks before using commands that only exist on newer Windows versions.
- Use `net stop` and `net start` carefully.
- Always include logging for new actions.
- Avoid hiding critical errors.
- Test your changes on multiple Windows versions if possible.

## How to Contribute

1. **Report Bugs**: Open an issue with your Windows version, error code, and log output.
2. **Feature Requests**: Open an issue to discuss new repair steps.
3. **Pull Requests**:
   - Fork the repository.
   - Create a new branch for your fix.
   - Submit a pull request with a clear description of the change.

Please keep the script style simple and readable. Avoid unnecessary external dependencies.
