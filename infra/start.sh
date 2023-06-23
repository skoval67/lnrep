terraform apply -auto-approve

terraform output -json > ansible/hosts.json

cd ansible/ && ./gen_inv.py

sleep 1m

ansible-playbook playbook.yml
cd ..
