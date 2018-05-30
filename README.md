## SONM autodeploy
To remove SONM run command
 ```bash
curl -s https://raw.githubusercontent.com/sonm-io/autodeploy/master/sonm-uninstall.sh | sudo bash
```

To install SONM for supplier run command:
 ```bash
sudo bash -c "$(curl -s https://raw.githubusercontent.com/sonm-io/autodeploy/master/sonm-auto-deploy-supplier.sh)"
```

To install SONM for consumer run command:
 ```bash
sudo bash -c "$(curl -s https://raw.githubusercontent.com/sonm-io/autodeploy/master/sonm-auto-deploy-consumer.sh)"
```