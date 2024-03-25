// SPDX-License-Identifier: MIT

import "hardhat/console.sol";


pragma solidity ^0.8.20;

import "@openzeppelin/contracts/governance/Governor.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorSettings.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorCountingSimple.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorVotes.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorVotesQuorumFraction.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorTimelockControl.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
}

// percentage off calculate with
contract KarratGovernor is
    AccessControl,
    GovernorSettings,
    GovernorCountingSimple,
    GovernorVotes,
    GovernorTimelockControl
{
    bytes32 public constant PROPOSAL_CREATOR_ROLE =
        keccak256("PROPOSAL_CREATOR_ROLE");
    bytes32 public constant PROPOSAL_CANCELLER_ROLE_1 =
        keccak256("PROPOSAL_CANCELLER_ROLE_1");
    bytes32 public constant PROPOSAL_CANCELLER_ROLE_2 =
        keccak256("PROPOSAL_CANCELLER_ROLE_2");
    bytes32 public constant PROPOSAL_CANCELLER_ROLE_3 =
        keccak256("PROPOSAL_CANCELLER_ROLE_3");

    // events
    event AdminRoleGiven(address indexed canceler, uint256 indexed slot);
    event AdminRejectsProposal(
        address indexed admin,
        uint256 indexed proposalId
    );
    event RejectionOfProposal(uint256 indexed proposalId);
    event ProposalCreatedNumber(uint indexed proposalId);

    //errors
    error RejectionAlreadyProposed();
    error CallerIsNotAdmin();

    //mapping
    // Mapping from proposal ID to a mapping of voter addresses to a boolean indicating whether they have voted
    mapping(uint256 => mapping(address => bool)) public hasRejectedProposal;
    // maps proposal id to rejections
    mapping(uint256 => uint256) public totalRejections;
    // Mapping from proposal ID to the percentage of total tokens the proposal concerns
    mapping(uint256 => uint256) public proposalTokenTotals;
    mapping(uint256 proposalId => ProposalCore) private _proposals;

    address public karratToken;

    address public DAO_TREASURY;

    constructor(
        IVotes _token,
        TimelockController _timelock,
        address _canceller1,
        address _canceller2,
        address _canceller3,
        address karratTokenContract
    )
        Governor("KarratGovernor")
        GovernorSettings(1 /* 1 day */, 3 /* 1 week */, 0)
        GovernorVotes(_token)
        GovernorTimelockControl(_timelock)
    {
        karratTokenContract = karratToken;
        DAO_TREASURY = address(_timelock);
        _canceller1 = canceler1;
        _canceller2 = canceler2;
        _canceller3 = canceler3;
        _grantRole(DEFAULT_ADMIN_ROLE, address(this));
        _grantRole(PROPOSAL_CANCELLER_ROLE_1, _canceller1);
        emit AdminRoleGiven(_canceller1, 0);
        _grantRole(PROPOSAL_CANCELLER_ROLE_2, _canceller2);
        emit AdminRoleGiven(_canceller1, 1);
        _grantRole(PROPOSAL_CANCELLER_ROLE_3, _canceller3);
        emit AdminRoleGiven(_canceller1, 2);
        lastRoleChangeVote = block.timestamp;
        _grantRole(PROPOSAL_CREATOR_ROLE,
        //address(_timelock
        msg.sender);
    }

    uint256 public lastRoleChangeVote;

    address private canceler1;
    address private canceler2;
    address private canceler3;

    // Override functions to include role checks

    function propose(
        address[] memory targets,
        // values 0 needs to be the total number of tokens
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    )
    public
    override(Governor)
    onlyRole(PROPOSAL_CREATOR_ROLE)
    returns(uint256){
        super.propose(targets,
        // values 0 needs to be the total number of tokens
        values,
        calldatas,
        description
        );
    }

    function declareProposalCost(
        uint256 proposalId,
        uint256 totalTokenCost
    ) external onlyRole(PROPOSAL_CREATOR_ROLE){
        proposalTokenTotals[proposalId] = totalTokenCost;
    }
    // {
    //     address proposer = _msgSender();
    //             // check description restriction
    //     if (!_isValidDescriptionForProposer(proposer, description)) {
    //         revert GovernorRestrictedProposer(proposer);
    //     }

    //     // check proposal threshold
    //     uint256 votesThreshold = proposalThreshold();
    //     if (votesThreshold > 0) {
    //         uint256 proposerVotes = getVotes(proposer, clock() - 1);
    //         if (proposerVotes < votesThreshold) {
    //             revert GovernorInsufficientProposerVotes(proposer, proposerVotes, votesThreshold);
    //         }

    //     uint proposalId = _propose(targets, values, calldatas, description, msg.sender);


    // }
    // }

    // function _setCost(uint proposalId, uint totalTokenCost)internal {
    //      proposalTokenTotals[proposalId] = totalTokenCost;
    //       emit ProposalCreatedNumber(proposalId);
    // }


// function _propose(
//     address[] memory targets,
//     uint256[] memory values,
//     bytes[] memory calldatas,
//     string memory description,
//     address proposer
// ) internal virtual override returns (uint256 proposalId) {
//     if (!hasRole(PROPOSAL_CREATOR_ROLE, _msgSender())) {
//         revert CallerIsNotAdmin();
//     }

//     // Call the base implementation and return its value.
//     proposalId = super._propose(targets, values, calldatas, description, proposer);
//        console.log("Calling _propose");

//     // Ensure the proposal ID is returned.
//     return proposalId;
// }

    function initateEmergencyCancel(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) external {
        if (
            !hasRole(PROPOSAL_CANCELLER_ROLE_1, _msgSender()) ||
            !hasRole(PROPOSAL_CANCELLER_ROLE_2, _msgSender()) ||
            !hasRole(PROPOSAL_CANCELLER_ROLE_3, _msgSender())
        ) {
            revert CallerIsNotAdmin();
        }
        if (hasRejectedProposal[proposalId][msg.sender]) {
            revert RejectionAlreadyProposed();
        }

        // Record that the voter has voted on this proposal
        hasRejectedProposal[proposalId][msg.sender] = true;
        // total cancels
        totalRejections[proposalId]++;

        emit AdminRejectsProposal(msg.sender, proposalId);
        if (totalRejections[proposalId] == 2) {
            _cancel(targets, values, calldatas, descriptionHash);
            emit RejectionOfProposal(proposalId);
        }
    }

    function isVoteDue() public view returns (bool) {
        // 6 months = approximately 15778463 seconds
        return (block.timestamp - lastRoleChangeVote) > 15778462;
    }

    function initiateRoleChangeVote(
        address[] memory newCancellers,
        string memory description
    ) public {
        require(isVoteDue(), "It's not yet time to change roles.");

        // Prepare the data for the governance proposal
        address[] memory targets = new address[](1);
        targets[0] = address(this); // Targeting this contract

        uint256[] memory values = new uint256[](1);
        values[0] = 0; // No ETH is sent

        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature(
            "changeCancellorRoles(address,address,address)",
            newCancellers[0],
            newCancellers[1],
            newCancellers[2]
        );

        // Create the proposal
        propose(targets, values, calldatas, description);

        lastRoleChangeVote = block.timestamp; // Reset the timer
    }

    function changeCancellorRoles(
        address newCancellor1,
        address newCancellor2,
        address newCancellor3
    ) public onlyGovernance {
        // Revoke old roles
        _revokeRole(PROPOSAL_CANCELLER_ROLE_1, exposeAddressOne());
        _revokeRole(PROPOSAL_CANCELLER_ROLE_2, exposeAddressTwo());
        _revokeRole(PROPOSAL_CANCELLER_ROLE_3, exposeAddressThree());

        // Grant new roles
        _grantRole(PROPOSAL_CANCELLER_ROLE_1, newCancellor1);
        newCancellor1 = canceler1;
        emit AdminRoleGiven(newCancellor1, 0);
        _grantRole(PROPOSAL_CANCELLER_ROLE_2, newCancellor2);
        newCancellor2 = canceler2;
        emit AdminRoleGiven(newCancellor2, 1);
        _grantRole(PROPOSAL_CANCELLER_ROLE_3, newCancellor3);
        newCancellor3 = canceler3;
        emit AdminRoleGiven(newCancellor3, 2);
    }


    function getProposalMagnitude(
        uint256 proposalId
    ) public view returns (uint256) {
        uint256 DAOSupply = IERC20(karratToken).balanceOf(DAO_TREASURY);
        uint256 tokenCost = proposalTokenTotals[proposalId];

        return tokenCost * 100 /DAOSupply * 100;
    }

    function quorum(uint256 proposalId) public view override(Governor) returns (uint256) {
        return 1;
        // uint256 baseQuorumPercentage = 4; // 4% of total token supply
        // uint256 totalSupply = IERC20(karratToken).balanceOf(DAO_TREASURY);
        // uint256 proposalMagnitude = getProposalMagnitude(proposalId); // Implement this based on your criteria
        // uint256 requiredQuorumPercentage;

        // if (proposalMagnitude <= 10) {
        //     requiredQuorumPercentage = 15;
        // } else if (proposalMagnitude > 10 && proposalMagnitude <= 35) {
        //     requiredQuorumPercentage = 40;
        // } else if (proposalMagnitude > 35 && proposalMagnitude <= 50) {
        //     requiredQuorumPercentage = 50;
        // } else if (proposalMagnitude > 50) {
        //     requiredQuorumPercentage = 75;
        // } else {
        //     requiredQuorumPercentage = baseQuorumPercentage;
        // }

        // return (totalSupply * requiredQuorumPercentage) / 100;
    }

    function exposeAddressOne() public view returns (address) {
        return canceler1;
    }

    function exposeAddressTwo() public view returns (address) {
        return canceler2;
    }

    function exposeAddressThree() public view returns (address) {
        return canceler3;
    }

    // The following functions are overrides required by Solidity.

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(
        bytes4 interfaceId
    ) public view override(AccessControl, Governor) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function votingDelay()
        public
        view
        override(Governor, GovernorSettings)
        returns (uint256)
    {
        return super.votingDelay();
    }

    function votingPeriod()
        public
        view
        override(Governor, GovernorSettings)
        returns (uint256)
    {
        return super.votingPeriod();
    }

    // function quorum(
    //     uint256 blockNumber
    // )
    //     public
    //     view
    //     override(Governor, GovernorVotesQuorumFraction)
    //     returns (uint256)
    // {
    //     return super.quorum(blockNumber);
    // }

    function state(
        uint256 proposalId
    )
        public
        view
        override(Governor, GovernorTimelockControl)
        returns (ProposalState)
    {
        return super.state(proposalId);
    }

    function proposalNeedsQueuing(
        uint256 proposalId
    ) public view override(Governor, GovernorTimelockControl) returns (bool) {
        return super.proposalNeedsQueuing(proposalId);
    }

    function proposalThreshold()
        public
        view
        override(Governor, GovernorSettings)
        returns (uint256)
    {
        return super.proposalThreshold();
    }

    function _queueOperations(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) returns (uint48) {
        return
            super._queueOperations(
                proposalId,
                targets,
                values,
                calldatas,
                descriptionHash
            );
    }

    function _executeOperations(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) {
        super._executeOperations(
            proposalId,
            targets,
            values,
            calldatas,
            descriptionHash
        );
    }

    function _cancel(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) returns (uint256) {
        return super._cancel(targets, values, calldatas, descriptionHash);
    }

    function _executor()
        internal
        view
        override(Governor, GovernorTimelockControl)
        returns (address)
    {
        return super._executor();
    }

    function _getVotes(
        address account,
        uint256 timepoint,
        bytes memory /*params*/
    ) internal view virtual override(Governor, GovernorVotes) returns (uint256) {
        return 1;
    }

}