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

	function mint(address _to, uint256 _amount) public returns (bool) {
		require(msg.sender == minter);

		totalSupply = totalSupply.add(_amount);
		balances[_to] = balances[_to].add(_amount);

		Mint(_to, _amount);
		Transfer(address(0), _to, _amount);

		return true;
	}

	function burn(uint256 _value) public returns (bool) {
		require(_value <= balances[msg.sender]);
		// no need to require value <= totalSupply, since that would imply the
		// sender's balance is greater than the totalSupply, which *should* be an assertion failure

		address burner = msg.sender;
		balances[burner] = balances[burner].sub(_value);
		totalSupply = totalSupply.sub(_value);

		Burn(burner, _value);
		Transfer(burner, address(0), _value);

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
