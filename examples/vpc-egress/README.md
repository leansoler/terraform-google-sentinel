# Private VPC Direct Egress Example (`examples/vpc-egress`)

Deploys Sentinel inside a customer GCP project with **Cloud Run Direct VPC Egress** (`vpc_network_name` and `vpc_subnetwork_name`), allowing `@sentinel/control-plane` readiness probes and `@sentinel/agent-runner` browser workers to verify internal VPC staging endpoints without exposing them to the public internet.

## Usage

```bash
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform apply
```
