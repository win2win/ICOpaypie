# ICOpaypie

# README #



### What is this repository for? 

* PyaPie ICO contracts
* ver 1.0
* for crowd funding during the pre and ICO phase


### How do I get set up? 

* Use truffle, remix or  Ethereum Wallet to deploy contract on Ethereum network


### How do I run

* admin can start the contract by calling start() function
* contributions are accepted by sending ether to contract address
* when the campaign is over, admin can run finilize() function to end the campaign and transfer ether to safe multisig wallet. 
* in case of emergency function emergencyStop() can be called to stop contribution and function release() to start campaign again. 
* in case of refunds or claiming tokens in presale contract, admin needs to set the appropriate steps through setStep() fucntion
according to this definitiaon in presale

        enum Step {
        Unknown,
        Funding,
        Distributing,
        Refunding
    }

    and public ICO

        enum Step {
        Unknown,
        Funding,  
        Refunding
    }
* in case of failed campaign contributors can safly withdraw their funds by calling refund() function. 
* in presale contributors will need to claim their tokens after ICO. To claim tokens one needs to call function claimTokens()
and flag "Distributing" has to be set as a step in campaig.

