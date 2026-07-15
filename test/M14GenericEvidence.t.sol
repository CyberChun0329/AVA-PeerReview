// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AVACoreTypes} from "../src/core/AVACoreTypes.sol";
import {AVAAuthorityMatrix} from "../src/core/AVAAuthorityMatrix.sol";
import {AVAIdentityRegistry} from "../src/core/AVAIdentityRegistry.sol";
import {AVADisclosurePolicyRegistry} from "../src/core/AVADisclosurePolicyRegistry.sol";
import {AVAEvidenceRegistry} from "../src/core/AVAEvidenceRegistry.sol";
import {AVACoreRulePackageRegistry} from "../src/core/AVACoreRulePackageRegistry.sol";
import {M14ApplicationFixture, M14PermissiveApplicationModule} from "./helpers/M14ApplicationFixture.sol";
import "./helpers/M14CorePackageFixture.sol";

contract M14GenericEvidenceActor {
    function registerPolicy(
        AVADisclosurePolicyRegistry registry,
        bytes32 appId,
        bytes32 roleKey,
        bytes32 authorityId,
        bytes32 policyKey
    ) external returns (uint256) {
        return registry.registerPolicy(appId, roleKey, authorityId, policyKey, "m14-policy", "ipfs://m14-policy");
    }

    function registerEvidence(
        AVAEvidenceRegistry registry,
        AVAEvidenceRegistry.EvidenceRegistrationInput calldata input
    ) external returns (uint256) {
        return registry.registerEvidence(input);
    }
}

contract M14GenericEvidenceRegistryTest is M14ApplicationFixture, M14CorePackageFixture {
    bytes32 private constant ROLE_KEY = keccak256("m14.generic-evidence.role");
    bytes32 private constant SUBJECT_ID = keccak256("m14.generic-evidence.subject");
    bytes32 private constant PACKAGE_ROLE = keccak256("m14.generic-evidence.package-role");
    bytes32 private constant PACKAGE_SUBJECT = keccak256("m14.generic-evidence.package-subject");

    function testM145GenericEvidenceUsesAppScopedRoleWithoutLegacyRoleAssignment() public {
        AVAIdentityRegistry identityRegistry = new AVAIdentityRegistry(applicationRegistry);
        AVAAuthorityMatrix appAuthority = new AVAAuthorityMatrix(applicationRegistry, identityRegistry);
        identityRegistry.assignSubject(
            address(this), PEER_REVIEW_APP_ID, PACKAGE_ROLE, PACKAGE_SUBJECT, "ipfs://m14-package-subject"
        );
        appAuthority.setPermission(
            PEER_REVIEW_APP_ID, PACKAGE_ROLE, AVACoreTypes.ACTION_REGISTER_RULE_PACKAGE, true
        );
        AVACoreRulePackageRegistry corePackageRegistry =
            new AVACoreRulePackageRegistry(applicationRegistry, appAuthority);
        uint256 packageId = corePackageRegistry.registerRulePackage(
            _corePackageInput(
                PEER_REVIEW_APP_ID,
                DEFAULT_WORKFLOW,
                PACKAGE_ROLE,
                PACKAGE_SUBJECT,
                1,
                keccak256("m14.generic-evidence.compatibility"),
                "ipfs://m14-generic-evidence-package"
            ),
            _coreBindings(new M14PermissiveApplicationModule(PEER_REVIEW_APP_ID))
        );
        AVADisclosurePolicyRegistry policyRegistry =
            new AVADisclosurePolicyRegistry(applicationRegistry, appAuthority);
        AVAEvidenceRegistry genericEvidenceRegistry =
            new AVAEvidenceRegistry(appAuthority, identityRegistry, corePackageRegistry, policyRegistry);
        M14GenericEvidenceActor actor = new M14GenericEvidenceActor();
        identityRegistry.assignSubject(
            address(actor), PEER_REVIEW_APP_ID, ROLE_KEY, SUBJECT_ID, "ipfs://m14-generic-evidence-subject"
        );
        appAuthority.setPermission(
            PEER_REVIEW_APP_ID, ROLE_KEY, AVACoreTypes.ACTION_REGISTER_DISCLOSURE_POLICY, true
        );
        appAuthority.setPermission(PEER_REVIEW_APP_ID, ROLE_KEY, AVACoreTypes.ACTION_REGISTER_EVIDENCE, true);

        uint256 policyId = actor.registerPolicy(
            policyRegistry, PEER_REVIEW_APP_ID, ROLE_KEY, SUBJECT_ID, keccak256("m14-generic-policy")
        );
        uint256 evidenceId = actor.registerEvidence(
            genericEvidenceRegistry,
            AVAEvidenceRegistry.EvidenceRegistrationInput({
                appId: PEER_REVIEW_APP_ID,
                workflowKey: DEFAULT_WORKFLOW,
                packageId: packageId,
                roleKey: ROLE_KEY,
                subjectId: SUBJECT_ID,
                commitment: keccak256("m14-generic-evidence"),
                evidenceTypeHash: keccak256("m14-generic-evidence-type"),
                disclosurePolicyId: policyId,
                authorityId: SUBJECT_ID,
                uri: "ipfs://m14-generic-evidence"
            })
        );

        AVACoreTypes.EvidenceRecord memory evidence = genericEvidenceRegistry.getEvidence(evidenceId);
        require(evidence.appId == PEER_REVIEW_APP_ID, "evidence app missing");
        require(evidence.packageId == packageId, "evidence package missing");
        require(evidence.subjectId == SUBJECT_ID, "evidence subject missing");

        (bool compactOk, bytes memory compactData) = address(genericEvidenceRegistry).staticcall(
            abi.encodeWithSignature("getEvidenceReference(uint256)", evidenceId)
        );
        require(compactOk, "compact evidence reader missing");
        require(
            keccak256(compactData)
                == keccak256(
                    abi.encode(
                        evidence.id,
                        evidence.appId,
                        evidence.workflowKey,
                        evidence.packageId,
                        evidence.commitment,
                        evidence.evidenceTypeHash,
                        evidence.subjectId,
                        evidence.disclosurePolicyId,
                        evidence.authorityId,
                        evidence.status,
                        evidence.lastLifecycleRecordId,
                        evidence.replacementEvidenceId
                    )
                ),
            "compact evidence context changed"
        );

        AVACoreTypes.DisclosurePolicyRecord memory policy = policyRegistry.getPolicy(policyId);
        (bool policyRefOk, bytes memory policyRefData) = address(policyRegistry).staticcall(
            abi.encodeWithSignature("getPolicyReference(uint256)", policyId)
        );
        require(policyRefOk, "compact policy reader missing");
        require(
            keccak256(policyRefData)
                == keccak256(abi.encode(policy.id, policy.appId, policy.policyKey, policy.authorityId, policy.active)),
            "compact policy context changed"
        );
        (bool activePolicyOk,) = address(policyRegistry).staticcall(
            abi.encodeWithSignature("requireActivePolicyReference(uint256,bytes32)", policyId, PEER_REVIEW_APP_ID)
        );
        require(activePolicyOk, "compact active-policy gate missing");
        (bool unknownPolicyOk,) = address(policyRegistry).staticcall(
            abi.encodeWithSignature("requireActivePolicyReference(uint256,bytes32)", policyId + 1, PEER_REVIEW_APP_ID)
        );
        require(!unknownPolicyOk, "unknown policy passed compact gate");
    }
}
