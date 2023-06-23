#! /usr/bin/python3

from json import loads

PRIVATE_KEY_FILENAME = 'id_ed25519'

with open('hosts.json', 'r') as jsonfile, open('hosts', 'w') as output:
  ip_addresses = loads(jsonfile.read())
  
  output.write("[app_servers]\n")
  for i, ip in enumerate(ip_addresses['instance_group_ip_addresses']['value']):
    output.write(f"app_{i} ansible_host={ip} ansible_user=ubuntu ansible_ssh_private_key=~/.ssh/{PRIVATE_KEY_FILENAME}\n")
  
  output.write("[adm_server]\n")
  ip = ip_addresses['admin_server_ip_address']['value']
  output.write(f"adm_0 ansible_host={ip} ansible_user=ubuntu ansible_ssh_private_key=~/.ssh/{PRIVATE_KEY_FILENAME}\n")
