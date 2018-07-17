pragma solidity 0.4.23;

/**
 * @title ERC20Basic
 * @dev Simpler version of ERC20 interface
 * @dev see https://github.com/ethereum/EIPs/issues/179
 */
contract ERC20Basic {
  function totalSupply() public view returns (uint256);
  function balanceOf(address who) public view returns (uint256);
  function transfer(address to, uint256 value) public returns (bool);
  event Transfer(address indexed from, address indexed to, uint256 value);
}


/**
 * @title ERC20 interface
 * @dev see https://github.com/ethereum/EIPs/issues/20
 */
contract ERC20 is ERC20Basic {
  function allowance(address owner, address spender) public view returns (uint256);
  function transferFrom(address from, address to, uint256 value) public returns (bool);
  function approve(address spender, uint256 value) public returns (bool);
  function transferToken(address _to, uint256 _amount) external returns (bool);
  function needALight(uint256 _amount) external returns (bool);
  event Approval(address indexed owner, address indexed spender, uint256 value);
}


/**
 * @title SafeMath
 * @dev Math operations with safety checks that throw on error
 */
library SafeMath {
    /**
    * @dev Multiplies two numbers, throws on overflow.
    */
    function mul(uint256 a, uint256 b) internal pure returns (uint256 c) {
        if (a == 0) {
            return 0;
        }
        c = a * b;
        assert(c / a == b);
        return c;
    }

    /**
    * @dev Integer division of two numbers, truncating the quotient.
    */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        // assert(b > 0); // Solidity automatically throws when dividing by 0
        // uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold
        return a / b;
    }

    /**
    * @dev Subtracts two numbers, throws on overflow (i.e. if subtrahend is greater than minuend).
    */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        assert(b <= a);
        return a - b;
    }

    /**
    * @dev Adds two numbers, throws on overflow.
    */
    function add(uint256 a, uint256 b) internal pure returns (uint256 c) {
        c = a + b;
        assert(c >= a);
        return c;
    }
}

/**
 * @title Crowdsale
 * @dev Crowdsale is a base contract for managing a token crowdsale,
 * allowing investors to purchase tokens with ether. This contract implements
 * such functionality in its most fundamental form and can be extended to provide additional
 * functionality and/or custom behavior.
 * The external interface represents the basic interface for purchasing tokens, and conform
 * the base architecture for crowdsales. They are *not* intended to be modified / overriden.
 * The internal interface conforms the extensible and modifiable surface of crowdsales. Override
 * the methods to add functionality. Consider using 'super' where appropiate to concatenate
 * behavior.
 */
contract Crowdsale {
    using SafeMath for uint256;

    // The token being sold
    ERC20 public token;

    // Address where funds are collected
    address public wallet;

    // How many token units a buyer gets per wei
    uint256 public rate;

    // Amount of wei raised
    uint256 public weiRaised;

    /**
     * Event for token purchase logging
     * @param purchaser who paid for the tokens
     * @param beneficiary who got the tokens
     * @param value weis paid for purchase
     * @param amount amount of tokens purchased
     */
    event TokenPurchase(address indexed purchaser, address indexed beneficiary, uint256 value, uint256 amount);

    /**
     * @param _rate Number of token units a buyer gets per wei
     * @param _wallet Address where collected funds will be forwarded to
     */
    constructor(uint256 _rate, address _wallet) public {
      require(_rate > 0);
      require(_wallet != address(0));
      rate = _rate;
      wallet = _wallet;
    }
    
    function setup(address _token) internal {
      require(_token != address(0));
      token = ERC20(_token);
    }

    // -----------------------------------------
    // Crowdsale external interface
    // -----------------------------------------
    /**
     * @dev fallback function ***DO NOT OVERRIDE***
     */
    function () external payable {
        buyTokens(msg.sender);
    }

    /**
     * @dev low level token purchase ***DO NOT OVERRIDE***
     * @param _beneficiary Address performing the token purchase
     */
    function buyTokens(address _beneficiary) public payable {
      uint256 weiAmount = msg.value;
      _preValidatePurchase(_beneficiary, weiAmount);
      
      // calculate token amount to be created
      uint256 tokens = _getTokenAmount(weiAmount);
      
      // update state
      weiRaised = weiRaised.add(weiAmount);
      
      _processPurchase(_beneficiary, tokens);
      emit TokenPurchase(msg.sender, _beneficiary, weiAmount, tokens);
    
    //   _updatePurchasingState(_beneficiary, weiAmount);
      
      _forwardFunds();
      _postValidatePurchase(_beneficiary, weiAmount);
    }

    // -----------------------------------------
    // Internal interface (extensible)
    // -----------------------------------------

    /**
     * @dev Validation of an incoming purchase. Use require statements to revert state when conditions are not met. Use super to concatenate validations.
     * @param _beneficiary Address performing the token purchase
     * @param _weiAmount Value in wei involved in the purchase
     */
    function _preValidatePurchase(address _beneficiary, uint256 _weiAmount) internal {
      require(_beneficiary != address(0));
      require(_weiAmount != 0);
    }

    /**
     * @dev Validation of an executed purchase. Observe state and use revert statements to undo rollback when valid conditions are not met.
     * @param _beneficiary Address performing the token purchase
     * @param _weiAmount Value in wei involved in the purchase
     */
    function _postValidatePurchase(address _beneficiary, uint256 _weiAmount) internal {
      // optional override
    }

    /**
     * @dev Source of tokens. Override this method to modify the way in which the crowdsale ultimately gets and sends its tokens.
     * @param _beneficiary Address performing the token purchase
     * @param _tokenAmount Number of tokens to be emitted
     */
    function _deliverTokens(address _beneficiary, uint256 _tokenAmount) internal {
      token.transfer(_beneficiary, _tokenAmount);
    }

    /**
     * @dev Executed when a purchase has been validated and is ready to be executed. Not necessarily emits/sends tokens.
     * @param _beneficiary Address receiving the tokens
     * @param _tokenAmount Number of tokens to be purchased
     */
    function _processPurchase(address _beneficiary, uint256 _tokenAmount) internal {
      _deliverTokens(_beneficiary, _tokenAmount);
    }

    /**
     * @dev Override to extend the way in which ether is converted to tokens.
     * @param _weiAmount Value in wei to be converted into tokens
     * @return Number of tokens that can be purchased with the specified _weiAmount
     */
    function _getTokenAmount(uint256 _weiAmount) internal view returns (uint256) {
      return _weiAmount.mul(rate);
    }

    /**
     * @dev Determines how ETH is stored/forwarded on purchases.
     */
    function _forwardFunds() internal {
      wallet.transfer(msg.value);
    }
}

/**
 * @title Ownable
 * @dev The Ownable contract has an owner address, and provides basic authorization control
 * functions, this simplifies the implementation of "user permissions".
 */
contract Ownable {
    address public owner;
    event OwnershipRenounced(address indexed previousOwner);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev The Ownable constructor sets the original `owner` of the contract to the sender
     * account.
     */
    constructor() public {
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
      _transferOwnership(newOwner);
    }
    
    /**
     * @dev Transfers control of the contract to a newOwner.
     * @param _newOwner The address to transfer ownership to.
     */
    function _transferOwnership(address _newOwner) internal {
      require(_newOwner != address(0));
      emit OwnershipTransferred(owner, _newOwner);
      owner = _newOwner;
    }
}

/**
 * @title Escrow
 * @dev Base escrow contract, holds funds destinated to a payee until they
 * withdraw them. The contract that uses the escrow as its payment method
 * should be its owner, and provide public methods redirecting to the escrow's
 * deposit and withdraw.
 */
contract Escrow is Ownable {
  using SafeMath for uint256;

  event Deposited(address indexed payee, uint256 weiAmount);
  event Withdrawn(address indexed payee, uint256 weiAmount);

  mapping(address => uint256) private deposits;

  function depositsOf(address _payee) public view returns (uint256) {
    return deposits[_payee];
  }

  /**
  * @dev Stores the sent amount as credit to be withdrawn.
  * @param _payee The destination address of the funds.
  */
  function deposit(address _payee) public onlyOwner payable {
    uint256 amount = msg.value;
    deposits[_payee] = deposits[_payee].add(amount);

    emit Deposited(_payee, amount);
  }

  /**
  * @dev Withdraw accumulated balance for a payee.
  * @param _payee The address whose funds will be withdrawn and transferred to.
  */
  function withdraw(address _payee) public onlyOwner {
    uint256 payment = deposits[_payee];
    assert(address(this).balance >= payment);

    deposits[_payee] = 0;

    _payee.transfer(payment);

    emit Withdrawn(_payee, payment);
  }
}

/**
 * @title ConditionalEscrow
 * @dev Base abstract escrow to only allow withdrawal if a condition is met.
 */
contract ConditionalEscrow is Escrow {
  /**
  * @dev Returns whether an address is allowed to withdraw their funds. To be
  * implemented by derived contracts.
  */
  function withdrawalAllowed() public view returns (bool);

  function withdraw(address _payee) public {
    require(withdrawalAllowed());
    super.withdraw(_payee);
  }
}

/**
 * @title RefundEscrow
 * @dev Escrow that holds funds for a beneficiary, deposited from multiple parties.
 * The contract owner may close the deposit period, and allow for either withdrawal
 * by the beneficiary, or refunds to the depositors.
 */
contract RefundEscrow is Ownable, ConditionalEscrow {
  enum State { Active, Refunding, Closed }

  event Closed();
  event RefundsEnabled();

  State public state;
  address public beneficiary;

  /**
   * @dev Constructor.
   * @param _beneficiary The beneficiary of the deposits.
   */
  constructor(address _beneficiary) public {
    require(_beneficiary != address(0));
    beneficiary = _beneficiary;
    state = State.Active;
  }

  /**
   * @dev Stores funds that may later be refunded.
   * @param _refundee The address funds will be sent to if a refund occurs.
   */
  function deposit(address _refundee) public payable {
    require(state == State.Active);
    super.deposit(_refundee);
  }

  /**
   * @dev Allows for the beneficiary to withdraw their funds, rejecting
   * further deposits.
   */
  function close() public onlyOwner {
    require(state == State.Active);
    state = State.Closed;
    emit Closed();
  }

  /**
   * @dev Allows for refunds to take place, rejecting further deposits.
   */
  function enableRefunds() public onlyOwner {
    require(state == State.Active);
    state = State.Refunding;
    emit RefundsEnabled();
  }

  /**
   * @dev Withdraws the beneficiary's funds.
   */
  function beneficiaryWithdraw() public {
    require(state == State.Closed);
    beneficiary.transfer(address(this).balance);
  }

  /**
   * @dev Returns whether refundees can withdraw their deposits (be refunded).
   */
  function withdrawalAllowed() public view returns (bool) {
    return state == State.Refunding;
  }
}

/**
 * @title TimedCrowdsale
 * @dev Crowdsale accepting contributions only within a time frame.
 */
contract TimedCrowdsale is Crowdsale {
  using SafeMath for uint256;

  uint256 public openingTime;
  uint256 public closingTime;

  /**
   * @dev Reverts if not in crowdsale time range.
   */
  modifier onlyWhileOpen {
    // solium-disable-next-line security/no-block-members
    require(block.timestamp >= openingTime && block.timestamp <= closingTime);
    _;
  }
  
  event InitTime(uint256 _now, uint256 _openTime, uint256 _closeTime);

  /**
   * @dev Constructor, takes crowdsale opening and closing times.
   * @param _openingTime Crowdsale opening time
   * @param _closingTime Crowdsale closing time
   */
  constructor(uint256 _openingTime, uint256 _closingTime) public {
    // solium-disable-next-line security/no-block-members
    require(_openingTime >= block.timestamp);
    require(_closingTime >= _openingTime);

    openingTime = _openingTime;
    closingTime = _closingTime;
    
    emit InitTime(block.timestamp, openingTime, closingTime);
  }

  /**
   * @dev Checks whether the period in which the crowdsale is open has already elapsed.
   * @return Whether crowdsale period has elapsed
   */
  function hasClosed() public view returns (bool) {
    // solium-disable-next-line security/no-block-members
    return block.timestamp > closingTime;
  }

  /**
   * @dev Extend parent behavior requiring to be within contributing period
   * @param _beneficiary Token purchaser
   * @param _weiAmount Amount of wei contributed
   */
  function _preValidatePurchase(
    address _beneficiary,
    uint256 _weiAmount
  )
    internal
    onlyWhileOpen
  {
    super._preValidatePurchase(_beneficiary, _weiAmount);
  }

}

/**
 * @title FinalizableCrowdsale
 * @dev Extension of Crowdsale where an owner can do extra work
 * after finishing.
 */
contract FinalizableCrowdsale is TimedCrowdsale, Ownable {
  using SafeMath for uint256;

  bool public isFinalized = false;

  event Finalized();

  /**
   * @dev Must be called after crowdsale ends, to do some extra finalization
   * work. Calls the contract's finalization function.
   */
  function finalize() onlyOwner public {
    require(!isFinalized);
    require(hasClosed());

    finalization();
    emit Finalized();

    isFinalized = true;
  }

  /**
   * @dev Can be overridden to add finalization logic. The overriding function
   * should call super.finalization() to ensure the chain of finalization is
   * executed entirely.
   */
  function finalization() internal {
    
  }

}

/**
 * @title RefundableCrowdsale
 * @dev Extension of Crowdsale contract that adds a funding goal, and
 * the possibility of users getting a refund if goal is not met.
 */
contract RefundableCrowdsale is FinalizableCrowdsale {
  using SafeMath for uint256;

  // minimum amount of funds to be raised in weis
  uint256 public goal;

  // refund escrow used to hold funds while crowdsale is running
  RefundEscrow private escrow;

  /**
   * @dev Constructor, creates RefundEscrow.
   * @param _goal Funding goal
   */
  constructor(uint256 _goal) public {
    require(_goal > 0);
    escrow = new RefundEscrow(wallet);
    goal = _goal;
  }

  /**
   * @dev Investors can claim refunds here if crowdsale is unsuccessful
   */
  function claimRefund() public {
    require(isFinalized);
    require(!goalReached());

    escrow.withdraw(msg.sender);
  }

  /**
   * @dev Checks whether funding goal was reached.
   * @return Whether funding goal was reached
   */
  function goalReached() public view returns (bool) {
    // return false;
    return weiRaised >= goal;
  }

  /**
   * @dev escrow finalization task, called when owner calls finalize()
   */
  function finalization() internal {
    if (goalReached()) {
      escrow.close();
      escrow.beneficiaryWithdraw();
    } else {
      escrow.enableRefunds();
    }

    super.finalization();
  }
  
//   event DepositIntoEscrow(address _sender, uint256 _amount);

  /**
   * @dev Overrides Crowdsale fund forwarding, sending funds to escrow.
   */
  function _forwardFunds() internal {
    escrow.deposit.value(msg.value)(msg.sender);
    // emit DepositIntoEscrow(msg.sender, msg.value);
  }

}

/**
 * @title MyCrowdsale
 * @dev Crowdsale that locks tokens from withdrawal until it ends.
 */
contract MyCrowdsale is RefundableCrowdsale {
  using SafeMath for uint256;
  
  // Map of all purchaser's balances (doesn't include bounty amounts)
  mapping(address => uint256) public balances;
  
  // Amount of issued tokens
  uint256 public tokensIssued;
  
  // TODO: Define bonus tokens rate multiplier x1000 (i.e. 1200 is 1.2 x 1000 = 120% x1000 = +20% bonus)
  uint256 public bonusMultiplier;
  
  // Is a crowdsale closed?
  bool public isClose;
  
  // setup
  bool private configSet;
  address public tokenVault;
  

  /**
   * Event for token withdrawal logging
   * @param _receiver who receive the tokens
   * @param _amount amount of tokens sent
   */
  event TokenDelivered(address indexed _receiver, uint256 _amount);
  
  event TokenPurchased(address indexed _receiver, uint256 _amount);

  /**
   * Event for token burning
   * @param _amount amount of tokens going to be burnt
   */
  event ReadyToRoast(uint256 _amount);

  /**
   * Event for token adding by referral program
   * @param beneficiary who got the tokens
   * @param amount amount of tokens added
   */
  event TokenAdded(address indexed beneficiary, uint256 amount);
  
  /**
   * Init crowdsale by setting its params
   * @param _rate Number of token units a buyer gets per wei
   * @param _wallet Address where collected funds will be forwarded to
   * @param _bonusMultiplier bonus tokens rate multiplier x1000
   */
  constructor(
    uint256 _rate, 
    address _wallet,
    uint256 _goal,
    uint256 _bonusMultiplier,
    uint256 _openingTime,
    uint256 _closingTime
  ) public
  Crowdsale(_rate, _wallet)
  TimedCrowdsale(_openingTime, _closingTime)
  RefundableCrowdsale(_goal)
  {
    bonusMultiplier = _bonusMultiplier;
    isClose = true;
  }
  
  function setupTokenVault(address _token, address _tokenVault) public onlyOwner {
    require(!configSet);
    // require(isClose);
    // require(hasClosed());
    require(_token != address(0));

    token = ERC20(_token);
    tokenVault = _tokenVault;  
    
    configSet = true;
  }
  
  event CrowdsaleClose(bool _isClosed);
  
  /**
  * @dev Overrides parent by using transferToken function that will not be impede by whenNotPaused.
  * @param _beneficiary Token purchaser
  * @param _tokenAmount Amount of tokens purchased
  */
  function _processPurchase(address _beneficiary, uint256 _tokenAmount) internal {
    require(!isClose);
    // bool crowdSaleClosed = hasClosed();
    // emit CrowdsaleClose(crowdSaleClosed);
    
    // TODO: checkings
    require(!hasClosed());
    // require(!capReached());
    // require(balances[tokenVault] >= _tokenAmount);
    // require(token.balanceOf(tokenVault) >= _tokenAmount);
    
    token.transferToken(_beneficiary, _tokenAmount);
    tokensIssued = tokensIssued.add(_tokenAmount);
    emit TokenPurchased(_beneficiary, _tokenAmount);
  }

  /**
  * @dev Overrides the way in which ether is converted into tokens.
  * @param _weiAmount Value in wei to be converted into tokens
  * @return Number of tokens that can be purchased with the specified _weiAmount
  */
  function _getTokenAmount(uint256 _weiAmount) internal view returns (uint256) {
    require(_weiAmount > 0);
    require(rate > 0);
    require(bonusMultiplier > 0);
    return _weiAmount.mul(rate).mul(bonusMultiplier).div(1000);
  }
  
  /**
   * @dev Overrides to update crowdsale state based on fund raised
   * @param _beneficiary Token purchaser
   * @param _weiAmount Value in wei to be converted into tokens
   */
  function _postValidatePurchase(address _beneficiary, uint256 _weiAmount) internal {
    // If goal is reached, update the crowdsale state to true, closing the crowdsale
    bool isGoalReached = goalReached();
    if(isGoalReached) {
      isClose = true;
    }
  }

  /**
   * @dev Overrides parent 
   */
  function finalization() internal onlyOwner {
    //Burn remaining tokens
    uint256 _amount = token.balanceOf(tokenVault);
    token.needALight(_amount);
    emit ReadyToRoast(_amount);
    
    super.finalization();
  }
  
  /**
   * @dev Open or closes the crowdsale.
   * @param _close boolean value
   */
  function updateCrowdsaleState(bool _close) public onlyOwner {
    isClose = _close;
  }

  /**
   * @dev set the bonus multiplier.
   * @param _bonusMultiplier Value of the bonus multiplier to be assigned
   */
  function setBonusMultiplier(uint256 _bonusMultiplier) external onlyOwner {
    require(isClose);
    require(_bonusMultiplier > 0);
    bonusMultiplier = _bonusMultiplier;
  }
  
  /**
   * @dev Update the conversion rate when crowdsale is close 
   * @param _rate value of the conversion rate to be assigned
   */
  function updateRate(uint256 _rate) external onlyOwner{
    require(isClose);
    require(_rate > 0);
    rate = _rate;
  }
}