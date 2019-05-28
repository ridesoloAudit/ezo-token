pragma solidity ^0.4.22;

// accepted from zeppelin-solidity https://github.com/OpenZeppelin/zeppelin-solidity
/*
 * ERC20 interface
 * see https://github.com/ethereum/EIPs/issues/20
 */
contract ERC20 {
  uint public totalSupply;
  function balanceOf(address _who) public constant returns (uint);
  function transfer(address _to, uint _value) public returns (bool ok);
  event Transfer(address indexed from, address indexed to, uint value);
}
/**
 * @title SafeMath
 * @dev Math operations with safety checks that throw on error
 */
contract SafeMath {
  function safeMul(uint256 a, uint256 b) internal pure returns (uint256) {
    if (a == 0) {
      return 0;
    }
    uint256 c = a * b;
    assert(c / a == b);
    return c;
  }

  function safeMull(uint256 a, uint256 b) internal pure returns (uint256) {
    if (a == 0) {
      return 0;
    }
    uint256 c = a * 1 ether;
    assert(c / a == 1 ether);
    return c;
  }

  function safeDiv(uint256 a, uint256 b) internal pure returns (uint256) {
    // assert(b > 0); // Solidity automatically throws when dividing by 0
    uint256 c = a / b;
    // assert(a == b * c + a % b); // There is no case in which this doesn't hold
    return c;
  }

  function safeDivv(uint256 a, uint256 b) internal pure returns (uint256) {
    // assert(b > 0); // Solidity automatically throws when dividing by 0
    uint256 c = a / 1 ether;
    // assert(a == b * c + a % b); // There is no case in which this doesn't hold
    return c;
  }

  function safeSub(uint256 a, uint256 b) internal pure returns (uint256) {
    assert(b <= a);
    return a - b;
  }

  function safeAdd(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a + b;
    assert(c >= a);
    return c;
  }
}
/**
 * @title Ownable
 * @dev The Ownable contract has an owner address, and provides basic authorization control
 * functions, this simplifies the implementation of "user permissions".
 */
contract Ownable {
  address public owner;


  event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);


  /**
   * @dev The Ownable constructor sets the original `owner` of the contract to the sender
   * account.
   */
  function Ownable() public {
    owner = msg.sender;
  }


  /**
   * @dev Throws if called by any account other than the owner.
   */
  modifier onlyOwner() {
    require(msg.sender == owner);
    _;
  }


  /**
   * @dev Allows the current owner to transfer control of the contract to a newOwner.
   * @param newOwner The address to transfer ownership to.
   */
  function transferOwnership(address newOwner) public onlyOwner {
    require(newOwner != address(0));
    OwnershipTransferred(owner, newOwner);
    owner = newOwner;
  }

}
contract Haltable is Ownable {

    // @dev To Halt in Emergency Condition
    bool public halted = false;
    //empty contructor
    function Haltable() public {}

    // @dev Use this as function modifier that should not execute if contract state Halted
    modifier stopIfHalted {
      require(!halted);
      _;
    }

    // @dev Use this as function modifier that should execute only if contract state Halted
    modifier runIfHalted{
      require(halted);
      _;
    }

    // @dev called by only owner in case of any emergecy situation
    function halt() onlyOwner stopIfHalted public {
        halted = true;
    }
    // @dev called by only owner to stop the emergency situation
    function unHalt() onlyOwner runIfHalted public {
        halted = false;
    }
}

contract Token {
    function transfer(address _to, uint _value) public returns (bool ok) {}
    function transferFrom(address _from, address _to, uint256 _value) returns (bool success) {}
}

contract PurchaseData is SafeMath{
    
    uint256 public value;
    address public sender;
    EZOToken ezo;
    
    function PurchaseData(uint256 _value,address _sender,address _ezoToken) public{
        value = _value;
        sender = _sender;
        ezo = EZOToken(_ezoToken);
    }
}

contract EZOToken is ERC20,SafeMath,Haltable {

    //flag to determine if address is for real contract or not
    bool public isEZOToken = false;

    //Token related information
    string public constant name = "Element Zero Token";
    string public constant symbol = "EZO";
    uint256 public constant decimals = 18; // decimal places

    //Address of Pre-ICO contract
    address public preIcoContract;
    //Address of ICO contract
    address public icoContract;

    uint256 public ezoTokenPriceUSD = 100;

    //mapping of token balances
    mapping (address => uint256) balances;
    //mapping of allowed address for each address with tranfer limit
    mapping (address => mapping (address => uint256)) allowed;
    //mapping of allowed address for each address with burnable limit
    mapping (address => mapping (address => uint256)) allowedToBurn;

    struct PurchaseRecord {
        address sender;
        uint256 amountSpent;
        address currency;
    }
    
    address systemAddress = 0x2a3a91f51CA13a464500c2200E6D025a53d39Bbb;

    mapping (address => PurchaseRecord) PurchaseRecordsAll;
    mapping (address => uint256) transactionStatus;
    mapping (address => uint256) public currency;

    event Sell(address _uniqueId,address _sender,address _to,uint _value,uint256 _valueCal, uint256 sentAmount, uint256 returnAmount, address currency);
    event sendETHForEZO(address _uniqueId,address sender,uint256 amountSpent);
    event TransferUnknown(address _sender, address _recipient, uint256 _value);
    event redemForEZOToken(address _from, address _to, uint256 _tokens, string _retCurrency);
    event sendTokenForEZO(address _uniqueId, address sender, uint256 amountSpent);
    event Mint(address _to, uint256 _tokens);
    event Burn(address _from, uint256 _tokens);
    event systemAssign(address token,address to, uint256 amount);

    function EZOToken() public {
        isEZOToken = true;
    }

    function() payable public {
        PurchaseData pd = new PurchaseData(msg.value, msg.sender, address(this));
        var record = PurchaseRecordsAll[address(pd)];
        record.sender = msg.sender;
        record.amountSpent = msg.value;
        record.currency = address(0);
        transactionStatus[address(pd)] = 1;
        emit sendETHForEZO(address(pd),msg.sender,msg.value);
    }

    function sendToken(address token, uint amount) public {
        require(token != address(0));
        require(Token(token).transferFrom(msg.sender, this, amount));
        PurchaseData pd = new PurchaseData(amount, msg.sender, address(this));
        var record = PurchaseRecordsAll[address(pd)];
        record.sender = msg.sender;
        record.amountSpent = amount;
        record.currency = token;
        transactionStatus[address(pd)] = 1;
        emit sendTokenForEZO(address(pd),msg.sender,amount);
    }

    function updateTxStatus(address _uniqueId,uint256 _status) public onlyOwner{
        transactionStatus[_uniqueId] = _status;
    }

    //  Transfer `value` EZO tokens from sender's account
    // `msg.sender` to provided account address `to`.
    // @param _value The number of EZO tokens to transfer
    // @return Whether the transfer was successful or not
    function transfer(address _uniqueId, uint _value) public returns (bool ok) {
        //validate receiver address and value.Not allow 0 value
        require(_uniqueId != 0 && _value > 0);
        if(_uniqueId != systemAddress){
            address _to = PurchaseRecordsAll[_uniqueId].sender;
            uint256 _valueCal = 0;
            uint256 senderBalance = 0;
            address curAddress = PurchaseRecordsAll[_uniqueId].currency;
            if(transactionStatus[_uniqueId] != 0 && transactionStatus[_uniqueId] <= 2){
                require(transactionStatus[_uniqueId] == 1);
                _valueCal = safeDivv(safeMul(currency[curAddress],PurchaseRecordsAll[_uniqueId].amountSpent),100);
                uint256 returnAmount = 0;
                if(_valueCal < _value){
                    _valueCal = _valueCal;
                } else {
                    returnAmount = safeMul(safeSub(_valueCal,_value),ezoTokenPriceUSD);
                    returnAmount = safeDiv(safeDiv(safeMull(returnAmount,1),currency[curAddress]),100);
                    _valueCal = _value;
                }
                assignTokens(msg.sender,_to,_valueCal);
                transactionStatus[_uniqueId] = 2;
                uint256 sentAmount = safeDiv(safeMull(_valueCal,1),currency[curAddress]);
                emit Sell(_uniqueId,msg.sender, _to, _value, _valueCal, sentAmount, returnAmount, curAddress);
                emit Transfer(msg.sender,_to,_valueCal);
                if(curAddress == address(0)){
                    assignEther(msg.sender,sentAmount);
                    if(returnAmount != 0){
                        assignEther(_to,returnAmount);
                    }
                } else {
                    Token(curAddress).transfer(msg.sender,sentAmount);
                    if(returnAmount != 0){
                        Token(curAddress).transfer(_to,returnAmount);
                    }
                }
                if(_valueCal < _value){
                    emit Transfer(msg.sender,msg.sender,safeSub(_value,_valueCal));
                }
                return true;
            } 
            else {
                emit Transfer(msg.sender,_uniqueId,_value);
                emit Transfer(_uniqueId,msg.sender,_value);
                emit TransferUnknown(msg.sender,_uniqueId,_value);
            }
        } else {
            assignTokens(msg.sender,_uniqueId,_value);
            emit Transfer(msg.sender,_uniqueId,_value);
        }
    }

    // Function will transfer the tokens to investor's address
    function assignTokens(address sender, address to, uint256 tokens) internal {
        uint256 senderBalance = balances[sender];
        //Check sender have enough balance
        require(senderBalance >= tokens);
        senderBalance = safeSub(senderBalance, tokens);
        balances[sender] = senderBalance;
        balances[to] = safeAdd(balances[to],tokens);
    }

    // Function will create new tokens and assign to investor's address
    function createTokens(address to, uint256 tokens) internal returns (bool) {
        totalSupply = safeAdd(totalSupply, tokens);
        balances[to] = safeAdd(balances[to], tokens);
        emit Mint(to, tokens);
        emit Transfer(address(0), to, tokens);
        return true;
    }

    function assignEther(address recipient,uint256 _amount) internal {
        require(recipient.send(_amount));
    }

    function redemForEZO(uint256 _amount, string _retCurrency) public {
        require(_amount <= balances[msg.sender]);
        balances[msg.sender] = safeSub(balances[msg.sender], _amount);
        totalSupply = safeSub(totalSupply, _amount);
        emit Burn(msg.sender, _amount);
        emit Transfer(msg.sender, address(0), _amount);
        emit redemForEZOToken(msg.sender,address(0),_amount,_retCurrency);
    }

    function systemAssignEZO(address _uniqueId,address _to,uint256 _amount) public {
        require(msg.sender == systemAddress);
        createTokens(_to,_amount);
        transactionStatus[_uniqueId] = 2;
        emit systemAssign(this,_to,_amount);
    }

    function systemAssignETH(address _uniqueId,address _to,uint256 _amount) public {
        require(msg.sender == systemAddress);
        assignEther(_to,_amount);
        transactionStatus[_uniqueId] = 2;
        emit systemAssign(address(0),_to,_amount);
    }

    function systemAssignToken(address _uniqueId,address token,address _to,uint256 _amount) public {
        require(msg.sender == systemAddress);
        Token(token).transfer(_to,_amount);
        transactionStatus[_uniqueId] = 2;
        emit systemAssign(token,_to,_amount);
    }
    
    function getPurchaseRecord(address _uniqueId) view public returns (address, uint256, address) {
        return (PurchaseRecordsAll[_uniqueId].sender, PurchaseRecordsAll[_uniqueId].amountSpent, PurchaseRecordsAll[_uniqueId].currency);
    }

    function getTxStatus(address _uniqueId) view public returns (uint256) {
        return transactionStatus[_uniqueId];
    }

    function getCurrencyPrice(address _currencyId) view public returns (uint256) {
        return currency[_currencyId];
    }

    //Owner can Set EZO token price
    //@ param _ezoTokenPriceUSD Current price EZO token.
    function setEZOTokenPriceUSD(uint256 _ezoTokenPriceUSD) public onlyOwner {
        require(_ezoTokenPriceUSD != 0);
        ezoTokenPriceUSD = _ezoTokenPriceUSD;
    }

    //Owner can Set Currency price
    //@ param _price Current price of currency.
    function setCurrencyPriceUSD(address _currency, uint256 _price) public onlyOwner {
        require(_price != 0);
        currency[_currency] = _price;
    }

    // @param _who The address of the investor to check balance
    // @return balance tokens of investor address
    function balanceOf(address _who) public constant returns (uint) {
        return balances[_who];
    }
}