pragma solidity ^0.4.18;

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

    MintableERC20 shares;
    MintableERC20 coins;

    address oracle;
    uint price = 1e6; // in ppm-USD, 1e6 = $1
    mapping(uint => Cycle) cycles;

    uint counter = 0;

    function SeignorageShares (address sharesContract, address coinsContract) {
        shares = MintableERC20(sharesContract);
        coins = MintableERC20(coinsContract);

        require(shares.decimals() == 18);
        require(coins.decimals() == 18);

        oracle = msg.sender;

        // start first cycle 
        cycles[++counter] = Cycle(Direction.Neutral, 0, block.number, 0);
    }

    function updatePrice (uint _price) {
        require(msg.sender == oracle);
        price = _price;
    }

    function newCycle () {
        Cycle oldCycle = cycles[counter];
        require(block.number > oldCycle.startBlock + CYCLE_INTERVAL);

        // determine monetary policy for cycle
        uint targetSupply = coins.totalSupply() * price / TARGET_PRICE;
        int vector = targetSupply - coins.totalSupply();
        Direction direction;
        uint magnitude;
        if (vector == 0)
            direction = Direction.Neutral;
        else if (vector < 0) {
            direction = Direction.Contracting;
            magnitude = uint(-vector);
        }
        else {
            direction  = Direction.Expanding;
            magnitude = uint(vector);
        }
            
        cycles[++counter] = Cycle(direction, magnitude, block.number, 0);
        
        // mint coins/shares
        uint printAmount = magnitude * MINT_CONSTANT / 100;
        if (direction == Direction.Contracting)
            shares.mint(printAmount);
        else if (direction == Direction.Expanding)
            coins.mint(printAmount);
    }

    function bid (uint amount) {
        Cycle cycle = cycles[counter];

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
        policy.bids[msg.sender] += amount;
        policy.bidTotal += amount;
    }

    function claim (uint cyleId) {
        Cycle cycle = cycles[cycleId];
        uint bid = cycle.bids[msg.sender];

        require(block.number > cycle.startBlock + AUCTION_DURATION);
        require(msg.sender == bid.user);
        require(bid > 0);
        require(cycle.direction != Direction.Neutral);

        uint amount = bid * cycle.magnitude / cycle.bidTotal;
        if (cycle.direction == Direction.Contracting)
            shares.transfer(amount);
        else if (cycle.direction == Direction.Expanding)
            coins.transfer(amount);

        delete cycle.bids[msg.sender];
    }
}
