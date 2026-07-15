// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AVAApplicationRegistry} from "../../src/AVAApplicationRegistry.sol";
import {AVACoreTypes} from "../../src/core/AVACoreTypes.sol";
import {IAVAApplicationModule} from "../../src/interfaces/IAVAApplicationModule.sol";
import {RuleModuleIdentity} from "../../src/interfaces/IRuleModuleIdentity.sol";
import {PeerReviewTypes} from "../../src/apps/peerreview/PeerReviewTypes.sol";

abstract contract M14ApplicationFixture {
    bytes32 internal constant PEER_REVIEW_APP_ID = PeerReviewTypes.APP_ID;
    bytes32 internal constant DEFAULT_WORKFLOW = keccak256("default-review-workflow");

    AVAApplicationRegistry internal applicationRegistry;

    function setUp() public virtual {
        applicationRegistry = new AVAApplicationRegistry();
        applicationRegistry.registerApplication(
            PEER_REVIEW_APP_ID,
            keccak256("peer-review-application-identity-v1"),
            keccak256("peer-review-application-authority"),
            "ipfs://peer-review-application"
        );
    }
}

contract M14PermissiveApplicationModule is IAVAApplicationModule, RuleModuleIdentity {
    bytes32 public immutable APP_ID;

    constructor(bytes32 appId) {
        if (appId == bytes32(0)) revert AVACoreTypes.EmptyValue();
        APP_ID = appId;
    }

    function applicationId() external view returns (bytes32) {
        return APP_ID;
    }

    function validateGovernedObject(GovernedObjectContext calldata context) external view {
        _requireApp(context.appId, context.packageId);
    }

    function validateRecognisedStateFormation(RecognisedStateFormationContext calldata context) external view {
        _requireApp(context.appId, context.packageId);
    }

    function validateRecognisedStateTransition(RecognisedStateTransitionContext calldata context) external view {
        _requireApp(context.appId, context.packageId);
    }

    function validateEvidence(EvidenceContext calldata context) external view {
        _requireApp(context.appId, context.packageId);
    }

    function validateDownstreamRecord(DownstreamRecordContext calldata context) external view {
        _requireApp(context.appId, context.packageId);
    }

    function _requireApp(bytes32 appId, uint256 packageId) private view {
        if (appId != APP_ID) revert AVACoreTypes.InvalidState(packageId);
    }

    function _moduleConfigurationHash() internal view override returns (bytes32) {
        return APP_ID;
    }
}
