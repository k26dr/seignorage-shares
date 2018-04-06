pragma solidity ^0.4.18;

/*
 * ERC20 interface
 * see https://github.com/ethereum/EIPs/issues/20
 */
contract ERC20 {
  uint public totalSupply;

  function balanceOf(address who) constant public returns (uint);
  function allowance(address owner, address spender) constant public returns (uint);

  function transfer(address to, uint value) public returns (bool ok);
  function transferFrom(address from, address to, uint value) public returns (bool ok);
  function approve(address spender, uint value) public returns (bool ok);
  function increaseApproval(address _spender, uint _addedValue) public returns (bool); 
  function decreaseApproval(address _spender, uint _subtractedValue) public returns (bool);

  event Transfer(address indexed from, address indexed to, uint value);
  event Approval(address indexed owner, address indexed spender, uint value);
}
