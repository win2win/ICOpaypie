pragma solidity ^ 0.4.11;

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
}




contract Ownable {
    address public owner;

    function Ownable() {
        owner = msg.sender;
    }

    function transferOwnership(address newOwner) onlyOwner {
        if (newOwner != address(0)) 
            owner = newOwner;
    }

    function kill() {
        if (msg.sender == owner) 
            selfdestruct(owner);
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


contract ERC20 {
    uint public totalSupply;

    function balanceOf(address who) constant returns(uint);

    function allowance(address owner, address spender) constant returns(uint);

    function transfer(address to, uint value) returns(bool ok);

    function transferFrom(address from, address to, uint value) returns(bool ok);

    function approve(address spender, uint value) returns(bool ok);

    event Transfer(address indexed from, address indexed to, uint value);
    event Approval(address indexed owner, address indexed spender, uint value);
}


contract Token is ERC20, SafeMath, Ownable {

    function transfer(address _to, uint _value) returns(bool);
}

// Presale Smart Contract
// This smart contract collects ETH and in return sends PPP tokens to the backers
contract Presale is SafeMath, Pausable {

    struct Backer {
        uint weiReceived; // amount of ETH contributed
        uint tokensToSend; // amount of tokens  sent
        bool claimed;
        bool refunded;
    }


    address public owner; // Contract owner
    address public multisig; // Multisig contract that will receive the ETH    
    uint public ethReceived; // Number of ETH received
    uint public tokensSent; // Number of PPP sent to ETH contributors
    uint public startBlock; // Presale start block
    uint public endBlock; // Presale end block

    uint public minInvestETH; // Minimum amount to invest
    bool public presaleClosed; // Is presale still on going
    //enum Step{Unknown, Funding, Distributing, Refunding};

    enum Step {
        Unknown,
        Funding,
        Distributing,
        Refunding
    }


    uint public tokenPriceWei;
    Token public token;


    uint multiplier = 10000000000; // to provide 10 decimal values
    mapping(address => Backer) public backers; //backer list
    address[] public backersIndex;
    uint public maxCap;
    uint public claimCount;
    uint public refundCount;
    uint public totalClaimed;
    uint public totalRefunded;
    Step public currentStep;



    //enum Step{Unknown, Funding, Distributing, Refunding};

    mapping(address => uint) public claimed; // Tokens claimed by contibutors
    mapping(address => uint) public refunded; // Tokens refunded to contributors


    // @notice to verify if action is not performed out of the campaing range
    modifier respectTimeFrame() {
        if ((block.number < startBlock) || (block.number > endBlock)) 
            revert();
        _;
    }



    // Events
    event ReceivedETH(address backer, uint amount, uint tokenAmount);
    event TokensClaimed(address backer, uint count);
    event Refunded(address backer, uint amount);



    // Presale  {constructor}
    // @notice fired when contract is crated. Initilizes all constnat variables.
    function Presale() {
        owner = msg.sender;
        multisig = 0xAbA916F9EEe18F41FC32C80c8Be957f5E7efE481; //TODO: Replace address with correct one
        minInvestETH = 1 ether;
        //TODO add actual max cap
        maxCap = 50000000 * multiplier;
        startBlock = 0; // Should wait for the call of the function start
        endBlock = 0; // Should wait for the call of the function start       
        tokenPriceWei = 1100000000000000;
        currentStep = Step.Funding;
    }

    // @notice to loop thoruhg backersIndex and assign tokens
    // @return  {uint} true if transaction was successful
    function numberOfBackers() constant returns(uint) {
        return backersIndex.length;
    }


    // @notice called to mark contributors when tokens are transfered to them after ICO manually. 
    // @param _backer {address} address of beneficiary
    function claimTokensForUser(address _backer) onlyOwner() external returns(bool) {

        if (backer.refunded) 
            revert();  // if refunded, don't allow for another refund
        if (backer.claimed) 
            revert(); // if tokens claimed, don't allow refunding
        if (backer.tokensToSend == 0) 
            revert();  // only continue if are any tokens to send
            

        Backer storage backer = backers[_backer];
        backer.claimed = true;

        if (!token.transfer(_backer, backer.tokensToSend)) 
            revert(); // send claimed tokens to contributor account

        TokensClaimed(msg.sender, backer.tokensToSend);  

        return true;
    }


    // {fallback function}
    // @notice It will call internal function which handels allocation of Ether and calculates PPP tokens.
    function () payable {
        contribute(msg.sender);
    }

    // @notice It will be called by owner to start the sale
    // TODO WARNING REMOVE _block parameter and _block variable in function
    function start(uint _block) external onlyOwner() {
        startBlock = block.number;
        endBlock = startBlock + _block; //TODO: Replace 20 with 161280 for actual deployment
        // 4 weeks in blocks = 161280 (4 * 60 * 24 * 7 * 4)
        // enable this for live assuming each bloc takes 15 sec = 7 days.
    }


    function setStep(Step _step) external onlyOwner() {
        currentStep = _step;
    }


    function setToken(Token _token) onlyOwner() returns(bool) {

        token = _token;
        return true;

    }
    // @notice It will be called by fallback function whenever ether is sent to it
    // @param  _backer {address} address of beneficiary
    // @return res {bool} true if transaction was successful
    function contribute(address _backer) internal stopInEmergency respectTimeFrame returns(bool res) {

        if (currentStep != Step.Funding)
            revert();

        if (msg.value < minInvestETH) 
            revert(); // stop when required minimum is not sent

        uint tokensToSend = calculateNoOfTokensToSend();

         // Ensure that max cap hasn't been reached
        if (safeAdd(tokensSent, tokensToSend) > maxCap) 
            revert();


        Backer storage backer = backers[_backer];

        if (backer.weiReceived == 0)
            backersIndex.push(_backer);

        backer.tokensToSend = safeAdd(backer.tokensToSend, tokensToSend);
        backer.weiReceived = safeAdd(backer.weiReceived, msg.value);
        ethReceived = safeAdd(ethReceived, msg.value); // Update the total Ether recived
        tokensSent = safeAdd(tokensSent, tokensToSend);


        ReceivedETH(_backer, msg.value, tokensToSend); // Register event
        return true;
    }

    // @notice It is called by contribute to determine amount of tokens for given contribution    
    // @return tokensToPurchase {uint} value of tokens to purchase

    function calculateNoOfTokensToSend() constant internal returns(uint) {
         
        uint tokenAmount = safeDiv(safeMul(msg.value, multiplier), tokenPriceWei);
        uint ethAmount = msg.value;

        if (ethAmount > 105 ether)
            return tokenAmount + (tokenAmount * 22) / 100;
        else if (ethAmount > 55 ether)
            return tokenAmount + (tokenAmount * 10) / 100;
        else if (ethAmount > 28 ether)
            return tokenAmount + (tokenAmount * 5) / 100;
        else if (ethAmount > 5 ether)
            return tokenAmount + (tokenAmount * 2) / 100;
        else 
            return tokenAmount;

    }

    // @notice This function will finalize the sale.
    // It will only execute if predetermined sale time passed 

    function finalize() external onlyOwner() {

        if (presaleClosed)
            revert();

        if (block.number < endBlock) 
            revert();

        if (!multisig.send(this.balance)) 
            revert();
        presaleClosed = true;

    }


    // @notice Backers can claim tokens after public ICO is finished
    function claimTokens() external {

        if (currentStep != Step.Distributing)   // ensure that we are ready for this step
            revert();

        if (token == address(0))  // address of the token is set after ICO, ensure that it is already set
            revert();

        Backer storage backer = backers[msg.sender];
        if (backer.refunded) 
            revert();  // if refunded, don't allow for another refund
        if (backer.claimed) 
            revert(); // if tokens claimed, don't allow refunding
        if (backer.tokensToSend == 0)   // only continue if are any tokens to send
            revert();

        claimCount++;
        claimed[msg.sender] = backer.tokensToSend;  // save claimed tokens
        backer.claimed = true;

        totalClaimed = safeAdd(totalClaimed, backer.tokensToSend);
        
        if (!token.transfer(msg.sender, backer.tokensToSend)) 
            revert(); // send claimed tokens to contributor account

        TokensClaimed(msg.sender, backer.tokensToSend);  

    }

    // @notice allow refund when ICO failed
    // the step will be set when main ICO finished 
    function refund() external {

        if (currentStep != Step.Refunding)
            revert();

        Backer storage backer = backers[msg.sender];

        if (backer.claimed) 
            revert();  // check if tokens have been allocated already        
        if (backer.refunded) 
            revert();  // check if user has been already refunded

        backer.refunded = true; // mark contributor as refunded. 
        totalRefunded = safeAdd(totalRefunded, backer.weiReceived);
        refundCount ++;
        refunded[msg.sender] = backer.weiReceived;

        if (!msg.sender.send(backer.weiReceived))  // refund contribution
            revert();

        Refunded(msg.sender, backer.weiReceived);
    }


    // @notice Failsafe drain
    function drain() external onlyOwner() {
        if (!multisig.send(this.balance)) 
            revert();
    }
}