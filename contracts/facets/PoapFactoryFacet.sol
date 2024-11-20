// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {LibDiamond} from "../libraries/LibDiamond.sol";
import {SonikPoapFacet} from "./SonikPoapFacet.sol";
import {Errors, Events} from "../libraries/Utils.sol";

contract PoapFactoryFacet {
    function _createSonikPoap(
        string memory _name,
        string memory _symbol,
        string memory _baseURI,
        bytes32 _merkleRoot,
        address _nftAddress,
        uint256 _claimTime,
        uint256 _noOfClaimers
    ) private {
        if (msg.sender == address(0)) {
            revert Errors.ZeroAddressDetected();
        }
        if (_noOfClaimers <= 0) {
            revert Errors.ZeroValueDetected();
        }

        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();

        SonikPoapFacet _newSonikPoap = new SonikPoapFacet();

        uint256 _id = ds.clonePoapCount;

        LibDiamond.SonikPoapObj storage _newSonikPoapObj = ds.sonikContractToPoapObj[address(_newSonikPoap)];

        // Initialize the POAP object
        _newSonikPoapObj._name = _name;
        _newSonikPoapObj._symbol = _symbol;
        _newSonikPoapObj.baseURI = _baseURI;
        _newSonikPoapObj.merkleRoot = _merkleRoot;
        _newSonikPoapObj.nftAddress = _nftAddress;
        _newSonikPoapObj.contractAddress = address(_newSonikPoap);
        _newSonikPoapObj.owner = msg.sender;
        _newSonikPoapObj.claimTime = _claimTime;
        _newSonikPoapObj.totalNoOfClaimers = _noOfClaimers;
        _newSonikPoapObj.isNftRequired = _nftAddress != address(0);
        _newSonikPoapObj.isTimeLocked = _claimTime != 0;
        _newSonikPoapObj.airdropEndTime = block.timestamp + _claimTime;
        _newSonikPoapObj.totalAmountSpent = 0;
        _newSonikPoapObj.totalNoOfClaimed = 0;
        _newSonikPoapObj.index = 0;

        ds.ownerToSonikPoapCloneContracts[msg.sender].push(address(_newSonikPoap));
        ds.allSonikPoapClones.push(address(_newSonikPoap));
        ++ds.clonePoapCount;

        emit Events.SonikPoapCloneCreated(msg.sender, block.timestamp, address(_newSonikPoap));
    }

    // Create POAP with NFT requirement and time lock
    function createSonikPoap(
        string memory _name,
        string memory _symbol,
        string memory _baseURI,
        bytes32 _merkleRoot,
        address _nftAddress,
        uint256 _claimTime,
        uint256 _noOfClaimers
    ) external {
        return _createSonikPoap(_name, _symbol, _baseURI, _merkleRoot, _nftAddress, _claimTime, _noOfClaimers);
    }

    // Create POAP with NFT requirement but no time lock
    function createSonikPoap(
        string memory _name,
        string memory _symbol,
        string memory _baseURI,
        bytes32 _merkleRoot,
        address _nftAddress,
        uint256 _noOfClaimers
    ) external {
        return _createSonikPoap(_name, _symbol, _baseURI, _merkleRoot, _nftAddress, 0, _noOfClaimers);
    }

    // Create basic POAP without NFT requirement or time lock
    function createSonikPoap(
        string memory _name,
        string memory _symbol,
        string memory _baseURI,
        bytes32 _merkleRoot,
        uint256 _noOfClaimers
    ) external {
        return _createSonikPoap(_name, _symbol, _baseURI, _merkleRoot, address(0), 0, _noOfClaimers);
    }

    // Get all POAPs created by a specific owner
    // function getOwnerSonikPoapClones(address _owner) external view returns (LibDiamond.SonikPoapObj[] memory) {
    //     LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
    //     address[] memory cloneContractAddresses = ds.ownerToSonikPoapCloneContracts[_owner];

    //     LibDiamond.SonikPoapObj[] memory sonikPoapObjs = new LibDiamond.SonikPoapObj[](cloneContractAddresses.length);

    //     for (uint256 i = 0; i < cloneContractAddresses.length; i++) {
    //         sonikPoapObjs[i] = ds.sonikContractToPoapObj[cloneContractAddresses[i]];
    //     }
    //     return sonikPoapObjs;
    // }

    // Get all POAP clone addresses
    function getAllSonikPoapClones() external view returns (address[] memory) {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        return ds.allSonikPoapClones;
    }

    // // Read a specific POAP clone's details
    // function readSonikPoapClone(address _sonikAddress) external view returns (LibDiamond.SonikPoapObj memory) {
    //     LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
    //     return ds.sonikContractToPoapObj[_sonikAddress];
    // }

    // Check if an address is a POAP clone
    function isAddressPoapClone(address _sonikAddress) external view returns (bool) {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        return ds.sonikContractToPoapObj[_sonikAddress].contractAddress != address(0);
    }
}
