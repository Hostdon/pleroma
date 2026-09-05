# Optimizing PostgreSQL performance

Akkoma performance is largely dependent on performance of the underlying database. Better performance can be achieved by adjusting a few settings.

## PGTune

[PgTune](https://pgtune.leopard.in.ua) can be used to get recommended settings. Make sure to set the DB type to "Online transaction processing system" for optimal performance. Also set the number of connections to between 25 and 30. This will allow each connection to have access to more resources while still leaving some room for running maintenance tasks while the instance is still running. 

It is also recommended to not use "Network Storage" option.

If your server runs other services, you may want to take that into account. E.g. if you have 4G ram, but 1G of it is already used for other services, it may be better to tell PGTune you only have 3G.

In the end, PGTune only provides recommended settings, you can always try to finetune further.
