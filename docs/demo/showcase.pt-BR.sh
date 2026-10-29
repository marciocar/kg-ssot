#!/usr/bin/env bash
# A vitrine do KG-SSOT em pt-BR: a mesma do showcase.sh, com os comentários e a saída das ferramentas em português. Uma
# afirmação sustentada por um teste que roda, uma mudança no código que tira o chão dela, e o grafo dizendo que decisão
# revisitar. Precisa do kit publicado (pip install kg-ssot) e roda numa pasta temporária nova.
# Gravada com: asciinema rec --window-size 120x32 --command "bash docs/demo/showcase.pt-BR.sh" showcase.cast
#              agg --theme monokai showcase.cast docs/demo/kg-ssot-showcase.pt-BR.gif
set -euo pipefail
export KG_SSOT_LANG=pt-BR
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
     label: "Repetir um pagamento duas vezes com a mesma chave cobra uma vez só.", trace: "tests/test_retry.py",
     verified_at: "2026-10-28", verified_against: "python -m unittest tests.test_retry",
     provenance: {source: "tests/test_retry.py", locator: "test_retry_twice_charges_once",
                  method: "measurement: python -m unittest tests.test_retry"}}
  - {id: C_RETRY_SAFE, node_type: claim, plane: DEV, status: confirmed, impact: 4, confidence: 0.85,
     label: "A repetição do pagamento é idempotente.", verified_at: "2026-10-28", verified_against: "E_RETRY_TEST",
     provenance: {source: "payments.kg.yaml#E_RETRY_TEST", locator: "#E_RETRY_TEST",
                  method: "derived: do teste que roda"}}
  - {id: D_AUTO_RETRY, node_type: decision, plane: DEV, status: open, impact: 4, confidence: 0.6,
     label: "Repetir automaticamente os pagamentos que falharam.", trace: "src/retry.py"}
  - {id: Q_REFUNDS, node_type: question, plane: DEV, status: open, impact: 5, confidence: 0.9,
     label: "O estorno parcial mantém o livro-razão fechado?"}
edges:
  - {from: E_RETRY_TEST, to: C_RETRY_SAFE, edge_type: SUPPORTS}
  - {from: C_RETRY_SAFE, to: D_AUTO_RETRY, edge_type: SUPPORTS}
  - {from: Q_REFUNDS, to: D_AUTO_RETRY, edge_type: TRACES_TO}
YAML
git add -A; git commit -qm "pagamentos, com a repetição e o grafo dela"

say "1. Uma afirmação com chão: o teste roda e passa"
run "python3 -m unittest -q tests.test_retry 2>&1 | tail -1"
run "kg-validate payments.kg.yaml"
say "De onde vem 'a repetição é segura'? De uma medição, não de uma opinião"
run "kg-query --root . --chain C_RETRY_SAFE"
run "kg-trace check --root ."
say "O backlog de hoje, pela atenção"
run "kg-query --root . --open --sort attention | grep -v '^    '"

say "2. O código muda: uma refatoração tira a chave de idempotência, e o teste dela"
cat > src/retry.py <<'PY'
def charge(order, key=None):
    """Simplificado: cobra o pedido."""
    return f"charged {order}"
PY
git rm -q tests/test_retry.py; git commit -qam "simplifica a repetição"
run "git log --oneline -1"
say "O grafo percebe: a evidência aponta para um arquivo que sumiu"
run "kg-trace check --root . || true"

say "Chega um incidente: um cliente foi cobrado duas vezes"
python3 - <<'PY'
import pathlib
p = pathlib.Path("payments.kg.yaml")
s = p.read_text()
s = s.replace("edges:\n", '''  - {id: E_DOUBLE_CHARGE, node_type: evidence, plane: PROD, status: confirmed, impact: 5, confidence: 0.95,
     label: "O pedido A-7 foi cobrado duas vezes depois de uma repetição.", verified_at: "2026-10-28",
     verified_against: "log de pagamentos, 2026-10-28 14:02",
     provenance: {source: "logs/payments-2026-10-28.log", locator: "A-7", method: "measurement: o log de pagamentos"}}
edges:
  - {from: E_DOUBLE_CHARGE, to: D_AUTO_RETRY, edge_type: REFUTES}
''')
p.write_text(s)
PY
run "grep -n 'E_DOUBLE_CHARGE' payments.kg.yaml"
say "Que decisão viva se apoia no que acabou de cair?"
run "kg-query --root . --revisit"

say "3. O backlog se reordena pela atenção: a decisão contestada vai para a frente"
run "kg-query --root . --open --sort attention | grep -v '^    '"
say "pip install kg-ssot  ·  github.com/marciocar/kg-ssot"
