# Security Policy

## 🔒 Reporting a Vulnerability

**DO NOT** open a public GitHub issue for security vulnerabilities.

Instead, please report security issues privately to:

**Email:** haalbers@gmail.com

**Subject:** `[SECURITY] harm-cli - <brief description>`

### What to Include

Please provide as much information as possible:

1. **Description**: Clear description of the vulnerability
2. **Impact**: What can an attacker do?
3. **Affected Versions**: Which versions are affected?
4. **Reproduction Steps**: How to reproduce the issue
5. **Proof of Concept**: Code or commands demonstrating the issue
6. **Suggested Fix**: If you have ideas for fixing it

### Response Timeline

- **Acknowledgment**: Within 48 hours
- **Initial Assessment**: Within 1 week
- **Status Updates**: Every 2 weeks
- **Fix Timeline**: Depends on severity (see below)

---

## 🚨 Severity Levels

### Critical (Fix within 24-48 hours)

- Remote code execution
- Authentication bypass
- Arbitrary file write/read outside project
- Privilege escalation

### High (Fix within 1 week)

- Information disclosure of secrets
- Denial of service
- Injection vulnerabilities (command, SQL)

### Medium (Fix within 1 month)

- Cross-site scripting (if web UI added)
- Path traversal
- Weak cryptography

### Low (Fix in next release)

- Information disclosure (non-sensitive)
- Minor logic errors

---

## ✅ Security Best Practices (Implemented)

### 1. Input Validation

- All inputs validated before use
- Type checking enforced
- Bounds checking for arrays
- Sanitization of user input

### 2. Safe File Operations

- Atomic writes prevent corruption
- File permissions checked
- No arbitrary path access
- Temp files with restrictive permissions

### 3. Command Execution

- No `eval` usage
- Commands properly quoted
- Subshell execution isolated
- Timeout enforcement

### 4. Dependency Management

- Minimal dependencies
- Dependencies vetted
- SBOM (Software Bill of Materials) generated
- Vulnerability scanning in CI

### 5. Secret Management

- No secrets in code
- No secrets in logs
- Environment variables preferred
- Keychain integration for credentials

---

## 🛡️ Security Features

### Strict Error Handling

```bash
set -Eeuo pipefail  # Fail on errors
IFS=$'\n\t'         # Safe word splitting
```

### Input Sanitization

```bash
# All inputs validated
require_arg "$input" "Input"
validate_int "$count"
validate_format "$format"
```

### Safe Defaults

- Read-only by default
- Explicit confirmation for destructive operations
- Fail-safe on errors
- Atomic operations

### Resource Limits

- Timeouts on external commands
- File size limits
- Process group management

---

## 🔍 Security Scanning

### Automated Checks

- **ShellCheck**: Static analysis for shell scripts
- **Pre-commit hooks**: Prevent common issues
- **CI/CD scans**: Grype for vulnerabilities
- **SBOM generation**: Track all dependencies

### Manual Review

- Code review for all PRs
- Security-focused testing
- Penetration testing (before v1.0)

---

## 📋 Security Checklist for Contributors

Before submitting code:

- [ ] No hardcoded secrets
- [ ] All inputs validated
- [ ] Commands properly quoted
- [ ] Error handling comprehensive
- [ ] File operations atomic
- [ ] Timeouts on external calls
- [ ] No arbitrary code execution
- [ ] No path traversal vulnerabilities
- [ ] Secrets handled securely
- [ ] Tests cover security edge cases

---

## 📚 Known Limitations

### Current Version (0.1.0-alpha)

1. **Alpha software**: Not production-ready
2. **Limited testing**: Security testing in progress
3. **No formal audit**: Independent security audit planned for v1.0

### Planned Improvements

- [ ] Formal security audit
- [ ] Fuzzing tests
- [ ] Penetration testing
- [ ] Security documentation expansion
- [ ] CVE monitoring
- [ ] Automated dependency updates

---

## 🔐 Cryptographic Operations

### Current State

- No cryptographic operations (v0.1.0-alpha)

### Future Plans

If cryptography is added:
- Industry-standard algorithms only
- External libraries (OpenSSL, libsodium)
- No custom crypto implementations
- Regular key rotation

---

## 📞 Contact

**Security Team:** haalbers@gmail.com

**PGP Key:** Coming soon

**Response SLA:**
- Critical: 24-48 hours
- High: 1 week
- Medium: 1 month
- Low: Next release

---

## 🏆 Security Hall of Fame

Contributors who responsibly disclose security issues will be listed here (with permission).

---

**Last Updated:** 2025-10-18
**Version:** 0.1.0-alpha
