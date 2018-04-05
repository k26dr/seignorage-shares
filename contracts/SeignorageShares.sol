pragma solidity ^0.4.18;

contract SeignorageShares {
    enum Direction { Neutral, Expanding, Contracting }
    
    struct Policy {
        int vector;
        uint startBlock;
        uint bidTotal;
        mapping(uint => Bid) bids;
    }

    struct Bid {
        address user;
        uint limit;
        uint amount;
    }
    
    uint public constant POLICY_INTERVAL = 1000; // in blocks
    uint public constant AUCTION_DURATION = 900; // in blocks
    uint public constant TARGET_PRICE = 1e6; // == $1

    ERC20 shares;
    ERC20 coins;

    address oracle;
    uint price = 1e6; // in ppm-USD, 1e6 = $1
    mapping(uint => Policy) policies;

    uint bidCounter = 0;
    uint policyCounter = 0;

    function SeignorageShares () {
        oracle = msg.sender;
        policy.startBlock = block.number;
    }

    function updatePrice (uint _price) {
        require(msg.sender == oracle);
        price = _price;
    }

    function newPolicy () {
        require(block.number > policy.startBlock + POLICY_INTERVAL);
        uint targetSupply = coins.totalSupply() * price / TARGET_PRICE;
        int vector = targetSupply - coins.totalSupply();
        policies[++policyCounter] = Policy(vector, block.number, 0);
        
        // mint coins/shares
        if (policy.vector < 0)
            shares.mint(uint(-vector));
        else
            coins.mint(vector);
    }

    function bid (uint amount, uint limit, uint[] bumpOrders) {
        Policy policy = policies[policyCounter];
        require(block.number < policy.startBlock + AUCTION_DURATION);

        // transfer coins/shares to contract
        if (policy.vector < 0)
            coins.transferFrom(msg.sender, address(this), amount);
        else
            shares.transferFrom(msg.sender, address(this), amount);

        // place bid on books
        Bid memory bid = Bid(msg.sender, amount, limit);
        policy.bids[++bidCounter] = bid;
        policy.bidTotal += amount;

        // TODO: bump orders
        // need a good system for this
        // the naive system is to permit any order to be bumped
    }

    function claim (uint policyId, uint bidId) {
        Policy policy = policies[policyId];
        Bid bid = policy.bids[bidId];

        require(block.number > policy.startBlock + AUCTION_DURATION);
        require(msg.sender == bid.user);

        // contracting - user gets shares
        if (policy.vector < 0) 
            shares.transfer(bid.amount * bid.limit / 1e6);
        // expanding - user gets coins
        else 
            coins.transfer(bid.amount * bid.limit / 1e6);

        delete bid;
    }
}
