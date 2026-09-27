# 09 - Terraform

| File | Contenuto |
|---|---|
| [terraform.md](terraform.md) | Concetti, installazione, ciclo `init`/`plan`/`apply`/`destroy`, linguaggio HCL (tipi, variabili, espressioni, funzioni, `count`/`for_each`, `dynamic`, `lifecycle`), provider, moduli, stato remoto, `moved`/`import`/`removed`, workspace, pipeline, problemi comuni |
| [01-docker-nginx/](01-docker-nginx/) | Il primo apply: un container nginx con il provider Docker |
| [02-webfarm/](02-webfarm/) | N web server dietro HAProxy: variabili con validazione, `for_each`, `templatefile`, `depends_on`, `replace_triggered_by` |
| [03-moduli/](03-moduli/) | Un modulo locale usato più volte, anche con `for_each` |
| [04-stato/](04-stato/) | Drift, `-replace`, `moved`, `import` con generazione della configurazione, `removed`, workspace |
| [05-aws-ec2/](05-aws-ec2/) | Un server con nginx su AWS: data source, chiave SSH, security group, `user_data`, backend S3 |
| [06-kubernetes/](06-kubernetes/) | Namespace, ConfigMap, Deployment e Service nel cluster kind con il provider `kubernetes` |

Torna a [../](../)
