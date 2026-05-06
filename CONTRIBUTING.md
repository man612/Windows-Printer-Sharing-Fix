# Contributing to Windows Printer Sharing Fix

Thank you for your interest in improving this utility!

## How Can I Contribute?

### Reporting Bugs
- Use the **Bug Report** issue template.
- Include your Windows version (e.g., Windows 10 22H2).
- Attach the `printer_fix_log.txt` (remove any sensitive info).

### Suggesting Enhancements
- Use the **Feature Request** issue template.
- Explain how the new fix helps and which error code it targets.

### Pull Requests
1. Fork the repo.
2. Create your feature branch (`git checkout -b feature/AmazingFix`).
3. Commit your changes (`git commit -m 'Add support for Error X'`).
4. Push to the branch (`git push origin feature/AmazingFix`).
5. Open a Pull Request.

## Coding Standards
- Keep the Batch script compatible with Windows 10/11.
- Use `net stop/start` carefully.
- Always include logging for new actions.
