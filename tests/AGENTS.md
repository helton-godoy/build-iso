# tests/ - Test Suite

**Purpose:** Automated validation of installer components and project structure  
**Pattern:** Individual test files + main test suite

## STRUCTURE
```
tests/
├── test_installer.sh    # Main suite (375 lines)
├── test_*.sh           # Individual validators
└── test_vm_*.sh        # VM-specific tests
```

## TEST NAMING
- `test_*.sh` - General tests
- `test_vm_*.sh` - VM validation tests
- `test_iso_*.sh` - ISO build tests

## PATTERN
```bash
#!/usr/bin/env bash
set -euo pipefail

TESTS_PASSED=0
TESTS_FAILED=0

report_test() {
    local test_name="$1"
    local result="$2"    # "PASS" or "FAIL"
    local details="${3-}"
    
    if [[ ${result} == "PASS" ]]; then
        echo "[PASS] ${test_name}"
        ((TESTS_PASSED++))
    else
        echo "[FAIL] ${test_name}"
        [[ -n ${details} ]] && echo "       ${details}"
        ((TESTS_FAILED++))
    fi
}
```

## RUNNING TESTS
```bash
# All tests
bash tests/test_installer.sh

# Individual test
bash tests/test_project_structure.sh

# With CI flag (silences interactive prompts)
CI=true bash tests/test_installer.sh
```

## KEY TESTS
| File | Purpose |
|------|---------|
| `test_installer.sh` | Main suite: shebang, permissions, modules |
| `test_project_structure.sh` | Directory structure validation |
| `test_vm_kvm.sh` | KVM support validation |
| `test_vm_uefi.sh` | UEFI firmware validation |
| `test_lb_config.sh` | Live-build config validation |

## NOTES
- test_installer.sh is the comprehensive suite (run in CI)
- Individual tests exit 1 on failure
- Main suite continues after failures to report all results
