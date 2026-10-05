// Eseguito da mongo la prima volta che parte (come mysql-init/ per MySQL): crea il database "app"
// con due collezioni, un indice e un utente applicativo.
db = db.getSiblingDB('app');

db.utenti.insertMany([
    { _id: 1, nome: 'Anna',  citta: 'Roma',   eta: 31, tag: ['admin', 'dev'] },
    { _id: 2, nome: 'Bruno', citta: 'Milano', eta: 45, tag: ['dev'] },
    { _id: 3, nome: 'Carla', citta: 'Roma',   eta: 28, tag: [] },
    { _id: 4, nome: 'Dario', citta: 'Torino', eta: 52, tag: ['ops'] },
    { _id: 5, nome: 'Elena', citta: 'Milano', eta: 39, tag: ['dev', 'ops'] },
]);

db.ordini.insertMany([
    { utente: 1, totale: 120.5, stato: 'pagato',   righe: [{ sku: 'A1', qta: 2 }, { sku: 'B2', qta: 1 }] },
    { utente: 1, totale: 15,    stato: 'spedito',  righe: [{ sku: 'C3', qta: 1 }] },
    { utente: 2, totale: 80,    stato: 'pagato',   righe: [{ sku: 'A1', qta: 1 }] },
    { utente: 3, totale: 42.9,  stato: 'annullato', righe: [{ sku: 'B2', qta: 3 }] },
    { utente: 5, totale: 300,   stato: 'pagato',   righe: [{ sku: 'A1', qta: 5 }, { sku: 'C3', qta: 2 }] },
    { utente: 5, totale: 9.9,   stato: 'spedito',  righe: [{ sku: 'C3', qta: 1 }] },
]);

db.utenti.createIndex({ citta: 1 });

// utente applicativo: legge e scrive solo nel database "app"
db.createUser({ user: 'app', pwd: 'app', roles: [{ role: 'readWrite', db: 'app' }] });
