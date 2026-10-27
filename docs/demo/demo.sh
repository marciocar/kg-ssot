#!/usr/bin/env bash
# The two-minute KG-SSOT demo: write a claim, let the contract catch the missing source, fix it, query the graph and
# turn on the gate. It needs the published kit (pip install kg-ssot) and runs in a fresh temporary folder.
# Recorded with: asciinema rec --cols 100 --rows 28 --command "bash docs/demo/demo.sh" demo.cast
#                agg --theme monokai demo.cast docs/demo/kg-ssot-demo.gif
set -euo pipefail
pause() { sleep "${DEMO_PAUSE:-1.6}"; }
say() { printf '\n\033[1;36m# %s\033[0m\n' "$1"; pause; }
run() { printf '\033[1;32m$\033[0m %s\n' "$*"; pause; eval "$@"; pause; }

work=$(mktemp -d); cd "$work"; git init -q; git config user.email demo@example.com; git config user.name demo

say "A claim marked confirmed, but nobody wrote down where it came from"
cat > backup.kg.yaml <<'YAML'
meta: {schema_version: "1", id: backup-review}
nodes:
  - {id: C_BACKUP_FAST, node_type: claim, plane: DEV, status: confirmed, impact: 4, confidence: 0.9,
     label: "The nightly backup completes in under one hour."}
  - {id: Q_RESTORE, node_type: question, plane: DEV, status: open, impact: 4, confidence: 0.5,
     label: "Is the backup restorable?"}
edges:
  - {from: C_BACKUP_FAST, to: Q_RESTORE, edge_type: TRACES_TO}
YAML
run cat backup.kg.yaml
say "The contract refuses it: a confirmed claim needs provenance"
run "kg-validate backup.kg.yaml || true"

say "Say where it came from: the source, where in it, and how it was checked"
python3 - <<'PY'
import pathlib
p = pathlib.Path("backup.kg.yaml")
p.write_text(p.read_text().replace(
    'label: "The nightly backup completes in under one hour."}',
    'label: "The nightly backup completes in under one hour.",\n'
    '     verified_at: "2026-10-20", verified_against: "logs/backup-2026-10-20.log",\n'
    '     provenance: {source: "logs/backup-2026-10-20.log", locator: "completed in 52m",\n'
    '                  method: "reading: the backup log"}}'))
PY
run "head -7 backup.kg.yaml"
run "kg-validate backup.kg.yaml"

say "Ask the graph: what is still open, most important first?"
run "git add -A && kg-query --root . --open --sort impact"

say "Turn on the gate: from now on, a pull request cannot make a graph worse"
run "kg-gate --update && git add -A && git commit -qm 'kg-ssot gate' && kg-gate"
say "pip install kg-ssot  ·  github.com/marciocar/kg-ssot"
