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
    function emergencyStop() external onlyOwner() {
        stopped = true;
    }

    // Called by the owner to end of emergency, returns to normal state
    function release() external onlyOwner() onlyInEmergency {
        stopped = false;
    }
}



// Base contract supporting async send for pull payments.
// Inherit from this contract and use asyncSend instead of send.
contract PullPayment {
    mapping(address => uint) public payments;


    event RefundETH(address to, uint value);

    // Store sent amount as credit to be pulled, called by payer
    function asyncSend(address dest, uint amount) internal {
        payments[dest] += amount;
    }
    // TODO: check
    // Withdraw accumulated balance, called by payee
    function withdrawPayments() internal returns (bool) {
        address payee = msg.sender;
        uint payment = payments[payee];

        require (payment != 0);
        require (this.balance >= payment);

        payments[payee] = 0;

        if (!payee.send(payment)) {
            revert();
        }
        RefundETH(payee, payment);
        return true;
    }
}

// Crowdsale Smart Contract
// This smart contract collects ETH and in return sends PPP tokens to the Backers
contract Crowdsale is SafeMath, Pausable, PullPayment {

    struct Backer {
        uint weiReceived; // amount of ETH contributed
        uint tokensSent; // amount of tokens  sent  
        bool refunded; // true if user has been refunded       
    }

    Token public token; // Token contract reference   
    address public multisig; // Multisig contract that will receive the ETH    
    address public team; // Address at which the team PPP will be sent   
    uint public tokensForTeam; // Tokens to be allocated to team if campaign succeeds
    uint public ethReceived; // Number of ETH received
    uint public tokensSent; // Number of PPP sent to ETH contributors
    uint public startBlock; // Crowdsale start block
    uint public endBlock; // Crowdsale end block
    uint public maxCap; // Maximum number of PPP to sell
    uint public minCap; // Minimum number of ETH to raise
    uint public minInvestETH; // Minimum amount to invest
    bool public crowdsaleClosed; // Is crowdsale still on going
    Step public currentStep;  // to allow for controled steps of the campaign 
    uint public refundCount;  // number of refunds
    uint public totalRefunded; // total amount of refunds


    uint public tokenPriceWei;

    mapping(address => Backer) public backers; //backer list
    address[] public backersIndex; // to be able to itarate through backers for verification.  



    // @notice to verify if action is not performed out of the campaing range
    modifier respectTimeFrame() {
        if ((block.number < startBlock) || (block.number > endBlock)) 
            revert();
        _;
    }

    modifier minCapNotReached() {
        if (tokensSent >= minCap) 
            revert();
        _;
    }

    enum Step {
        Unknown,
        Funding,  
        Refunding
    }


    // Events
    event ReceivedETH(address backer, uint amount, uint tokenAmount);

    // Crowdsale  {constructor}
    // @notice fired when contract is crated. Initilizes all constnat variables.
    function Crowdsale() {

        multisig = 0x5738352c14205BB6300903c631C4a949D33FaDC1; 
        team = 0x5738352c14205BB6300903c631C4a949D33FaDC1; 
        tokensForTeam = 27500000e18;  // tokens for the team
        //TODO: replace with amount of presale tokens
        tokensSent = 0; // initilaize token number sold in presale            
        startBlock = 0; // Should wait for the call of the function start
        endBlock = 0; // Should wait for the call of the function start
        maxCap = 82500000e18; // reserve tokens for the team            
        tokenPriceWei = 1100000000000000;    
        minCap = 4500000e18;
        currentStep = Step.Funding;
    }


    // @notice in case refunds are needed, money can be returned to the contract
    function fundContract() payable onlyOwner() returns (bool) {

    return true;
    }
    // @notice Specify address of token contract
    // @param _tokenAddress {address} address of the token contract
    // @return res {bool}
    function updateTokenAddress(Token _tokenAddress) external onlyOwner() returns(bool res) {
        token = _tokenAddress;
        return true;
    }

    // @notice set the step of the campaign. 
    // @param _step {Step}
    function setStep(Step _step) external onlyOwner() {
        currentStep = _step;
    }

    // @notice return number of contributors
    // @return  {uint} number of contributors
    function numberOfBackers() constant returns(uint) {
        return backersIndex.length;
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
        endBlock = startBlock + _block; 
    }

        // @notice Due to changing average of block time
    // this function will allow on adjusting duration of campaign closer to the end 
    function adjustDuration(uint _block) external onlyOwner() {

        endBlock = startBlock + _block;  
    }

    // @notice It will be called by fallback function whenever ether is sent to it
    // @param  _backer {address} address of beneficiary
    // @return res {bool} true if transaction was successful
    function contribute(address _backer) internal stopInEmergency respectTimeFrame returns(bool res) {

        require (currentStep == Step.Funding);

        uint tokensToSend = safeDiv(safeMul(msg.value, 1e18), tokenPriceWei); // ensure adding of decimal values before devision

        // Ensure that max cap hasn't been reached
        require (safeAdd(tokensSent, tokensToSend) <= maxCap);
        

        Backer storage backer = backers[_backer];

        if (!token.transfer(_backer, tokensToSend)) 
            revert(); // Transfer tokens
        backer.tokensSent = safeAdd(backer.tokensSent, tokensToSend);
        backer.weiReceived = safeAdd(backer.weiReceived, msg.value);
        ethReceived = safeAdd(ethReceived, msg.value); // Update the total Ether recived
        tokensSent = safeAdd(tokensSent, tokensToSend);
        backersIndex.push(_backer);

        multisig.transfer(this.balance);                

        ReceivedETH(_backer, msg.value, tokensToSend); // Register event
        return true;
    }




    // @notice This function will finalize the sale.
    // It will only execute if predetermined sale time passed or all tokens are sold.
    function finalize() external onlyOwner() {

        if (crowdsaleClosed)
            revert();

        if (block.number < endBlock && tokensSent < maxCap) 
            revert();

        if (tokensSent < minCap && block.number > endBlock) 
            revert();

        if (tokensSent > minCap) {               
            if (!token.transfer(team, token.balanceOf(this))) 
                revert();
            token.unlock();
        }

        crowdsaleClosed = true;
        
    }


    // @notice Failsafe drain
    function drain() external onlyOwner() {
        if (!multisig.send(this.balance)) 
            revert();
    }


    // @notice Prepare refund of the backer if minimum is not reached
    // burn the tokens
    function prepareRefund()  minCapNotReached internal returns (bool) {

        Backer storage backer = backers[msg.sender];

        require (!backer.refunded);               
        require (backer.tokensSent != 0); 

        if (!token.burn(msg.sender, backer.tokensSent)) 
            revert();

        backer.refunded = true;        
        if (backer.weiReceived > 0) {
            asyncSend(msg.sender, backer.weiReceived);
            refundCount ++;
            totalRefunded = safeAdd(totalRefunded, backer.weiReceived);
            return true;
        }
        else 
            return false;            
    }

    // @notice refund the backer
    function refund() external returns (bool) {

        require (currentStep == Step.Refunding);

        if (!prepareRefund()) 
            revert();
        if (!withdrawPayments())
            revert();
        return true;
    }
}

// The PPP token
contract Token is ERC20, SafeMath, Ownable {
    // Public variables of the token
    string public name;
    string public symbol;
    uint8 public decimals; // How many decimals to show.
    string public version = "v0.1";
    uint public initialSupply;
    uint public totalSupply;
    bool public locked;
    address public crowdSaleAddress;
    address public preSaleAddress;       
    mapping(address => uint) balances;
    mapping(address => mapping(address => uint)) allowed;

    // Lock transfer for contributors during the ICO 
    modifier onlyUnlocked() {
        if (msg.sender != crowdSaleAddress && msg.sender != preSaleAddress && locked) 
            revert();
        _;
    }

    modifier onlyAuthorized() {
        if (msg.sender != owner && msg.sender != crowdSaleAddress ) 
            revert();
        _;
    }

    // The PPP Token created with the time at which the crowdsale ends
    function Token(address _crowdSaleAddress, address _presaleAddress, uint tokensSold) {
        // Lock the transfCrowdsaleer function during the crowdsale
        locked = true;
        initialSupply = 165000000e18;
        totalSupply = initialSupply;
        name = "PayPie"; // Set the name for display purposes
        symbol = "PPP"; // Set the symbol for display purposes
        decimals = 18; // Amount of decimals for display purposes
        crowdSaleAddress = _crowdSaleAddress;
        preSaleAddress = _presaleAddress;

        // TODO: make sure the address in here and the presale amounts are accurate
        // Address to hold tokens for pre-sale customers
        balances[_presaleAddress] = tokensSold;

        balances[crowdSaleAddress] = totalSupply - balances[_presaleAddress];
    }

    function unlock() onlyAuthorized {
        locked = false;
    }

    function lock() onlyAuthorized {
        locked = true;
    }

    function burn( address _member, uint256 _value) onlyAuthorized returns(bool) {
        balances[_member] = safeSub(balances[_member], _value);
        totalSupply = safeSub(totalSupply, _value);
        Transfer(_member, 0x0, _value);
        return true;
    }

    function transfer(address _to, uint _value) onlyUnlocked returns(bool) {
        balances[msg.sender] = safeSub(balances[msg.sender], _value);
        balances[_to] = safeAdd(balances[_to], _value);
        Transfer(msg.sender, _to, _value);
        return true;
    }


    /* A contract attempts to get the coins */
    function transferFrom(address _from, address _to, uint256 _value) returns(bool success) {
        require (balances[_from] >= _value); // Check if the sender has enough                            
        require (_value <= allowed[_from][msg.sender]); // Check if allowed is greater or equal        
        balances[_from] = safeSub(balances[_from], _value); // Subtract from the sender
        balances[_to] = safeAdd(balances[_to],_value); // Add the same to the recipient
        allowed[_from][msg.sender] = safeSub(allowed[_from][msg.sender],_value);
        Transfer(_from, _to, _value);
        return true;
    }

    function balanceOf(address _owner) constant returns(uint balance) {
        return balances[_owner];
    }

    function approve(address _spender, uint _value) returns(bool) {
        allowed[msg.sender][_spender] = _value;
        Approval(msg.sender, _spender, _value);
        return true;
    }


    function allowance(address _owner, address _spender) constant returns(uint remaining) {
        return allowed[_owner][_spender];
    }
}