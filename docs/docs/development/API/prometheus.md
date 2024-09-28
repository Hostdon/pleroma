# Prometheus Metrics

Akkoma includes support for exporting metrics via the [prometheus_ex](https://github.com/deadtrickster/prometheus.ex) library.

Config example:

```
config :pleroma, :instance,
  export_prometheus_metrics: true
```

## `/api/v1/akkoma/metrics`

### Exports Prometheus application metrics

* Method: `GET`
* Authentication: required
* Params: none
* Response: text

## Grafana

### Config example

The following is a config example to use with [Grafana](https://grafana.com)

```
  - job_name: 'beam'
    metrics_path: /api/v1/akkoma/metrics
    scheme: https
    static_configs:
    - targets: ['otp.akkoma.dev']
```
