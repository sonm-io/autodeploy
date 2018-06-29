## SONM autodeploy
To remove SONM run command
 ```bash
sudo bash -c "$(curl -s https://raw.githubusercontent.com/sonm-io/autodeploy/master/sonm-uninstall.sh)"
```

To install SONM for supplier run command:
 ```bash
sudo bash -c "$(curl -s https://raw.githubusercontent.com/sonm-io/autodeploy/master/sonm-auto-deploy-supplier.sh)" -s "0xMASTER ETH ADDRESS"
```

To install SONM for consumer run command:
 ```bash
sudo bash -c "$(curl -s https://raw.githubusercontent.com/sonm-io/autodeploy/master/sonm-auto-deploy-consumer.sh)"
```