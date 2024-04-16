MIN 34:31 https://www.youtube.com/watch?v=bw6Iq-hIcqo

Voglio collegare il mio webserver `apache+php` (gli ho già fatto installare le librerie) ad un DB mysql.

Serve un altro container `docker pull mysql`

Devo creare due container collegati fra loro: uno basato sul mio `my-php-apache-mysqli` e uno su `mysqli`.

Devo anche settarli: mapping porte e cartelle. In questo caso metto tutto nello YML
