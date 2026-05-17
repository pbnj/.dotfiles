# api

Make raw GraphQL API requests against the Linear API.

```bash
linear api '{ viewer { name email } }'
linear api --variable key=value QUERY
linear api --variables-json '{"id":"abc"}' QUERY
linear api --silent MUTATION                        # Suppress response output
linear api --paginate 'query($after: String) {
  issues(first: 50, after: $after) {
    nodes { id }
    pageInfo { hasNextPage endCursor }
  }
}'
```

| Flag               | Description                                                                       |
| ------------------ | --------------------------------------------------------------------------------- |
| `--variable`       | Variable as `key=value`; coerces booleans, numbers, null; `@file` reads from path |
| `--variables-json` | JSON object of variables; merged with `--variable` (which takes precedence)       |
| `--paginate`       | Auto-paginate a single connection field using cursor pagination                   |
| `--silent`         | Suppress response output (exit code still reflects errors)                        |
