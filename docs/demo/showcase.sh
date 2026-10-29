#!/usr/bin/env bash
# The KG-SSOT showcase: a claim held up by a test that runs, then a code change that pulls the ground from under it,
# and the graph says which decision to revisit. It needs the published kit (pip install kg-ssot) and runs in a fresh
# temporary folder.
# Recorded with: asciinema rec --window-size 120x32 --command "bash docs/demo/showcase.sh" showcase.cast
#                agg --theme monokai showcase.cast docs/demo/kg-ssot-showcase.gif
set -euo pipefail
pause() { sleep "${DEMO_PAUSE:-1.6}"; }
say() { printf '\n\033[1;36m# %s\033[0m\n' "$1"; pause; }
run() { printf '\033[1;32m$\033[0m %s\n' "$*"; pause; eval "$@"; pause; }

work=$(mktemp -d); cd "$work"; git init -q; git config user.email demo@example.com; git config user.name demo
mkdir -p src tests
cat > src/retry.py <<'PY'
_seen = {}


def charge(order, key):
    """Charge an order once per idempotency key, however many times it is retried."""
    if key not in _seen:
        _seen[key] = f"charged {order}"
    return _seen[key]
PY
cat > tests/test_retry.py <<'PY'
import unittest
from src import retry


class Retry(unittest.TestCase):
    def test_retry_twice_charges_once(self):
        retry._seen.clear()
        retry.charge("A-1", "k1")
        retry.charge("A-1", "k1")
        self.assertEqual(len(retry._seen), 1)
PY
touch src/__init__.py tests/__init__.py
cat > payments.kg.yaml <<'YAML'
meta: {schema_version: "1", id: payments}
nodes:
  - {id: E_RETRY_TEST, node_type: evidence, plane: DEV, status: confirmed, impact: 4, confidence: 0.9,
     label: "Retrying a payment twice with the same key charges it once.", trace: "tests/test_retry.py",
     verified_at: "2026-10-28", verified_against: "python -m unittest tests.test_retry",
     provenance: {source: "tests/test_retry.py", locator: "test_retry_twice_charges_once",
                  method: "measurement: python -m unittest tests.test_retry"}}
  - {id: C_RETRY_SAFE, node_type: claim, plane: DEV, status: confirmed, impact: 4, confidence: 0.85,
     label: "The payment retry is idempotent.", verified_at: "2026-10-28", verified_against: "E_RETRY_TEST",
     provenance: {source: "payments.kg.yaml#E_RETRY_TEST", locator: "#E_RETRY_TEST",
                  method: "derived: from the test that runs"}}
  - {id: D_AUTO_RETRY, node_type: decision, plane: DEV, status: open, impact: 4, confidence: 0.6,
     label: "Retry failed payments automatically.", trace: "src/retry.py"}
  - {id: Q_REFUNDS, node_type: question, plane: DEV, status: open, impact: 5, confidence: 0.9,
     label: "Do partial refunds keep the ledger balanced?"}
edges:
  - {from: E_RETRY_TEST, to: C_RETRY_SAFE, edge_type: SUPPORTS}
  - {from: C_RETRY_SAFE, to: D_AUTO_RETRY, edge_type: SUPPORTS}
  - {from: Q_REFUNDS, to: D_AUTO_RETRY, edge_type: TRACES_TO}
YAML
git add -A; git commit -qm "payments, with the retry and its graph"

say "1. A claim with ground under it: the test runs and passes"
run "python3 -m unittest -q tests.test_retry 2>&1 | tail -1"
run "kg-validate payments.kg.yaml"
say "Where does 'the retry is safe' come from? A measurement, not an opinion"
run "kg-query --root . --chain C_RETRY_SAFE"
run "kg-trace check --root ."
say "The backlog today, by attention"
run "kg-query --root . --open --sort attention | grep -v '^    '"

say "2. The code changes: a refactor drops the idempotency key, and its test"
cat > src/retry.py <<'PY'
def charge(order, key=None):
    """Simplified: charge the order."""
    return f"charged {order}"
PY
git rm -q tests/test_retry.py; git commit -qam "simplify the retry"
run "git log --oneline -1"
say "The graph notices: the evidence points at a file that is gone"
run "kg-trace check --root . || true"

say "An incident comes in: a customer was charged twice"
python3 - <<'PY'
import pathlib
p = pathlib.Path("payments.kg.yaml")
s = p.read_text()
s = s.replace("edges:\n", '''  - {id: E_DOUBLE_CHARGE, node_type: evidence, plane: PROD, status: confirmed, impact: 5, confidence: 0.95,
     label: "Order A-7 was charged twice after one retry.", verified_at: "2026-10-28",
     verified_against: "payments log, 2026-10-28 14:02",
     provenance: {source: "logs/payments-2026-10-28.log", locator: "A-7", method: "measurement: the payments log"}}
edges:
  - {from: E_DOUBLE_CHARGE, to: D_AUTO_RETRY, edge_type: REFUTES}
''')
p.write_text(s)
PY
run "grep -n 'E_DOUBLE_CHARGE' payments.kg.yaml"
say "Which live decision stands on what just fell?"
run "kg-query --root . --revisit"

say "3. The backlog reorders by attention: the contested decision goes first"
run "kg-query --root . --open --sort attention | grep -v '^    '"
say "pip install kg-ssot  ·  github.com/marciocar/kg-ssot"
