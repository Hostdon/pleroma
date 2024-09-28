# Monitoring Akkoma

If you run akkoma, you may be inclined to collect metrics to ensure your instance is running smoothly,
and that there's nothing quietly failing in the background.

To facilitate this, akkoma exposes prometheus metrics to be scraped.

## Prometheus

See: [export\_prometheus\_metrics](../../configuration/cheatsheet#instance)

To scrape prometheus metrics, we need an oauth2 token with the `admin:metrics` scope.

consider using [constanze](https://akkoma.dev/AkkomaGang/constanze) to make this easier -

```bash
constanze token --client-app --scopes "admin:metrics" --client-name "Prometheus"
```

or see `scripts/create_metrics_app.sh` in the source tree for the process to get this token.

Once you have your token of the form `Bearer $ACCESS_TOKEN`, you can use that in your prometheus config:

```yaml
- job_name: akkoma
  scheme: https
  authorization:
    credentials: $ACCESS_TOKEN # this should have the bearer prefix removed
  metrics_path: /api/v1/akkoma/metrics
  static_configs:
  - targets:
    - example.com
```
