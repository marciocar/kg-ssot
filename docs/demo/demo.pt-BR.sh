#!/usr/bin/env bash
# A demo do KG-SSOT em pt-BR: a mesma do demo.sh, com os comentários e a saída das ferramentas em português. Uma
# afirmação sem fonte, o contrato que a recusa, a correção, a consulta ao grafo e o gate. Precisa do kit publicado
# (pip install kg-ssot) e roda numa pasta temporária nova.
# Gravada com: asciinema rec --cols 100 --rows 28 --command "bash docs/demo/demo.pt-BR.sh" demo.cast
#              agg --theme monokai demo.cast docs/demo/kg-ssot-demo.pt-BR.gif
set -euo pipefail
export KG_SSOT_LANG=pt-BR
pause() { sleep "${DEMO_PAUSE:-1.6}"; }
say() { printf '\n\033[1;36m# %s\033[0m\n' "$1"; pause; }
run() { printf '\033[1;32m$\033[0m %s\n' "$*"; pause; eval "$@"; pause; }

work=$(mktemp -d); cd "$work"; git init -q; git config user.email demo@example.com; git config user.name demo

say "Uma afirmação marcada como confirmada, mas ninguém anotou de onde ela veio"
cat > backup.kg.yaml <<'YAML'
meta: {schema_version: "1", id: backup-review}
nodes:
  - {id: C_BACKUP_FAST, node_type: claim, plane: DEV, status: confirmed, impact: 4, confidence: 0.9,
     label: "O backup noturno termina em menos de uma hora."}
  - {id: Q_RESTORE, node_type: question, plane: DEV, status: open, impact: 4, confidence: 0.5,
     label: "O backup pode ser restaurado?"}
edges:
  - {from: C_BACKUP_FAST, to: Q_RESTORE, edge_type: TRACES_TO}
YAML
run cat backup.kg.yaml
say "O contrato recusa: uma afirmação confirmada precisa de procedência"
run "kg-validate backup.kg.yaml || true"

say "Diga de onde ela veio: a fonte, onde nela, e como foi conferida"
python3 - <<'PY'
import pathlib
p = pathlib.Path("backup.kg.yaml")
p.write_text(p.read_text().replace(
    'label: "O backup noturno termina em menos de uma hora."}',
    'label: "O backup noturno termina em menos de uma hora.",\n'
    '     verified_at: "2026-10-20", verified_against: "logs/backup-2026-10-20.log",\n'
    '     provenance: {source: "logs/backup-2026-10-20.log", locator: "terminou em 52 min",\n'
    '                  method: "reading: o log do backup"}}'))
PY
run "head -7 backup.kg.yaml"
run "kg-validate backup.kg.yaml"

say "Pergunte ao grafo: o que segue aberto, o mais importante primeiro?"
run "git add -A && kg-query --root . --open --sort impact"

say "Ligue o gate: daqui em diante, um pull request não pode piorar um grafo"
run "kg-gate --update && git add -A && git commit -qm 'gate do kg-ssot' && kg-gate"
say "pip install kg-ssot  ·  github.com/marciocar/kg-ssot"
