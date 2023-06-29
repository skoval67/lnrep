terraform apply -auto-approve

terraform output -json > ansible/hosts.json

cd ansible/ && ./gen_inv.py

ansible-playbook playbook.yml
cd ..