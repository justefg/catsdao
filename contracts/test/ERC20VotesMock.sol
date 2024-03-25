// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

contract ERC20VotesMock is ERC20Votes {
  constructor() ERC20("Vote Token", "VTT") EIP712("", "") {}
}