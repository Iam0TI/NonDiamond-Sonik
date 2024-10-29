// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

library Errors {
    // @dev Custom errors
    error ZeroAddressDetected();
    error HasClaimedRewardsAlready();
    error UnAuthorizedFunctionCall();
    error InvalidClaim();
    error ZeroValueDetected();
    error UnclaimedTokensStillMuch();
    error WithdrawalFailed();
    error TransferFailed();
    error CannotSetOwnerTwice();
    error CannotSetAddressTwice();
    error NFTNotFound();
    error AirdropClaimEnded();
    error AirdropClaimTimeNotEnded();
    error TotalClaimersExceeded();
    error InsufficientContractBalance();
    // error FeeIsRequired();
    // error FeeNotSet();
}

library Events {
    // @dev events
    event AirdropClaimed(address indexed _user, uint256 indexed _amount);

    event WithdrawalSuccessful(address indexed _owner, uint256 indexed _amount);

    event MerkleRootUpdated(
        bytes32 indexed _oldMerkleRoot,
        bytes32 indexed _newMerkleRoot
    );
    event OwnershipTransferred(
        address indexed _oldOwner,
        uint256 indexed _timestamp,
        address indexed _newOwner
    );
    event AirdropTokenDeposited(
        address indexed _owner,
        uint256 indexed _amount
    );
    event NftRequirementOff(address indexed _owner, uint256 indexed _timestamp);

    event NftRequirementUpdated(
        address indexed _owner,
        uint256 indexed _timestamp,
        address indexed _newNft
    );
    event ClaimTimeUpdated(
        address indexed _owner,
        uint256 indexed _newClaimTimeDuration,
        uint256 indexed _newDeadline
    );

    event SonikCloneCreated(
        address indexed _owner,
        uint256 indexed _timestamp,
        address indexed _sonikClone
    );

    event ClaimersNumberUpdated(
        address indexed _owner,
        uint256 indexed _timestamp,
        uint256 indexed _newClaimersNumber
    );

}

