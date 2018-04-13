pragma solidity ^0.4.18;

import './VariableSupplyERC20.sol';

contract SeignorageController {
    enum Direction { Neutral, Expanding, Contracting }
    
    struct Cycle {
        Direction direction; // expand or contract
        uint toMint; // when expanding -> number of coins to mint. when contracting -> number of shares to mint
        uint startBlock; // start of cycle
        uint bidTotal; // current cumulative sum of user bids
        mapping(address => uint) bids; // track individual bids by users
    }

    
    uint public constant MINT_CONSTANT = 10; // supply contraction/expansion as a percentage of price change
    uint public constant CYCLE_INTERVAL = 2000; // in blocks
    uint public constant TARGET_PRICE = 1e6; // == $1. in ppm-USD

    VariableSupplyERC20 public shares;
    VariableSupplyERC20 public coins;

    address public oracle;
    uint public coinPrice = 1e6; // in ppm-USD, 1e6 = $1
    uint public sharePrice = 100e6; // in ppm-coins, 1e6 = 1 coin
    mapping(uint => Cycle) public cycles;

    uint public counter = 0;

    function SeignorageController (address sharesContract, address coinsContract) public {
        shares = VariableSupplyERC20(sharesContract);
        coins = VariableSupplyERC20(coinsContract);

        require(shares.decimals() == 18);
        require(coins.decimals() == 18);

        oracle = msg.sender;

        // start first cycle 
        cycles[++counter] = Cycle(Direction.Neutral, 0, block.number, 0);
    }

    // the updated price must be within 10% of the old price
    // this is to prevent accidental mispricings 
    // a change of greater than 10% requires multiple transactions
    function updateCoinPrice (uint _price) public {
        require(msg.sender == oracle);
        require(_price > coinPrice * 9 / 10);
        require(_price < coinPrice * 11 / 10);
        coinPrice = _price;
    }

    // the updated price must be within 10% of the old price
    // this is to prevent accidental mispricings 
    // a change of greater than 10% requires multiple transactions
    function updateSharePrice (uint _price) public {
        require(msg.sender == oracle);
        require(_price > sharePrice * 9 / 10);
        require(_price < sharePrice * 11 / 10);
        sharePrice = _price;
    }

    function newCycle () public {
        Cycle storage oldCycle = cycles[counter];
        require(block.number > oldCycle.startBlock + CYCLE_INTERVAL);

        // burn previous cycle's bids
        if(oldCycle.direction == Direction.Contracting)
            coins.burn(oldCycle.bidTotal);
        if(oldCycle.direction == Direction.Expanding)
            shares.burn(oldCycle.bidTotal);

        // determine monetary policy for cycle
        Direction direction;
        uint toMint;
        uint targetSupply = coins.totalSupply() * coinPrice / TARGET_PRICE;
        if (coinPrice == TARGET_PRICE)
            direction = Direction.Neutral;
        else if (coinPrice < TARGET_PRICE) {
            direction = Direction.Contracting;
            toMint = (coins.totalSupply() - targetSupply) * 1e6 / sharePrice;
        }
        else {
            direction  = Direction.Expanding;
            toMint = (targetSupply - coins.totalSupply()) * MINT_CONSTANT / 100;
        }
            
        cycles[++counter] = Cycle(direction, toMint, block.number, 0);
        
        // mint coins/shares
        if (direction == Direction.Contracting)
            shares.mint(address(this), toMint);
        else if (direction == Direction.Expanding)
            coins.mint(address(this), toMint);
    }

    function bid (uint amount) public {
        Cycle storage cycle = cycles[counter];

        require(block.number < cycle.startBlock + CYCLE_INTERVAL);
        require(cycle.direction != Direction.Neutral);
        require(amount > 1e16);

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

        require(block.number > cycle.startBlock + CYCLE_INTERVAL);
        require(userBid > 0);
        require(cycle.direction != Direction.Neutral);

        uint amount = userBid * cycle.toMint / cycle.bidTotal;
        if (cycle.direction == Direction.Contracting)
            shares.transfer(msg.sender, amount);
        else if (cycle.direction == Direction.Expanding)
            coins.transfer(msg.sender, amount);

        delete cycle.bids[msg.sender];
    }
    
    function userBids (uint cycleId, address user) public view returns (uint) {
        return cycles[cycleId].bids[user];
    }

    // price in ppm-USD
    function currentBidPrice () public view returns (uint) {
        Cycle storage cycle = cycles[counter];
        return cycle.bidTotal * 1e6 / cycle.toMint;
    }
}
