pragma solidity ^0.4.18;

import './VariableSupplyERC20.sol';

contract SeignorageShares {
    enum Direction { Neutral, Expanding, Contracting }
    
    struct Cycle {
        Direction direction; // expand or contract
        uint magnitude; // amount to expand/contract by 
        uint startBlock; // start of cycle
        uint bidTotal; // current amount of shares/coins posted for exchange
        mapping(address => uint) bids; // amount of shares/coins posted for exchange by user
    }

    // supply contraction/expansion as a percentage of price change
    uint public constant MINT_CONSTANT = 10;
    uint public constant CYCLE_INTERVAL = 1000; // in blocks
    uint public constant AUCTION_DURATION = 900; // in blocks
    uint public constant TARGET_PRICE = 1e6; // == $1. in ppm-USD

    VariableSupplyERC20 shares;
    VariableSupplyERC20 coins;

    address oracle;
    uint price = 1e6; // in ppm-USD, 1e6 = $1
    mapping(uint => Cycle) cycles;

    uint counter = 0;

    function SeignorageShares (address sharesContract, address coinsContract) public {
        shares = VariableSupplyERC20(sharesContract);
        coins = VariableSupplyERC20(coinsContract);

        require(shares.decimals() == 18);
        require(coins.decimals() == 18);

        oracle = msg.sender;

        // start first cycle 
        cycles[++counter] = Cycle(Direction.Neutral, 0, block.number, 0);
    }

    function updatePrice (uint _price) public {
        require(msg.sender == oracle);
        price = _price;
    }

    function newCycle () public {
        Cycle storage oldCycle = cycles[counter];
        require(block.number > oldCycle.startBlock + CYCLE_INTERVAL);

        // determine monetary policy for cycle
        Direction direction;
        uint magnitude;
        uint targetSupply = coins.totalSupply() * price / TARGET_PRICE;
        if (targetSupply == coins.totalSupply())
            direction = Direction.Neutral;
        else if (targetSupply < coins.totalSupply()) {
            direction = Direction.Contracting;
            magnitude = coins.totalSupply() - targetSupply;
        }
        else {
            direction  = Direction.Expanding;
            magnitude = targetSupply - coins.totalSupply();
        }
            
        cycles[++counter] = Cycle(direction, magnitude, block.number, 0);
        
        // mint coins/shares
        uint printAmount = magnitude * MINT_CONSTANT / 100;
        if (direction == Direction.Contracting)
            shares.mint(printAmount);
        else if (direction == Direction.Expanding)
            coins.mint(printAmount);
    }

    function bid (uint amount) public {
        Cycle storage cycle = cycles[counter];

        require(block.number < cycle.startBlock + AUCTION_DURATION);
        require(cycle.direction != Direction.Neutral);

        // transfer coins/shares to contract
        // .transferFrom will throw an error if the user has not 
        // called .approve(amount) in a separate transaction first
        if (cycle.direction == Direction.Contracting)
            coins.transferFrom(msg.sender, address(this), amount);
        else if (cycle.direction == Direction.Expanding)
            shares.transferFrom(msg.sender, address(this), amount);

        // add bid to books
        cycle.bids[msg.sender] += amount;
        cycle.bidTotal += amount;
    }

    function claim (uint cycleId) public {
        Cycle storage cycle = cycles[cycleId];
        uint userBid = cycle.bids[msg.sender];

        require(block.number > cycle.startBlock + AUCTION_DURATION);
        require(userBid > 0);
        require(cycle.direction != Direction.Neutral);

        uint amount = userBid * cycle.magnitude / cycle.bidTotal;
        if (cycle.direction == Direction.Contracting)
            shares.transfer(msg.sender, amount);
        else if (cycle.direction == Direction.Expanding)
            coins.transfer(msg.sender, amount);

        delete cycle.bids[msg.sender];
    }
}
