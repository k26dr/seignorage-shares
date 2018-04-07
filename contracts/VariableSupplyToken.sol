pragma solidity ^0.4.18;

import './VariableSupplyERC20.sol';
import './StandardToken.sol';

contract VariableSupplyToken is StandardToken, VariableSupplyERC20 {
    uint public constant decimals = 18;

    string public name; 
    string public symbol;
    address public minter;

    function VariableSupplyToken(string _name, string _symbol, uint initialSupply) public {
        name = _name;
        symbol = _symbol;

        // the minter is temporarily set to the creator of the contract
        // see setMinter(...) comments for how this will be updated
        minter = msg.sender;

        totalSupply = initialSupply;
        balances[msg.sender] = totalSupply;
    }

    function mint(uint _value) public returns (bool) {
        balances[msg.sender] = balances[msg.sender].add(_value);
        totalSupply = totalSupply.add(_value);

        Mint(_value, totalSupply);

        return true;
    }

    function burn(uint _value) public returns (bool) {
        require(_value <= balances[msg.sender]);

        // SafeMath.sub will throw if there is not enough balance.
        balances[msg.sender] = balances[msg.sender].sub(_value);
        totalSupply = totalSupply.sub(_value);

        Burn(_value, totalSupply);

        return true;
    }

    // this function will only be called once after intiialization
    // the SeignorageController contract address is unknown when the token is created
    // the creator of the token is responsible for switching the address of the
    // minter to the SeignorageController contract address. Once that switch is made,
    // it will be impossible to update the minter because the SeignorageController contract has no
    // way of calling this function
    function setMinter(address newMinter) public {
        require(msg.sender == minter);
        minter = newMinter;
    }
}
