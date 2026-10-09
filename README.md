# KG-SSOT

O contrato formal do `.kg.yaml`: um JSON Schema 2020-12 em dois níveis (MUST reprova, SHOULD alerta), uma suíte
de conformidade em dados puros que todo leitor tem de passar, um leitor de referência em Python e um kit de
adoção (vendor por tag e gate por grafo no CI).

Este repositório é o **espelho das releases**: cada commit é uma tag `contract-vX.Y.Z`, e nada é editado aqui.

- Como adotar: [`ADOPTING.md`](ADOPTING.md).
- O contrato: `spec/kg-contract-v*.schema.json` (o vigente está em [`spec/release.json`](spec/release.json)).
- A suíte: [`spec/conformance/`](spec/conformance/README.md).
- Licença: Apache-2.0 ([`LICENSE`](LICENSE), escopo no [`NOTICE`](NOTICE)).

Release atual: `contract-v4.3.0`.
