# Database



Database engine: PostgreSQL 18



## Structure



- migrations/ — SQL-файлы со структурой и изменениями базы.

- seeds/ — тестовые данные для локальной разработки.



## Local database



Database name: self\_storage



## Rules



- Never commit passwords, API keys, or real customer data.

- Schema changes must be saved in version-controlled migrations.

- Test migrations against a clean database before deployment.

