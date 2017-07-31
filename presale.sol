pragma solidity ^ 0.4 .11;

contract SafeMath {
    function safeMul(uint a, uint b) internal returns(uint) {
        uint c = a * b;
        assert(a == 0 || c / a == b);
        return c;
    }

    function safeDiv(uint a, uint b) internal returns(uint) {
        assert(b > 0);
        uint c = a / b;
        assert(a == b * c + a % b);
        return c;
    }

    function safeSub(uint a, uint b) internal returns(uint) {
        assert(b <= a);
        return a - b;
    }

    function safeAdd(uint a, uint b) internal returns(uint) {
        uint c = a + b;
        assert(c >= a && c >= b);
        return c;
    }

    function assert(bool assertion) internal {
        if (!assertion) {
            revert();
        }
    }
}




contract Ownable {
    address public owner;

    function Ownable() {
        owner = msg.sender;
    }

    function transferOwnership(address newOwner) onlyOwner {
        if (newOwner != address(0)) owner = newOwner;
    }

    function kill() {
        if (msg.sender == owner) selfdestruct(owner);
    }

    modifier onlyOwner() {
        if (msg.sender == owner)
        _;
    }
}

contract Pausable is Ownable {
    bool public stopped;

    modifier stopInEmergency {
        if (stopped) {
            revert();
        }
        _;
    }

    modifier onlyInEmergency {
        if (!stopped) {
            revert();
        }
        _;
    }

    // Called by the owner in emergency, triggers stopped state
    function emergencyStop() external onlyOwner {
        stopped = true;
    }

    // Called by the owner to end of emergency, returns to normal state
    function release() external onlyOwner onlyInEmergency {
        stopped = false;
    }
}





// Presale Smart Contract
// This smart contract collects ETH and in return sends PPP tokens to the backers
contract Presale is SafeMath, Pausable{

    struct Backer {
        uint weiReceived; // amount of ETH contributed
        uint PPPSent; // amount of tokens  sent
        bool processed;
    }

    
    address public owner; // Contract owner
    address public multisigETH; // Multisig contract that will receive the ETH    
    uint public ETHReceived; // Number of ETH received
    uint public PPPSentToETH; // Number of PPP sent to ETH contributors
    uint public startBlock; // Presale start block
    uint public endBlock; // Presale end block
    
    uint public minInvestETH; // Minimum amount to invest
    bool public presaleClosed; // Is presale still on going

    uint totalTokensSold;
    uint tokenPriceWei;

    
    uint multiplier = 10000000000; // to provide 10 decimal values
    mapping(address => Backer) public backers; //backer list
    address[] public backersIndex ;   // to be able to itarate through backers when distributing the tokens. 

    // @notice to be used when certain account is required to access the function
    // @param a {address}  The address of the authorised individual
    modifier onlyBy(address a) {
        if (msg.sender != a) revert();
        _;
    }

    // @notice to verify if action is not performed out of the campaing range
    modifier respectTimeFrame() {
        if ((block.number < startBlock) || (block.number > endBlock)) revert();
        _;
    }

 

    // Events
    event ReceivedETH(address backer, uint amount, uint tokenAmount);



    // Presale  {constructor}
    // @notice fired when contract is crated. Initilizes all constnat variables.
    function Presale() {
        owner = msg.sender;
        multisigETH = 0xAbA916F9EEe18F41FC32C80c8Be957f5E7efE481; //TODO: Replace address with correct one
        
        
        PPPSentToETH = 0;
        //TODO: Update this before deploying
        minInvestETH = 1 ether;
        startBlock = 0; // Should wait for the call of the function start
        endBlock = 0; // Should wait for the call of the function start       
        tokenPriceWei = 1100000000000000;        
    }

    // @notice to loop thoruhg backersIndex and assign tokens
    // @return  {uint} true if transaction was successful
    function numberOfBackers()constant returns (uint){
        return backersIndex.length;
    }


    // @notice called to mark contributer when tokens are transfered to them after ICO
    // @param _backer {address} address of beneficiary
    function process(address _backer) onlyBy(owner) returns (bool){

        Backer storage backer = backers[_backer]; 
        backer.processed = true;

        return true;
    }

    
    // {fallback function}
    // @notice It will call internal function which handels allocation of Ether and calculates PPP tokens.
    function () payable {
        if (block.number > endBlock) revert();
        handleETH(msg.sender);
    }

    // @notice It will be called by owner to start the sale
    // TODO WARNING REMOVE _block parameter and _block variable in function
    function start(uint _block) onlyBy(owner) {
        startBlock = block.number;
        endBlock = startBlock + _block; //TODO: Replace 20 with 161280 for actual deployment
        // 4 weeks in blocks = 161280 (4 * 60 * 24 * 7 * 4)
        // enable this for live assuming each bloc takes 15 sec = 7 days.
    }

    // @notice It will be called by fallback function whenever ether is sent to it
    // @param  _backer {address} address of beneficiary
    // @return res {bool} true if transaction was successful
    function handleETH(address _backer) internal stopInEmergency respectTimeFrame returns(bool res) {

        if (msg.value < minInvestETH) revert(); // stop when required minimum is not sent

         uint PPPToSend = calculateNoOfTokensToSend(); // calculate number of tokens basedn on contribution size

      
        Backer storage backer = backers[_backer];
       
        backer.PPPSent = safeAdd(backer.PPPSent, PPPToSend); // update amount of tokens sent for the backer
        backer.weiReceived = safeAdd(backer.weiReceived, msg.value); // update amount of ether received from the backer
        ETHReceived = safeAdd(ETHReceived, msg.value); // update the total Ether recived
        PPPSentToETH = safeAdd(PPPSentToETH, PPPToSend); // update the total amount of tokens sent so far
        backersIndex.push(_backer);  // maintain iterrable index of backers
       
        ReceivedETH(_backer, msg.value, PPPToSend); // Register event
        return true;
    }

    // @notice It is called by handleETH to determine amount of tokens for given contribution    
    // @return tokensToPurchase {uint} value of tokens to purchase


      function calculateNoOfTokensToSend() constant internal returns (uint){

        uint tokenAmount = safeDiv(safeMul(msg.value , multiplier) , tokenPriceWei);
        uint ethAmount = msg.value;

       if (ethAmount > 105 ether )  
           return  tokenAmount +  safeDiv( safeMul(tokenAmount , 22), 100);
        else if (ethAmount >   55 ether)
           return  tokenAmount +  safeDiv( safeMul(tokenAmount , 10), 100); 
        else if (ethAmount >   28 ether) 
            return  tokenAmount + safeDiv( safeMul(tokenAmount , 5), 100); 
        else if (ethAmount >   5 ether) 
            return  tokenAmount + safeDiv( safeMul(tokenAmount , 2), 100);
        else return  tokenAmount; 
    
    }

    // @notice This function will finalize the sale.
    // It will only execute if predetermined sale time passed 
    function finalize() onlyBy(owner) {       

        if (block.number < endBlock ) revert(); 

        if (!multisigETH.send(this.balance)) revert();
        presaleClosed = true;
        
    }

    // TODO do we want this here?
    // @notice Failsafe drain
    function drain() onlyBy(owner) {
        if (!owner.send(this.balance)) revert();
    }

}

