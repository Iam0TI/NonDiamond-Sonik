// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {MerkleProof} from "../libraries/MerkleProof.sol";
import {IERC20} from "../interfaces/IERC20.sol";
import {IERC721} from "../interfaces/IERC721.sol";
import {Errors, Events} from "../libraries/Utils.sol";
import {LibDiamond} from "../libraries/LibDiamond.sol";
import {ECDSA} from "../libraries/ECDSA.sol";

// another possible feature is time-locking the airdrop
// i.e people can only claim within a certain time
// owners cannot withdraw tokens within that time

contract SonikDrop {
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
        LibDiamond.SonikDropObj memory sonikObj = readSonikObj();
        if (msg.sender != sonikObj.owner) {
            revert Errors.UnAuthorizedFunctionCall();
        }
    }

    function readSonikObj()
        public
        view
        returns (LibDiamond.SonikDropObj memory)
    {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        return ds.sonikContractToObj[address(this)];
    }

    function getWritableSonikObj(
        uint256 _id
    )
        private
        view
        returns (
            LibDiamond.SonikDropObj storage,
            LibDiamond.SonikDropObj storage
        )
    {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        LibDiamond.SonikDropObj storage stateSonikObj = ds.sonikContractToObj[
            address(this)
        ];
        LibDiamond.SonikDropObj storage sonikClone = ds.allSonikDropClones[_id];
        return (stateSonikObj, sonikClone);
    }

    // @dev returns if a user has claimed or not
    function _hasClaimedAirdrop(address _user) private view returns (bool) {
        sanityCheck(_user);
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        return ds.hasUserClaimedAirdrop[_user][address(this)];
    }

    // @dev returns if airdropTime has ended or not
    function hasAidropTimeEnded() public view returns (bool) {
        LibDiamond.SonikDropObj memory sonikObj = readSonikObj();
        return block.timestamp > sonikObj.airdropEndTime;
    }

    // @dev checks contract token balance
    function getContractBalance() public view returns (uint256) {
        LibDiamond.SonikDropObj memory sonikObj = readSonikObj();
        return IERC20(sonikObj.tokenAddress).balanceOf(address(this));
    }

    // @user check for eligibility
    function checkEligibility(
        address _user,
        uint256 _amount,
        bytes32[] calldata _merkleProof
    ) public view returns (bool) {
        sanityCheck(_user);
        if (_hasClaimedAirdrop(msg.sender)) {
            return false;
        }

        // @dev we hash the encoded byte form of the user address and amount to create a leaf
        bytes32 leaf = keccak256(abi.encodePacked(msg.sender, _amount));

        LibDiamond.SonikDropObj memory sonikObj = readSonikObj();

        // @dev check if the merkleProof provided is valid or belongs to the merkleRoot
        return MerkleProof.verify(_merkleProof, sonikObj.merkleRoot, leaf);
    }

    function _verifySignature(
        bytes32 digest,
        bytes memory signature
    ) private view returns (bool) {
        return ECDSA.recover(digest, signature) == msg.sender;
    }

    // require msg.sender to sign a message before claiming
    // @user for claiming airdrop
    function claimAirdrop(
        uint256 _amount,
        bytes32[] calldata _merkleProof,
        bytes32 digest,
        bytes memory signature
    ) external {
        sanityCheck(msg.sender);
        LibDiamond.SonikDropObj memory sonikObj = readSonikObj();
        // check if NFT is required
        if (sonikObj.isNftRequired) {
            claimAirdrop(_amount, _merkleProof, 0);
            return;
        }

        if(!_verifySignature(digest, signature)){
            revert Errors.InvalidSignature();
        }

        // check if User has claimed before
        if (_hasClaimedAirdrop(msg.sender)) {
            revert Errors.HasClaimedRewardsAlready();
        }

        //    checks if User is eligible
        if (!checkEligibility(msg.sender, _amount, _merkleProof)) {
            revert Errors.InvalidClaim();
        }

        if (sonikObj.isTimeLocked && hasAidropTimeEnded()) {
            revert Errors.AirdropClaimEnded();
        }

        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();

        (
            LibDiamond.SonikDropObj storage stateSonikObj,
            LibDiamond.SonikDropObj storage stateSonikClone
        ) = getWritableSonikObj(sonikObj.id);

        ds.hasUserClaimedAirdrop[msg.sender][address(this)] = true;
        stateSonikObj.totalAmountSpent += _amount;
        stateSonikClone.totalAmountSpent += _amount;

        if (!IERC20(sonikObj.tokenAddress).transfer(msg.sender, _amount)) {
            revert Errors.TransferFailed();
        }

        emit Events.AirdropClaimed(msg.sender, _amount);
    }

    // @user for claiming airdrop with compulsory NFT ownership
    function claimAirdrop(
        uint256 _amount,
        bytes32[] calldata _merkleProof,
        uint256 _tokenId
    ) public {
        sanityCheck(msg.sender);
        if (_hasClaimedAirdrop(msg.sender)) {
            revert Errors.HasClaimedRewardsAlready();
        }

        //    checks if User is eligible
        if (!checkEligibility(msg.sender, _amount, _merkleProof)) {
            revert Errors.InvalidClaim();
        }

        LibDiamond.SonikDropObj memory sonikObj = readSonikObj();

        if (sonikObj.isTimeLocked && hasAidropTimeEnded()) {
            revert Errors.AirdropClaimEnded();
        }

        // @dev checks if user has the required NFT
        if (IERC721(sonikObj.nftAddress).ownerOf(_tokenId) != msg.sender) {
            revert Errors.NFTNotFound();
        }

        uint256 _currentNoOfClaims = sonikObj.totalNoOfClaimed;

        if (_currentNoOfClaims + 1 > sonikObj.totalNoOfClaimers) {
            revert Errors.TotalClaimersExceeded();
        }

        if (getContractBalance() < _amount) {
            revert Errors.InsufficientContractBalance();
        }

        (
            LibDiamond.SonikDropObj storage stateSonikObj,
            LibDiamond.SonikDropObj storage stateSonikClone
        ) = getWritableSonikObj(sonikObj.id);

        stateSonikObj.totalNoOfClaimed += 1;
        stateSonikClone.totalNoOfClaimed += 1;

        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        ds.hasUserClaimedAirdrop[msg.sender][address(this)] = true;

        stateSonikObj.totalAmountSpent += _amount;
        stateSonikClone.totalAmountSpent += _amount;

        if (!IERC20(sonikObj.tokenAddress).transfer(msg.sender, _amount)) {
            revert Errors.TransferFailed();
        }

        emit Events.AirdropClaimed(msg.sender, _amount);
    }

    // @user for the contract owner to update the Merkle root
    // @dev updates the merkle state
    function updateMerkleRoot(bytes32 _newMerkleRoot) external {
        onlyOwner();
        LibDiamond.SonikDropObj memory sonikObj = readSonikObj();
        bytes32 _oldMerkleRoot = sonikObj.merkleRoot;

        (
            LibDiamond.SonikDropObj storage stateSonikObj,
            LibDiamond.SonikDropObj storage stateSonikClone
        ) = getWritableSonikObj(sonikObj.id);

        stateSonikObj.merkleRoot = _newMerkleRoot;
        stateSonikClone.merkleRoot = _newMerkleRoot;

        emit Events.MerkleRootUpdated(_oldMerkleRoot, _newMerkleRoot);
    }

    // @user get current merkle proof
    function getMerkleRoot() external view returns (bytes32) {
        onlyOwner();
        LibDiamond.SonikDropObj memory sonikObj = readSonikObj();
        return sonikObj.merkleRoot;
    }

    // @user For owner to withdraw left over tokens

    /* @dev the withdrawal is only possible if the amount of tokens left in the contract
        is less than the total amount of tokens claimed by the users
    */
    function withdrawLeftOverToken() external {
        onlyOwner();
        uint256 contractBalance = getContractBalance();
        zeroValueCheck(contractBalance);
        LibDiamond.SonikDropObj memory sonikObj = readSonikObj();

        if (sonikObj.isTimeLocked) {
            if (!hasAidropTimeEnded()) {
                revert Errors.AirdropClaimTimeNotEnded();
            }
        }

        if (
            !IERC20(sonikObj.tokenAddress).transfer(
                sonikObj.owner,
                contractBalance
            )
        ) {
            revert Errors.WithdrawalFailed();
        }

        emit Events.WithdrawalSuccessful(msg.sender, contractBalance);
    }

    // @user for owner to fund the airdrop
    function fundAirdrop(uint256 _amount) external {
        onlyOwner();
        zeroValueCheck(_amount);
        LibDiamond.SonikDropObj memory sonikObj = readSonikObj();
        if (
            !IERC20(sonikObj.tokenAddress).transferFrom(
                msg.sender,
                address(this),
                _amount
            )
        ) {
            revert Errors.TransferFailed();
        }
        emit Events.AirdropTokenDeposited(msg.sender, _amount);
    }

    function updateNftRequirement(address _newNft) external {
        sanityCheck(_newNft);
        onlyOwner();
        LibDiamond.SonikDropObj memory sonikObj = readSonikObj();
        if (_newNft == sonikObj.nftAddress) {
            revert Errors.CannotSetAddressTwice();
        }

        (
            LibDiamond.SonikDropObj storage stateSonikObj,
            LibDiamond.SonikDropObj storage stateSonikClone
        ) = getWritableSonikObj(sonikObj.id);

        stateSonikObj.isNftRequired = true;
        stateSonikClone.isNftRequired = true;

        emit Events.NftRequirementUpdated(msg.sender, block.timestamp, _newNft);
    }

    function turnOffNftRequirement() external {
        onlyOwner();
        LibDiamond.SonikDropObj memory sonikObj = readSonikObj();
        (
            LibDiamond.SonikDropObj storage stateSonikObj,
            LibDiamond.SonikDropObj storage stateSonikClone
        ) = getWritableSonikObj(sonikObj.id);

        stateSonikObj.isNftRequired = false;
        stateSonikObj.nftAddress = address(0);

        stateSonikClone.isNftRequired = false;
        stateSonikClone.nftAddress = address(0);

        emit Events.NftRequirementOff(msg.sender, block.timestamp);
    }

    function updateClaimTime(uint256 _claimTime) external {
        onlyOwner();
        LibDiamond.SonikDropObj memory sonikObj = readSonikObj();
        (
            LibDiamond.SonikDropObj storage stateSonikObj,
            LibDiamond.SonikDropObj storage stateSonikClone
        ) = getWritableSonikObj(sonikObj.id);

        stateSonikObj.isTimeLocked = _claimTime != 0;
        stateSonikObj.airdropEndTime = block.timestamp + _claimTime;

        stateSonikClone.isTimeLocked = _claimTime != 0;
        stateSonikClone.airdropEndTime = block.timestamp + _claimTime;

        emit Events.ClaimTimeUpdated(
            msg.sender,
            _claimTime,
            stateSonikObj.airdropEndTime
        );
    }

    function updateClaimersNumber(uint256 _noOfClaimers) external {
        onlyOwner();
        zeroValueCheck(_noOfClaimers);

        LibDiamond.SonikDropObj memory sonikObj = readSonikObj();
        (
            LibDiamond.SonikDropObj storage stateSonikObj,
            LibDiamond.SonikDropObj storage stateSonikClone
        ) = getWritableSonikObj(sonikObj.id);

        stateSonikObj.totalNoOfClaimers = _noOfClaimers;
        stateSonikClone.totalNoOfClaimers = _noOfClaimers;

        emit Events.ClaimersNumberUpdated(
            msg.sender,
            block.timestamp,
            _noOfClaimers
        );
    }
}
