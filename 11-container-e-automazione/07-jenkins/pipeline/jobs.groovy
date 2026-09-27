// Job DSL: crea un job Pipeline per ogni file *.jenkinsfile di questa cartella (montata in /lab/pipeline).
// Lo esegue casc.yaml all'avvio di Jenkins e a ogni "Reload existing configuration":
// per aggiungere un esempio basta aggiungere un file e ricaricare.
new File('/lab/pipeline').listFiles()
    .findAll { it.name.endsWith('.jenkinsfile') }
    .sort { it.name }
    .each { file ->
        pipelineJob(file.name - '.jenkinsfile') {
            description("Definito in 07-jenkins/pipeline/${file.name}")
            definition {
                cps {
                    script(file.text)
                    sandbox()          // Groovy in sandbox: niente accesso libero alle API interne di Jenkins
                }
            }
        }
    }
