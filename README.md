## To deploy this IAC configuration:

```bash
git clone https://github.com/rubaiat-hossain/terraform-aws-automation
cd terraform-aws-automation

export AWS_ACCESS_KEY_ID="anaccesskey"
export AWS_SECRET_ACCESS_KEY="asecretkey"

terraform init
terraform plan
terraform apply

terraform destroy
```
