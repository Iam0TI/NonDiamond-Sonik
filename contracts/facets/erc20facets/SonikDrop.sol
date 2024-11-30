// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {MerkleProof} from "../../libraries/MerkleProof.sol";

import {IERC20} from "../../interfaces/IERC20.sol";
import {IERC721} from "../../interfaces/IERC721.sol";
import {Errors, Events} from "../../libraries/Utils.sol";
import {LibDiamond} from "../../libraries/LibDiamond.sol";
import {ECDSA} from "../../libraries/ECDSA.sol";

// another possible feature is time-locking the airdrop
// i.e people can only claim within a certain time
// owners cannot withdraw tokens within that time

contract SonikDrop {
    bytes32 public merkleRoot;
    address public owner;
    address public tokenAddress;
    address nftAddress; // for nft require drops
    uint256 internal airdropEndTime;
    uint256 internal claimTime;
    uint256 internal totalNoOfClaimers;
    uint256 internal totalNoOfClaimed;

    uint256 internal totalAmountSpent; // total for airdrop token spent

    bool isTimeLocked;
    bool isNftRequired;

    mapping(address user => bool claimed) public hasUserClaimedAirdrop;

    constructor(
        address _owner,
        address _tokenAddress,
        bytes32 _merkleRoot,
        address _nftAddress,
        uint256 _claimTime,
        uint256 _noOfClaimers
    ) {
        merkleRoot = _merkleRoot;
        owner = _owner;
        tokenAddress = _tokenAddress;
        nftAddress = _nftAddress;
        isNftRequired = _nftAddress != address(0);

        claimTime = _claimTime;
        totalNoOfClaimers = _noOfClaimers;

        isTimeLocked = _claimTime != 0;
        airdropEndTime = block.timestamp + _claimTime;
    }
    // @dev prevents zero address from interacting with the contract

    function sanityCheck(address _user) private pure {
        if (_user == address(0)) {
            revert Errors.ZeroAddressDetected();
        }
    }

    function zeroValueCheck(uint256 _amount) private pure {
        if (_amount <= 0) {
            revert Errors.ZeroValueDetected();
        }
    }

    // @dev prevents users from accessing onlyOwner privileges
    function onlyOwner() private view {
        sanityCheck(msg.sender);
        if (msg.sender != owner) {
            revert Errors.UnAuthorizedFunctionCall();
        }
    }

    // @dev returns if airdropTime has ended or not for time locked airdrop
    function hasAidropTimeEnded() public view returns (bool) {
        return block.timestamp > airdropEndTime;
    }

    // @dev checks contract token balance
    function getContractBalance() public view returns (uint256) {
        return IERC20(tokenAddress).balanceOf(address(this));
    }

    // how do we check for eligibility of a user without requiring the amount
    // reason= most users wont know their allocations until they check
    // checking eligibility should then reveal their allocation

    // @user check for eligibility

    function checkEligibility(uint256 _amount, bytes32[] calldata _merkleProof) public view returns (bool) {
        sanityCheck(msg.sender);
        if (hasUserClaimedAirdrop[msg.sender]) {
            return false;
        }

        // @dev we hash the encoded byte form of the user address and amount to create a leaf
        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(msg.sender, _amount))));

        // @dev check if the merkleProof provided is valid or belongs to the merkleRoot
        return MerkleProof.verify(_merkleProof, merkleRoot, leaf);
    }

    // verify user signature

    function _verifySignature(bytes32 digest, bytes memory signature) private view returns (bool) {
        return ECDSA.recover(digest, signature) == msg.sender;
    }

    // require msg.sender to sign a message before claiming
    // @user for claiming airdrop
    function claimAirdrop(uint256 _amount, bytes32[] calldata _merkleProof, bytes32 digest, bytes memory signature)
        external
    {
        sanityCheck(msg.sender);

        // check if NFT is required
        if (isNftRequired) {
            claimAirdrop(_amount, _merkleProof, type(uint256).max, digest, signature);
            return;
        }

        // verify user signature
        if (!_verifySignature(digest, signature)) {
            revert Errors.InvalidSignature();
        }

        // check if User has claimed before
        if (hasUserClaimedAirdrop[msg.sender]) {
            revert Errors.HasClaimedRewardsAlready();
        }

        //    checks if User is eligible
        if (!checkEligibility(_amount, _merkleProof)) {
            revert Errors.InvalidClaim();
        }

        if (isTimeLocked && hasAidropTimeEnded()) {
            revert Errors.AirdropClaimEnded();
        }

        uint256 _currentNoOfClaims = totalNoOfClaimed;

        if (_currentNoOfClaims + 1 > totalNoOfClaimers) {
            revert Errors.TotalClaimersExceeded();
        }
        if (getContractBalance() < _amount) {
            revert Errors.InsufficientContractBalance();
        }

        totalNoOfClaimed += 1;

        hasUserClaimedAirdrop[msg.sender] = true;

        totalAmountSpent += _amount;

        if (!IERC20(tokenAddress).transfer(msg.sender, _amount)) {
            revert Errors.TransferFailed();
        }

        emit Events.AirdropClaimed(msg.sender, _amount);
    }

    // @user for claiming airdrop with compulsory NFT ownership
    function claimAirdrop(
        uint256 _amount,
        bytes32[] calldata _merkleProof,
        uint256 _tokenId,
        bytes32 digest,
        bytes memory signature
    ) public {
        sanityCheck(msg.sender);

        if (_tokenId == type(uint256).max) {
            revert Errors.InvalidTokenId();
        }
        if (hasUserClaimedAirdrop[msg.sender]) {
            revert Errors.HasClaimedRewardsAlready();
        }

        // verify user signature
        if (!_verifySignature(digest, signature)) {
            revert Errors.InvalidSignature();
        }

        //    checks if User is eligible
        if (!checkEligibility(_amount, _merkleProof)) {
            revert Errors.InvalidClaim();
        }

        if (isTimeLocked && hasAidropTimeEnded()) {
            revert Errors.AirdropClaimEnded();
        }

        // @dev checks if user has the required NFT
        if (IERC721(nftAddress).balanceOf(msg.sender) > 0) {
            revert Errors.NFTNotFound();
        }

        uint256 _currentNoOfClaims = totalNoOfClaimed;

        if (_currentNoOfClaims + 1 > totalNoOfClaimers) {
            revert Errors.TotalClaimersExceeded();
        }

        if (getContractBalance() < _amount) {
            revert Errors.InsufficientContractBalance();
        }

        totalNoOfClaimed += 1;

        hasUserClaimedAirdrop[msg.sender] = true;

        totalAmountSpent += _amount;

        if (!IERC20(tokenAddress).transfer(msg.sender, _amount)) {
            revert Errors.TransferFailed();
        }

        emit Events.AirdropClaimed(msg.sender, _amount);
    }

    // @user for the contract owner to update the Merkle root
    // @dev updates the merkle state
    function updateMerkleRoot(bytes32 _newMerkleRoot) external {
        onlyOwner();

        bytes32 _oldMerkleRoot = merkleRoot;
        merkleRoot = _newMerkleRoot;

        emit Events.MerkleRootUpdated(_oldMerkleRoot, _newMerkleRoot);
    }

    // @user For owner to withdraw left over tokens

    /* @dev the withdrawal is only possible if the amount of tokens left in the contract
        is less than the total amount of tokens claimed by the users
    */
    function withdrawLeftOverToken() external {
        onlyOwner();
        uint256 contractBalance = getContractBalance();
        zeroValueCheck(contractBalance);

        if (isTimeLocked) {
            if (!hasAidropTimeEnded()) {
                revert Errors.AirdropClaimTimeNotEnded();
            }
        }

        if (!IERC20(tokenAddress).transfer(owner, contractBalance)) {
            revert Errors.WithdrawalFailed();
        }

        emit Events.WithdrawalSuccessful(msg.sender, contractBalance);
    }

    // @user for owner to fund the airdrop
    function fundAirdrop(uint256 _amount) external {
        onlyOwner();
        zeroValueCheck(_amount);
        if (!IERC20(tokenAddress).transferFrom(msg.sender, address(this), _amount)) {
            revert Errors.TransferFailed();
        }
        emit Events.AirdropTokenDeposited(msg.sender, _amount);
    }

    function updateNftRequirement(address _newNft) external {
        sanityCheck(_newNft);
        onlyOwner();

        if (_newNft == nftAddress) {
            revert Errors.CannotSetAddressTwice();
        }

        isNftRequired = true;

        emit Events.NftRequirementUpdated(msg.sender, block.timestamp, _newNft);
    }

    function turnOffNftRequirement() external {
        onlyOwner();

        isNftRequired = false;
        nftAddress = address(0);

        emit Events.NftRequirementOff(msg.sender, block.timestamp);
    }

    function updateClaimTime(uint256 _claimTime) external {
        onlyOwner();

        isTimeLocked = _claimTime != 0;
        airdropEndTime = block.timestamp + _claimTime;

        emit Events.ClaimTimeUpdated(msg.sender, _claimTime, airdropEndTime);
    }

    function updateClaimersNumber(uint256 _noOfClaimers) external {
        onlyOwner();
        zeroValueCheck(_noOfClaimers);

        totalNoOfClaimers = _noOfClaimers;

        emit Events.ClaimersNumberUpdated(msg.sender, block.timestamp, _noOfClaimers);
    }
}
