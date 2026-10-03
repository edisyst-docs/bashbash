# 13 - GitHub Actions

| File | Contenuto |
|---|---|
| [github-actions.md](github-actions.md) | Concetti, struttura di un workflow, runner, espressioni e contesti, comandi del runner, eventi, matrix, needs e output, artefatti e cache, servizi, CI completa con Trivy e ghcr.io, ambienti, segreti e OIDC, riuso, la CI di questa KB, sicurezza (SHA, permessi, iniezione di comandi, `pull_request_target`), `act`, `gh`, confronto con Jenkins e GitLab, problemi comuni |
| [app/](app/) | Applicazione Flask con test, usata dagli esempi 03, 05, 07 e 09 |

I workflow stanno dove li cerca GitHub, nella radice del repository:
[../../.github/workflows/](../../.github/workflows/) (nove `esempio-*.yml` e `kb.yml`, la CI della KB) e
[../../.github/actions/python-app/](../../.github/actions/python-app/) (l'Action composita dell'esempio 09).

```bash
gh workflow run esempio-02-eventi.yml -f ambiente=produzione && gh run watch
act workflow_dispatch -W .github/workflows/esempio-01-base.yml -P ubuntu-24.04=catthehacker/ubuntu:act-24.04
```

Torna a [../](../)
