// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC721} from "../../interfaces/IERC721.sol";
import {MerkleProof} from "../../libraries/MerkleProof.sol";
import {Errors, Events, IERC721Errors, ERC721Utils} from "../../libraries/Utils.sol";
import {LibDiamond} from "../../libraries/LibDiamond.sol";
import {ECDSA} from "../../libraries/ECDSA.sol";
import {ERC721Facet} from "./ERC721Facet.sol";

contract SonikPoapFacet is ERC721Facet {
    /*====================  VIew FUnctions ====================*/

    // @dev returns if airdropTime has ended or not
    function hasAidropTimeEnded() public view returns (bool) {
        LibDiamond.SonikPoapObj storage sonikPoapObj = getWritableSonikObj();
        return block.timestamp > sonikPoapObj.airdropEndTime;
    }

    // @user get current merkle proof
    function getMerkleRoot() external view returns (bytes32) {
        LibDiamond.SonikPoapObj storage sonikPoapObj = getWritableSonikObj();
        return sonikPoapObj.merkleRoot;
    }

    function checkEligibility(bytes32[] calldata _merkleProof) public view returns (bool) {
        sanityCheck(msg.sender);
        if (_hasClaimedAirdrop(msg.sender)) {
            return false;
        }

        // @dev we hash the encoded byte form of the user address and amount to create a leaf
        bytes32 leaf = keccak256(abi.encodePacked(msg.sender));

        LibDiamond.SonikPoapObj storage sonikPoapObj = getWritableSonikObj();
        // @dev check if the merkleProof provided is valid or belongs to the merkleRoot
        return MerkleProof.verify(_merkleProof, sonikPoapObj.merkleRoot, leaf);
    }
    // require msg.sender to sign a message before claiming
    // @user for claiming airdrop

    function claimAirdrop(bytes32[] calldata _merkleProof, bytes32 digest, bytes memory signature) external {
        sanityCheck(msg.sender);
        LibDiamond.SonikPoapObj storage sonikPoapObj = getWritableSonikObj();
        // check if NFT is required
        if (sonikPoapObj.isNftRequired) {
            claimAirdrop(_merkleProof, type(uint256).max, digest, signature);
            return;
        }

        // verify user signature
        if (!_verifySignature(digest, signature)) {
            revert Errors.InvalidSignature();
        }

        // check if User has claimed before
        if (_hasClaimedAirdrop(msg.sender)) {
            revert Errors.HasClaimedRewardsAlready();
        }

        //    checks if User is eligible
        if (!checkEligibility(_merkleProof)) {
            revert Errors.InvalidClaim();
        }

        if (sonikPoapObj.isTimeLocked && hasAidropTimeEnded()) {
            revert Errors.AirdropClaimEnded();
        }

        uint256 _currentNoOfClaims = sonikPoapObj.totalNoOfClaimed;

        if (_currentNoOfClaims + 1 > sonikPoapObj.totalNoOfClaimers) {
            revert Errors.TotalClaimersExceeded();
        }

        sonikPoapObj.totalNoOfClaimed += 1;

        uint256 tokenId = sonikPoapObj.index;
        ++sonikPoapObj.index;
        sonikPoapObj.hasUserClaimedAirdrop[msg.sender] = true;

        _safeMint(msg.sender, tokenId);
        emit Events.AirdropClaimed(msg.sender, tokenId);
    }

    // @user for claiming airdrop with compulsory NFT ownership
    function claimAirdrop(bytes32[] calldata _merkleProof, uint256 _tokenId, bytes32 digest, bytes memory signature)
        public
    {
        sanityCheck(msg.sender);

        if (_tokenId == type(uint256).max) {
            revert Errors.InvalidTokenId();
        }
        if (_hasClaimedAirdrop(msg.sender)) {
            revert Errors.HasClaimedRewardsAlready();
        }

        // verify user signature
        if (!_verifySignature(digest, signature)) {
            revert Errors.InvalidSignature();
        }

        //    checks if User is eligible
        if (!checkEligibility(_merkleProof)) {
            revert Errors.InvalidClaim();
        }

        LibDiamond.SonikPoapObj storage sonikPoapObj = getWritableSonikObj();

        if (sonikPoapObj.isTimeLocked && hasAidropTimeEnded()) {
            revert Errors.AirdropClaimEnded();
        }

        // @dev checks if user has the required NFT
        if (IERC721(sonikPoapObj.nftAddress).balanceOf(msg.sender) > 0) {
            revert Errors.NFTNotFound();
        }

        uint256 _currentNoOfClaims = sonikPoapObj.totalNoOfClaimed;

        if (_currentNoOfClaims + 1 > sonikPoapObj.totalNoOfClaimers) {
            revert Errors.TotalClaimersExceeded();
        }

        sonikPoapObj.totalNoOfClaimed += 1;

        uint256 tokenId = sonikPoapObj.index;
        ++sonikPoapObj.index;
        sonikPoapObj.hasUserClaimedAirdrop[msg.sender] = true;

        _safeMint(msg.sender, tokenId);
        emit Events.AirdropClaimed(msg.sender, tokenId);
    }

    /*====================  OWNER FUnctions ====================*/

    // @user for the contract owner to update the Merkle root
    // @dev updates the merkle state
    function updateMerkleRoot(bytes32 _newMerkleRoot) external {
        onlyOwner();
        LibDiamond.SonikPoapObj storage sonikPoapObj = getWritableSonikObj();
        bytes32 _oldMerkleRoot = sonikPoapObj.merkleRoot;

        sonikPoapObj.merkleRoot = _newMerkleRoot;

        emit Events.MerkleRootUpdated(_oldMerkleRoot, _newMerkleRoot);
    }

    function updateNftRequirement(address _newNft) external {
        sanityCheck(_newNft);
        onlyOwner();
        LibDiamond.SonikPoapObj storage sonikPoapObj = getWritableSonikObj();
        if (_newNft == sonikPoapObj.nftAddress) {
            revert Errors.CannotSetAddressTwice();
        }

        LibDiamond.SonikPoapObj storage statesonikPoapObj = getWritableSonikObj();

        statesonikPoapObj.isNftRequired = true;

        emit Events.NftRequirementUpdated(msg.sender, block.timestamp, _newNft);
    }

    function turnOffNftRequirement() external {
        onlyOwner();
        // LibDiamond.SonikPoapObj storage sonikPoapObj= getWritableSonikObj();

        LibDiamond.SonikPoapObj storage statesonikPoapObj = getWritableSonikObj();

        statesonikPoapObj.isNftRequired = false;
        statesonikPoapObj.nftAddress = address(0);

        emit Events.NftRequirementOff(msg.sender, block.timestamp);
    }

    function updateClaimTime(uint256 _claimTime) external {
        onlyOwner();
        // LibDiamond.SonikPoapObj storage sonikPoapObj= getWritableSonikObj();

        LibDiamond.SonikPoapObj storage statesonikPoapObj = getWritableSonikObj();

        statesonikPoapObj.isTimeLocked = _claimTime != 0;
        statesonikPoapObj.airdropEndTime = block.timestamp + _claimTime;

        emit Events.ClaimTimeUpdated(msg.sender, _claimTime, statesonikPoapObj.airdropEndTime);
    }

    function updateClaimersNumber(uint256 _noOfClaimers) external {
        onlyOwner();
        zeroValueCheck(_noOfClaimers);

        // LibDiamond.SonikPoapObj storage sonikPoapObj= getWritableSonikObj();

        LibDiamond.SonikPoapObj storage statesonikPoapObj = getWritableSonikObj();

        statesonikPoapObj.totalNoOfClaimers = _noOfClaimers;

        emit Events.ClaimersNumberUpdated(msg.sender, block.timestamp, _noOfClaimers);
    }

    /*====================  private functions ====================*/
    function zeroValueCheck(uint256 _amount) private pure {
        if (_amount <= 0) {
            revert Errors.ZeroValueDetected();
        }
    }

    // @dev returns if a user has claimed or not
    function _hasClaimedAirdrop(address _user) private view returns (bool) {
        sanityCheck(_user);
        LibDiamond.SonikPoapObj storage statesonikPoapObj = getWritableSonikObj();
        return statesonikPoapObj.hasUserClaimedAirdrop[_user];
    }

    // verify user signature
    function _verifySignature(bytes32 digest, bytes memory signature) private view returns (bool) {
        return ECDSA.recover(digest, signature) == msg.sender;
    }
}
