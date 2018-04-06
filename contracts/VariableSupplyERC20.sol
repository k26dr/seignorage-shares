pragma solidity ^0.4.18;

import './ERC20.sol';

contract VariableSupplyERC20 is ERC20 {
  uint public decimals;

  function mint(uint _value) public returns (bool);
  function burn(uint _value) public returns (bool);

  event Mint(uint value, uint newSupply);
  event Burn(uint value, uint newSupply);
}
