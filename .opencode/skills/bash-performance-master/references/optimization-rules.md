# Optimization rules

## Evidence

First establish identical output, relevant stderr, exit status, side effects, ordering, signal behavior, and accepted inputs. Then measure a representative workload.

## Safe local candidates

For small scalar values, consider `${#value}`, glob-pattern trimming/substitution, `printf -v`, and validated integer arithmetic. Quote final expansions.

## Static multi-line output

Emit a static menu, usage block, or banner with one builtin invocation instead of one `echo` per line. Prefer `printf '%s\n' 'line 1\nline 2'` with literal newlines inside the single-quoted argument. This preserves the text exactly and avoids `echo` portability differences involving `-n`, `-e`, and backslashes. Use separate `printf` calls when output is conditional, sent to different file descriptors, or produced incrementally; do not combine unrelated output merely to reduce command count. For large text assets, localization, or generated content, choose an appropriate file or streaming mechanism instead.

## Scaling hazards

- Do not read large files into variables.
- Prefer one streaming process over an external command per record.
- Avoid unbounded brace expansion and large arrays.
- Reject micro-optimizations that obscure error handling.

## Benchmark protocol

Verify equivalence, warm appropriately, run multiple iterations, compare medians and variance, record versions/locale/input/machine, and measure memory when materializing input. Keep the clearer form unless the measured gain matters.
