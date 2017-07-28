# ICOpaypie

# README #



### What is this repository for? 

* PyaPie ICO contracts
* ver 1.0
* for crowd funding during the pre and ICO phase


### How do I get set up? 

* Use truffle or Ethereum Wallet to deploy contract on Ethereum network


### How do I run

* admin can start the contract by calling start() function
* contributions are accepted by sending ether to contract address
* when the campaign is over, admin can run finilize() function to end the campaign and transfer ether to safe multisig wallet. 
* in case of emergency function emergencyStop() can be called to stop contribution and function release() to start campaign again. 
* in case of failed campaign contributors can safly withdraw their funds by calling receiveApproval() function and withdrawPayments()