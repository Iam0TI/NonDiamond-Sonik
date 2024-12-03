// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC721} from "../../interfaces/IERC721.sol";
import {MerkleProof} from "../../libraries/MerkleProof.sol";
import {Errors, Events, IERC721Errors, ERC721Utils} from "../../libraries/Utils.sol";
import {LibDiamond} from "../../libraries/LibDiamond.sol";
import {ECDSA} from "../../libraries/ECDSA.sol";

import {ERC721URIStorage} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

contract SonikPoapFacet is ERC721URIStorage {
    /*====================    Variable  ====================*/
    bytes32 merkleRoot;
    mapping(address => bool) hasUserClaimedAirdrop;
    bool isNftRequired;
    bool isTimeLocked;
    bool isTokenInitialized;
    address nftAddress;
    address contractAddress;
    address owner;
    uint256 claimTime;
    uint256 airdropEndTime;
    uint256 totalAmountSpent;
    uint256 totalNoOfClaimers;
    uint256 totalNoOfClaimed;
    uint256 index;

    constructor(string _name, string _symbol) ERC721(_name, _symbol) {
        owner = msg.sender;
    }

    function sanityCheck(address _user) internal pure {
        if (_user == address(0)) {
            revert Errors.ZeroAddressDetected();
        }
    }

    // @dev prevents users from accessing onlyOwner privileges
    function onlyOwner() internal view {
        sanityCheck(msg.sender);

        if (msg.sender != owner) {
            revert Errors.UnAuthorizedFunctionCall();
        }
    }
    /*====================  VIew FUnctions ====================*/

    // @dev returns if airdropTime has ended or not
    function hasAidropTimeEnded() public view returns (bool) {
        return block.timestamp > airdropEndTime;
    }

    // @user get current merkle proof
    function getMerkleRoot() external view returns (bytes32) {
        return merkleRoot;
    }

    function checkEligibility(bytes32[] calldata _merkleProof) public view returns (bool) {
        sanityCheck(msg.sender);
        if (_hasClaimedAirdrop(msg.sender)) {
            return false;
        }

        // @dev we hash the encoded byte form of the user address and amount to create a leaf
        bytes32 leaf = keccak256(abi.encodePacked(msg.sender));

        // @dev check if the merkleProof provided is valid or belongs to the merkleRoot
        return MerkleProof.verify(_merkleProof, merkleRoot, leaf);
    }
    // require msg.sender to sign a message before claiming
    // @user for claiming airdrop

    function claimAirdrop(bytes32[] calldata _merkleProof, bytes32 digest, bytes memory signature) external {
        sanityCheck(msg.sender);

        // check if NFT is requiredss
        if (isNftRequired) {
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

        if (isTimeLocked && hasAidropTimeEnded()) {
            revert Errors.AirdropClaimEnded();
        }

        uint256 _currentNoOfClaims = totalNoOfClaimed;

        if (_currentNoOfClaims + 1 > totalNoOfClaimers) {
            revert Errors.TotalClaimersExceeded();
        }

        totalNoOfClaimed += 1;

        uint256 tokenId = index;
        ++index;
        hasUserClaimedAirdrop[msg.sender] = true;

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

        totalNoOfClaimed += 1;

        uint256 tokenId = index;
        ++index;
        hasUserClaimedAirdrop[msg.sender] = true;

        _safeMint(msg.sender, tokenId);
        emit Events.AirdropClaimed(msg.sender, tokenId);
    }

    /*====================  OWNER FUnctions ====================*/

    // @user for the contract owner to update the Merkle root
    // @dev updates the merkle
    function updateMerkleRoot(bytes32 _newMerkleRoot) external {
        onlyOwner();

        bytes32 _oldMerkleRoot = merkleRoot;

        merkleRoot = _newMerkleRoot;

        emit Events.MerkleRootUpdated(_oldMerkleRoot, _newMerkleRoot);
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
        // LibDiamond.SonikPoapObj storage sonikPoapObj= getWritableSonikObj();

        isNftRequired = false;
        nftAddress = address(0);

        emit Events.NftRequirementOff(msg.sender, block.timestamp);
    }

    function updateClaimTime(uint256 _claimTime) external {
        onlyOwner();
        // LibDiamond.SonikPoapObj storage sonikPoapObj= getWritableSonikObj();

        isTimeLocked = _claimTime != 0;
        airdropEndTime = block.timestamp + _claimTime;

        emit Events.ClaimTimeUpdated(msg.sender, _claimTime, airdropEndTime);
    }

    function updateClaimersNumber(uint256 _noOfClaimers) external {
        onlyOwner();
        zeroValueCheck(_noOfClaimers);

        // LibDiamond.SonikPoapObj storage sonikPoapObj= getWritableSonikObj();

        totalNoOfClaimers = _noOfClaimers;

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

        return hasUserClaimedAirdrop[_user];
    }

    // verify user signature
    function _verifySignature(bytes32 digest, bytes memory signature) private view returns (bool) {
        return ECDSA.recover(digest, signature) == msg.sender;
    }
}
