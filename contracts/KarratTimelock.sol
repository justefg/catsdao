// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "@openzeppelin/contracts/governance/TimelockController.sol";

contract CatsDaoTimelock is TimelockController {
    constructor(uint minDelay) TimelockController(minDelay, new address[](0), new address[](0), msg.sender) {

    }

    modifier onlyAdmin() {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "only admin");
        _;
    }

    function initialize(address governor, address executor) public onlyAdmin {
        _grantRole(PROPOSER_ROLE, governor);
        _grantRole(CANCELLER_ROLE, governor);
        _grantRole(EXECUTOR_ROLE, executor);
    }
}