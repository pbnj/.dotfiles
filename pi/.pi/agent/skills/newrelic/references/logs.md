# NRQL Query Reference for Logs

The primary table is `Log`. Common fields:

| Field              | Description                            |
| ------------------ | -------------------------------------- |
| `message`          | Raw log message text                   |
| `level`            | Log severity (ERROR, WARN, INFO, etc.) |
| `service.name`     | Name of the emitting service           |
| `hostname`         | Host that emitted the log              |
| `timestamp`        | Event timestamp (auto-used by SINCE)   |
| `trace.id`         | Distributed trace ID                   |
| `span.id`          | Span ID                                |
| `logtype`          | Log type / source category             |
| `container.id`     | Container identifier                   |
| `kubernetes.pod.*` | Kubernetes pod metadata                |

## Useful NRQL clauses

```nrql
-- Time windows
SINCE 30 minutes ago
SINCE '2025-01-01 00:00:00' UNTIL '2025-01-02 00:00:00'

-- Filtering
WHERE message LIKE '%timeout%'
WHERE level IN ('ERROR', 'CRITICAL')
WHERE service.name = 'api-gateway'

-- Aggregation
SELECT count(*) FACET service.name
SELECT uniqueCount(hostname) FACET level
SELECT percentage(count(*), WHERE level = 'ERROR') FROM Log

-- Timeseries
SELECT count(*) FROM Log TIMESERIES 1 hour SINCE 1 day ago

-- Limit
LIMIT 500   -- max 2000 for SELECT *, higher for aggregations
```
