// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {
    Initializable
} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {
    AccessControlUpgradeable
} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {
    UUPSUpgradeable
} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {
    EnumerableSet
} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {
    EnumerableMap
} from "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import { Hashes } from "@openzeppelin/contracts/utils/cryptography/Hashes.sol";
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
        address indexed submitter,
        bytes32 dataHash
    );

    // --- Structs ---
    // @deprecated
    struct DataVersion {
        bytes32 dataHash;
        address[] oracles;
        uint256 timestamp;
    }

    // @deprecated
    struct DataItem {
        bytes32 propertyHash;
        bytes32 dataGroupHash;
        bytes32 dataHash;
    }

    struct DataSubmission {
        address oracle;
        uint256 timestamp;
    }

    struct DataCell {
        address oracle;
        uint64 timestamp;
        bytes32 dataHash;
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
    uint256 private constant SEVEN_DAYS = 7 days;

    // @deprecated
    mapping(bytes32 => EnumerableMap.Bytes32ToBytes32Map) private s_dataStorage;
    // Key is composite hash of propertyHash and dataGroupHash to ensure uniqueness
    // @deprecated
    mapping(bytes32 => DataSubmission) private s_dataSubmissions;

    mapping(bytes32 => DataCell) private s_dataCells;

    error EmptyBatchSubmission();
    error ElephantProtocol__DataCellLocked(
        bytes32 propertyHash, bytes32 dataGroupHash, address currentOracle
    );

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
        return Hashes.efficientKeccak256(propertyHash, dataGroupHash);
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
        external
    {
        (bool isNew, address penalizedOracle) =
            _submitDataInternal(propertyHash, dataGroupHash, dataHash);

        if (address(vMahout) != address(0)) {
            if (penalizedOracle != address(0)) {
                vMahout.burn(penalizedOracle, 1 ether);
            }
            if (isNew) {
                vMahout.mint(msg.sender, 1 ether);
            }
        }
    }

    function submitBatchData(DataItem[] calldata items) external {
        uint256 length = items.length;
        uint256 total = 0;
        address[] memory burnAccounts = new address[](length);
        uint256[] memory burnAmounts = new uint256[](length);
        uint256 burnListLength = 0;
        for (uint256 i = 0; i < length;) {
            (bool isNew, address penalizedOracle) = _submitDataInternal(
                items[i].propertyHash, items[i].dataGroupHash, items[i].dataHash
            );
            unchecked {
                i++;
                if (isNew) {
                    total += 1;
                }
            }

            if (penalizedOracle != address(0)) {
                uint256 j = 0;
                for (; j < burnListLength; ++j) {
                    if (burnAccounts[j] == penalizedOracle) {
                        burnAmounts[j] += 1 ether;
                        break;
                    }
                }
                if (j == burnListLength) {
                    burnAccounts[burnListLength] = penalizedOracle;
                    burnAmounts[burnListLength] = 1 ether;
                    unchecked {
                        burnListLength++;
                    }
                }
            }
        }
        if (address(vMahout) != address(0)) {
            for (uint256 k = 0; k < burnListLength;) {
                vMahout.burn(burnAccounts[k], burnAmounts[k]);
                unchecked {
                    ++k;
                }
            }

            if (total > 0) {
                vMahout.mint(msg.sender, total * 1 ether);
            }
        }
    }

    function _submitDataInternal(
        bytes32 propertyHash,
        bytes32 dataGroupHash,
        bytes32 dataHash
    )
        private
        returns (bool isNew, address penalizedOracle)
    {
        address submitter = msg.sender;
        bytes32 identifier =
            _getPropertyHashFieldHash(propertyHash, dataGroupHash);
        DataCell memory currentDataCell = s_dataCells[identifier];
        if (currentDataCell.oracle == address(0)) {
            currentDataCell = _getFromLegacyStorage(propertyHash, dataGroupHash);
        }
        if (currentDataCell.dataHash == dataHash) {
            if (currentDataCell.oracle == submitter) {
                emit DataGroupHeartBeat(
                    propertyHash, dataGroupHash, submitter, dataHash
                );
                s_dataCells[identifier].timestamp = uint64(block.timestamp);
                return (false, address(0));
            } else {
                if (block.timestamp - currentDataCell.timestamp < SEVEN_DAYS) {
                    revert ElephantProtocol__DataCellLocked(
                        propertyHash, dataGroupHash, currentDataCell.oracle
                    );
                }
                penalizedOracle = currentDataCell.oracle;
                emit DataGroupHeartBeat(
                    propertyHash, dataGroupHash, submitter, dataHash
                );
            }
        } else {
            emit DataSubmitted(propertyHash, dataGroupHash, submitter, dataHash);
        }
        s_dataCells[identifier] = DataCell({
            oracle: submitter,
            timestamp: uint64(block.timestamp),
            dataHash: dataHash
        });

        return (true, penalizedOracle);
    }

    function _getFromLegacyStorage(
        bytes32 propertyHash,
        bytes32 dataGroupHash
    )
        private
        view
        returns (DataCell memory)
    {
        (bool exists, bytes32 currentDataHash) =
            s_dataStorage[propertyHash].tryGet(dataGroupHash);
        if (!exists) {
            return DataCell(address(0), 0, bytes32(0));
        }
        bytes32 propertyDataHash =
            _getPropertyHashFieldHash(propertyHash, currentDataHash);
        DataSubmission storage dataSubmision =
            s_dataSubmissions[propertyDataHash];
        return DataCell({
            oracle: dataSubmision.oracle,
            timestamp: uint64(dataSubmision.timestamp),
            dataHash: currentDataHash
        });
    }

    function getDataCell(
        bytes32 propertyHash,
        bytes32 dataGroupHash
    )
        public
        view
        returns (DataCell memory)
    {
        DataCell memory dataCell =
            s_dataCells[_getPropertyHashFieldHash(propertyHash, dataGroupHash)];
        if (dataCell.oracle == address(0)) {
            dataCell = _getFromLegacyStorage(propertyHash, dataGroupHash);
        }
        return dataCell;
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
