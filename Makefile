.PHONY: plan apply destroy ssh connect init

init:
	terraform init

plan:
	terraform plan

apply:
	terraform apply -auto-approve

destroy:
	terraform destroy -auto-approve

ssh:
	@terraform output -raw ssh_connection_string

connect:
	@eval $$(terraform output -raw ssh_connection_string)
