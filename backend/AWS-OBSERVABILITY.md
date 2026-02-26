# Constellation Fabrick - AWS Observability Guide

## Components
1. **CloudWatch Logs**: All services log in JSON format to stdout. ECS routes these to CloudWatch.
2. **CloudWatch Metrics**: Metrics are extracted from logs via 'Metric Filters' or EMF.
3. **AWS X-Ray**: Distributed tracing via OpenTelemetry.

## Terraform Requirements
Ensure your ECS Task Role has these permissions:
- logs:CreateLogStream
- logs:PutLogEvents
- xray:PutTraceSegments
- xray:PutTelemetryRecords

