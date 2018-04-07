pragma solidity ^0.4.18;

import './ERC20.sol';

contract VariableSupplyERC20 is ERC20 {
  uint public decimals;

  function mint(address _to, uint256 _amount) public returns (bool);
  function burn(uint256 _value) public returns (bool);

  event Mint(address indexed to, uint256 amount);
  event Burn(address indexed burner, uint256 value);
}
