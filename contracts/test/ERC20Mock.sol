// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ERC20Mock is ERC20 {
    constructor() ERC20("Token Mock", "MCK") {
    }

    function mint(address _holder, uint256 _value) external {
        _mint(_holder, _value);
    }
}