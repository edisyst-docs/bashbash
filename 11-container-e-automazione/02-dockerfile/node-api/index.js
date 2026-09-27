const express = require('express')
const app = express()
const port = 3000

app.get('/', (req, res) => {
    res.json([
        { name: 'Mario', email: 'mario@example.com' },
        { name: 'Luigi', email: 'luigi@example.com' },
    ])
})

app.listen(port, () => {
    console.log(`API in ascolto sulla porta ${port}`)
})
