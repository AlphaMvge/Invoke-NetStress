# Contributing to Invoke-NetStress

We welcome contributions to `Invoke-NetStress`! Please follow these guidelines to help keep the project clean, reliable, and secure.

## Development Workflow

1. Fork the repository and create your feature branch (`git checkout -b feature/awesome-feature`).
2. Adhere to PowerShell best practices and styling rules:
   - Use standard approved verbs (`Get`, `Invoke`, `Test`, `Set`, `Assert`).
   - Maintain cross-compatibility between Windows PowerShell 5.1 and PowerShell 7+ (Core).
   - Ensure hardware-level safety: all background Runspaces and cancellation tokens must properly clean up on exit.
3. Run the Pester test suite before committing:
   ```powershell
   Invoke-Pester -Path .\tests\Invoke-NetStress.Tests.ps1
   ```
4. Run `PSScriptAnalyzer`:
   ```powershell
   Invoke-ScriptAnalyzer -Path .\Invoke-NetStress.ps1 -Recurse
   ```
5. Commit your changes (`git commit -m 'feat: add support for custom HTTP headers'`).
6. Push to the branch (`git push origin feature/awesome-feature`) and open a Pull Request.

## Pull Request Guidelines

- Describe the problem your PR solves and test results.
- Ensure all CI workflow checks pass.
- Update `README.md` if parameters or command behaviors change.
