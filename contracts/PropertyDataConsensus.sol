// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { Initializable } from
    "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { AccessControlUpgradeable } from
    "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { UUPSUpgradeable } from
    "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { EnumerableSet } from
    "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { EnumerableMap } from
    "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import { VMahout } from "./VMahout.sol";

/**
 * @title PropertyDataConsensus
 * @notice Permissionless consensus system for property data with UUPS upgradeability
 */
contract PropertyDataConsensus is
    Initializable,
    AccessControlUpgradeable,
    UUPSUpgradeable
{
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableMap for EnumerableMap.Bytes32ToBytes32Map;

    event DataSubmitted(
        bytes32 indexed propertyHash,
        bytes32 indexed dataGroupHash,
        address indexed submitter,
        bytes32 dataHash
    );
    event MinimumConsensusUpdated(uint256 oldValue, uint256 newValue);
    event DataGroupConsensusUpdated(
        bytes32 indexed dataGroupHash, uint256 oldValue, uint256 newValue
    );
    event DataGroupHeartBeat(
        bytes32 indexed propertyHash,
        bytes32 indexed dataGroupHash,
        bytes32 indexed dataHash,
        address submitter
    );

    // --- Structs ---
    struct DataVersion {
        bytes32 dataHash;
        address[] oracles;
        uint256 timestamp;
    }

    struct DataItem {
        bytes32 propertyHash;
        bytes32 dataGroupHash;
        bytes32 dataHash;
    }

    struct DataSubmission {
        address oracle;
        uint256 timestamp;
    }

    // @deprecated there is no consensus rule for the oracle submission anymore
    uint256 public minimumConsensus;

    // @deprecated we don't need to store what used to be a submission data anymore
    mapping(bytes32 => mapping(bytes32 => EnumerableSet.AddressSet)) private
        _submissionData;
    mapping(bytes32 => bytes32) private _currentConsensusDataHash;

    // @deprecated we don't store consensus log anymore
    mapping(bytes32 => DataVersion[]) private _consensusLog;

    VMahout public vMahout;

    // @deprecated this is not used anymore
    mapping(bytes32 => uint256) public consensusRequired;

    bytes32 public constant LEXICON_ORACLE_MANAGER_ROLE =
        keccak256("LEXICON_ORACLE_MANAGER_ROLE");

    mapping(bytes32 => EnumerableMap.Bytes32ToBytes32Map) private _dataStorage;
    mapping(bytes32 => DataSubmission) private _dataSubmissions;

    error EmptyBatchSubmission();

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function _getPropertyHashFieldHash(
        bytes32 propertyHash,
        bytes32 dataGroupHash
    )
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(propertyHash, dataGroupHash));
    }

    /**
     * @notice Initialize the contract
     * @param initialAdmin Address that will be granted DEFAULT_ADMIN_ROLE and ORACLE_MANAGER_ROLE.
     */
    function initialize(address initialAdmin) external initializer {
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, initialAdmin);
    }

    function submitData(
        bytes32 propertyHash,
        bytes32 dataGroupHash,
        bytes32 dataHash
    )
        public
    {
        _submitDataInternal(propertyHash, dataGroupHash, dataHash);
        if (address(vMahout) != address(0)) {
            vMahout.mint(msg.sender, 1 ether);
        }
    }

    function submitBatchData(DataItem[] calldata items) public {
        uint256 length = items.length;
        if (length == 0) {
            revert EmptyBatchSubmission();
        }
        unchecked {
            for (uint256 i = 0; i < length; i++) {
                _submitDataInternal(
                    items[i].propertyHash,
                    items[i].dataGroupHash,
                    items[i].dataHash
                );
            }
        }
        if (address(vMahout) != address(0)) {
            vMahout.mint(msg.sender, length * 1 ether);
        }
    }

    function _submitDataInternal(
        bytes32 propertyHash,
        bytes32 dataGroupHash,
        bytes32 dataHash
    )
        internal
    {
        address submitter = msg.sender;
        (bool exists, bytes32 currentDataHash) =
            _dataStorage[propertyHash].tryGet(dataGroupHash);
        if (exists && currentDataHash == dataHash) {
            if (_dataSubmissions[dataHash].oracle == submitter) {
                emit DataGroupHeartBeat(
                    propertyHash, dataGroupHash, dataHash, submitter
                );
                _dataSubmissions[dataHash].timestamp = block.timestamp;
                return;
            }
        }
        _dataStorage[propertyHash].set(dataGroupHash, dataHash);
        _dataSubmissions[dataHash] = DataSubmission(submitter, block.timestamp);
        emit DataSubmitted(propertyHash, dataGroupHash, submitter, dataHash);
    }

    function getCurrentFieldDataHash(
        bytes32 propertyHash,
        bytes32 dataGroupHash
    )
        public
        view
        returns (bytes32)
    {
        return _dataStorage[propertyHash].get(dataGroupHash);
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyRole(DEFAULT_ADMIN_ROLE)
    { }

    /**
     * @notice Sets the vMahout token address used for minting rewards to oracles.
     * @dev Can only be called by an account with DEFAULT_ADMIN_ROLE.
     * @param _vMahout The address of the vMahout token contract.
     */
    function setVMahout(address _vMahout)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        vMahout = VMahout(_vMahout);
    }
}
