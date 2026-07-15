// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AVASkeletonFixture, MutableIdentityAntiAbuseModule} from "./helpers/AVASkeletonFixture.sol";
import {AVADataTypes} from "../src/AVADataTypes.sol";
import {AVARulePackageRegistry} from "../src/AVARulePackageRegistry.sol";
import {ZKStandingComputationRegistry} from "../src/ZKStandingComputationRegistry.sol";
import {RejectingEvidenceLifecycleModule} from "../src/modules/ExampleFutureProofModules.sol";
import {IZKStandingCredentialIssuer} from "../src/interfaces/IZKStandingCredentialIssuer.sol";
import {IZKProofVerifier} from "../src/interfaces/IZKProofVerifier.sol";

contract RetainedSameDomainPermissiveVerifier is IZKProofVerifier {
    function verify(bytes32 contextHash, SchnorrProof calldata) external pure returns (bool) {
        return contextHash != bytes32(0);
    }

    function proofDomain() external pure returns (bytes32) {
        return keccak256("AVA_SCHNORR_DISCLOSURE_V1");
    }
}

contract AVASecurityHistoricalPackageClosureTest is AVASkeletonFixture {
    function testRetainedDisclosureProofFailsClosedWhenVerifierRuntimeChanges() public {
        uint256 policyId = _registerDisclosurePolicy("security-disclosure-verifier-drift");
        bytes32 subjectCommitment = _subjectCommitmentForSecret(7);
        bytes32 objectId = keccak256("security-disclosure-verifier-drift-object");
        bytes32 contextHash = zkProofRegistry.computeDisclosureContextHash(
            PEER_REVIEW_APP_ID,
            DEFAULT_WORKFLOW,
            AVADataTypes.AVAStage.Verification,
            AVADataTypes.Action.RegisterEvidence,
            objectId,
            AVADataTypes.Role.Panel,
            policyId,
            subjectCommitment
        );
        _registerZkDisclosureProof(
            zkProofRegistry,
            DEFAULT_WORKFLOW,
            AVADataTypes.Action.RegisterEvidence,
            objectId,
            AVADataTypes.Role.Panel,
            policyId,
            subjectCommitment
        );
        require(zkProofRegistry.hasVerifiedProof(contextHash), "valid disclosure proof missing");

        RetainedSameDomainPermissiveVerifier replacement = new RetainedSameDomainPermissiveVerifier();
        vm.etch(address(zkProofRegistry.verifier()), address(replacement).code);
        require(!zkProofRegistry.hasVerifiedProof(contextHash), "verifier drift left disclosure proof usable");
    }

    function testRetainedStandingProofFailsClosedWhenVerifierRuntimeChanges() public {
        bytes32 subjectCommitment = _subjectCommitmentForSecret(7);
        uint256 proofReceiptId = _createM66StandingProofReceipt(
            DEFAULT_WORKFLOW, subjectCommitment, "security-standing-verifier-drift"
        );
        uint256 packageId = rulePackageRegistry.getRulePackage(PEER_REVIEW_APP_ID, DEFAULT_WORKFLOW).packageId;
        require(
            zkStandingComputationRegistry.standingProofSupportsCredential(
                proofReceiptId, packageId, subjectCommitment, _m422VectorKey(), _m422CategoryHash(), 40
            ),
            "valid standing proof missing"
        );

        RetainedSameDomainPermissiveVerifier replacement = new RetainedSameDomainPermissiveVerifier();
        vm.etch(address(zkStandingComputationRegistry.verifier()), address(replacement).code);
        require(
            !zkStandingComputationRegistry.standingProofSupportsCredential(
                proofReceiptId, packageId, subjectCommitment, _m422VectorKey(), _m422CategoryHash(), 40
            ),
            "verifier drift left standing proof usable"
        );
    }
    function testStandingFormulaAndSourceSetUseDistinctAuthorityActions() public {
        ZKStandingComputationRegistry.StandingProofInput memory input = _m65StandingProofInput(
            DEFAULT_WORKFLOW, _subjectCommitmentForSecret(7), "security-distinct-standing-actions"
        );
        authorityMatrix.setPermission(
            AVADataTypes.Role.Panel, AVADataTypes.Action.RegisterStandingSourceSetCommitment, false
        );
        uint256 formulaId = _registerM68Formula(input, "security-distinct-standing-actions");

        authorityMatrix.setPermission(AVADataTypes.Role.Panel, AVADataTypes.Action.RegisterStandingFormula, false);
        authorityMatrix.setPermission(
            AVADataTypes.Role.Panel, AVADataTypes.Action.RegisterStandingSourceSetCommitment, true
        );
        uint256 evidenceId = _registerM68SourceSetEvidence(DEFAULT_WORKFLOW, "security-distinct-standing-actions");
        uint256 sourceSetId =
            _registerM68SourceSetCommitment(formulaId, input, evidenceId, "security-distinct-standing-actions");
        require(sourceSetId != 0, "source set did not use its distinct authority action");
    }

    function testOrdinaryCredentialBecomesUnusableAfterPackageIdentityDrift() public {
        bytes32 workflowKey = keccak256("security-credential-package-drift");
        MutableIdentityAntiAbuseModule mutableModule = _registerMutableWorkflow(workflowKey);
        uint256 computationId =
            _createM423StandingComputationRecord(workflowKey, "security-credential-package-drift", 50);
        uint256 credentialId = standingCredentialRegistry.issueCredential(
            AVADataTypes.Role.Panel,
            _m422CredentialInputForComputation(
                computationId, block.timestamp + 7 days, "ipfs://security-credential-package-drift"
            )
        );
        require(standingCredentialRegistry.isCredentialActive(credentialId), "credential setup failed");

        mutableModule.setBlockedAction(AVADataTypes.Action.ResolveChallenge);
        _requirePackageIdentityInvalid(workflowKey);
        require(
            !standingCredentialRegistry.isCredentialActive(credentialId),
            "identity-invalid package kept ordinary credential active"
        );
    }

    function testOrdinaryCredentialRejectsIssuanceAfterPackageIdentityDrift() public {
        bytes32 workflowKey = keccak256("security-credential-issue-package-drift");
        MutableIdentityAntiAbuseModule mutableModule = _registerMutableWorkflow(workflowKey);
        uint256 computationId =
            _createM423StandingComputationRecord(workflowKey, "security-credential-issue-package-drift", 50);

        mutableModule.setBlockedAction(AVADataTypes.Action.ResolveChallenge);
        _requirePackageIdentityInvalid(workflowKey);
        try standingCredentialRegistry.issueCredential(
            AVADataTypes.Role.Panel,
            _m422CredentialInputForComputation(
                computationId, block.timestamp + 7 days, "ipfs://security-credential-issue-package-drift"
            )
        ) {
            revert("ordinary credential issued from identity-invalid package");
        } catch Error(string memory reason) {
            require(
                keccak256(bytes(reason)) != keccak256("ordinary credential issued from identity-invalid package"),
                reason
            );
        } catch {}
    }

    function testZKStandingProofRejectsRegistrationAfterPackageIdentityDrift() public {
        bytes32 workflowKey = keccak256("security-zk-standing-package-drift");
        MutableIdentityAntiAbuseModule mutableModule = _registerMutableWorkflow(workflowKey);
        ZKStandingComputationRegistry.StandingProofInput memory input =
            _m65StandingProofInput(workflowKey, _subjectCommitmentForSecret(7), "security-zk-standing-package-drift");
        (input,,,) = _bindM93StandingProofInput(input, "security-zk-standing-package-drift");
        bytes32 contextHash = zkStandingComputationRegistry.computeStandingComputationContextHash(input);

        mutableModule.setBlockedAction(AVADataTypes.Action.ResolveChallenge);
        _requirePackageIdentityInvalid(workflowKey);
        try zkStandingComputationRegistry.registerStandingProof(input, _makeSchnorrProof(contextHash, 7, 19)) {
            revert("zk standing proof registered from identity-invalid package");
        } catch Error(string memory reason) {
            require(
                keccak256(bytes(reason)) != keccak256("zk standing proof registered from identity-invalid package"),
                reason
            );
        } catch {}
    }

    function testStandingSourceSetRejectsRegistrationAfterPackageIdentityDrift() public {
        bytes32 workflowKey = keccak256("security-standing-source-set-package-drift");
        MutableIdentityAntiAbuseModule mutableModule = _registerMutableWorkflow(workflowKey);
        ZKStandingComputationRegistry.StandingProofInput memory input = _m65StandingProofInput(
            workflowKey, _subjectCommitmentForSecret(7), "security-standing-source-set-package-drift"
        );
        uint256 formulaId = _registerM68Formula(input, "security-standing-source-set-package-drift");
        uint256 evidenceId = _registerM68SourceSetEvidence(workflowKey, "security-standing-source-set-package-drift");

        mutableModule.setBlockedAction(AVADataTypes.Action.ResolveChallenge);
        _requirePackageIdentityInvalid(workflowKey);
        try standingFormulaRegistry.registerSourceSetCommitment(
            AVADataTypes.Role.Panel,
            _m68SourceSetCommitmentInput(formulaId, input, evidenceId, "security-standing-source-set-package-drift")
        ) {
            revert("standing source set recorded from identity-invalid package");
        } catch Error(string memory reason) {
            require(
                keccak256(bytes(reason)) != keccak256("standing source set recorded from identity-invalid package"),
                reason
            );
        } catch {}
    }

    function testZKCredentialBecomesUnusableAfterPackageIdentityDrift() public {
        bytes32 workflowKey = keccak256("security-zk-credential-package-drift");
        MutableIdentityAntiAbuseModule mutableModule = _registerMutableWorkflow(workflowKey);
        bytes32 subjectCommitment = _subjectCommitmentForSecret(7);
        ZKStandingComputationRegistry.StandingProofInput memory input =
            _m65StandingProofInput(workflowKey, subjectCommitment, "security-zk-credential-package-drift");
        (input,,,) = _bindM93StandingProofInput(input, "security-zk-credential-package-drift");
        bytes32 contextHash = zkStandingComputationRegistry.computeStandingComputationContextHash(input);
        uint256 proofReceiptId =
            zkStandingComputationRegistry.registerStandingProof(input, _makeSchnorrProof(contextHash, 7, 19));
        uint256 packageId = rulePackageRegistry.getRulePackage(PEER_REVIEW_APP_ID, workflowKey).packageId;
        IZKStandingCredentialIssuer.ZKStandingCredentialInput memory credentialInput =
            _m66CredentialInput(proofReceiptId, packageId, subjectCommitment, "security-zk-credential-package-drift");
        uint256 credentialId = zkStandingCredentialRegistry.issueCredential(AVADataTypes.Role.Panel, credentialInput);
        require(
            zkStandingCredentialRegistry.credentialProves(
                credentialId, packageId, subjectCommitment, input.vectorKey, input.categoryHash, input.threshold
            ),
            "zk credential setup failed"
        );

        mutableModule.setBlockedAction(AVADataTypes.Action.ResolveChallenge);
        _requirePackageIdentityInvalid(workflowKey);
        require(
            !zkStandingCredentialRegistry.credentialProves(
                credentialId, packageId, subjectCommitment, input.vectorKey, input.categoryHash, input.threshold
            ),
            "identity-invalid package kept zk credential usable"
        );
    }

    function testEvidenceLifecycleCanVetoOrdinaryCredentialIssuance() public {
        bytes32 workflowKey = keccak256("security-credential-lifecycle-veto");
        _registerRulePackageWithFutureProofModules(
            workflowKey,
            valueExecutionAdapter,
            standingComputationModule,
            rulePackageLifecycleModule,
            new RejectingEvidenceLifecycleModule(AVADataTypes.Action.IssueStandingCredential),
            disclosureExecutionModule,
            1,
            keccak256("ava-m4-21-compatible"),
            false,
            "ipfs://security-credential-lifecycle-veto"
        );
        uint256 computationId =
            _createM423StandingComputationRecord(workflowKey, "security-credential-lifecycle-veto", 50);

        try standingCredentialRegistry.issueCredential(
            AVADataTypes.Role.Panel,
            _m422CredentialInputForComputation(
                computationId, block.timestamp + 7 days, "ipfs://security-credential-lifecycle-veto"
            )
        ) {
            revert("credential evidence lifecycle veto was bypassed");
        } catch Error(string memory reason) {
            require(keccak256(bytes(reason)) != keccak256("credential evidence lifecycle veto was bypassed"), reason);
        } catch {}
    }

    function testEvidenceLifecycleCanVetoZKCredentialIssuance() public {
        bytes32 workflowKey = keccak256("security-zk-credential-lifecycle-veto");
        _registerRulePackageWithFutureProofModules(
            workflowKey,
            valueExecutionAdapter,
            standingComputationModule,
            rulePackageLifecycleModule,
            new RejectingEvidenceLifecycleModule(AVADataTypes.Action.IssueStandingCredential),
            disclosureExecutionModule,
            1,
            keccak256("ava-m4-21-compatible"),
            false,
            "ipfs://security-zk-credential-lifecycle-veto"
        );
        bytes32 subjectCommitment = _subjectCommitmentForSecret(7);
        ZKStandingComputationRegistry.StandingProofInput memory input =
            _m65StandingProofInput(workflowKey, subjectCommitment, "security-zk-credential-lifecycle-veto");
        (input,,,) = _bindM93StandingProofInput(input, "security-zk-credential-lifecycle-veto");
        bytes32 contextHash = zkStandingComputationRegistry.computeStandingComputationContextHash(input);
        uint256 proofReceiptId =
            zkStandingComputationRegistry.registerStandingProof(input, _makeSchnorrProof(contextHash, 7, 19));
        uint256 packageId = rulePackageRegistry.getRulePackage(PEER_REVIEW_APP_ID, workflowKey).packageId;

        try zkStandingCredentialRegistry.issueCredential(
            AVADataTypes.Role.Panel,
            _m66CredentialInput(proofReceiptId, packageId, subjectCommitment, "security-zk-credential-lifecycle-veto")
        ) {
            revert("zk credential evidence lifecycle veto was bypassed");
        } catch Error(string memory reason) {
            require(keccak256(bytes(reason)) != keccak256("zk credential evidence lifecycle veto was bypassed"), reason);
        } catch {}
    }

    function testEvidenceLifecycleCanVetoStandingSourceSetRegistration() public {
        bytes32 workflowKey = keccak256("security-source-set-lifecycle-veto");
        _registerWorkflowWithEvidenceLifecycle(
            workflowKey,
            new RejectingEvidenceLifecycleModule(AVADataTypes.Action.RegisterStandingSourceSetCommitment),
            "security-source-set-lifecycle-veto"
        );
        ZKStandingComputationRegistry.StandingProofInput memory input =
            _m65StandingProofInput(workflowKey, _subjectCommitmentForSecret(7), "security-source-set-lifecycle-veto");
        uint256 formulaId = _registerM68Formula(input, "security-source-set-lifecycle-veto");
        uint256 evidenceId = _registerM68SourceSetEvidence(workflowKey, "security-source-set-lifecycle-veto");

        try standingFormulaRegistry.registerSourceSetCommitment(
            AVADataTypes.Role.Panel,
            _m68SourceSetCommitmentInput(formulaId, input, evidenceId, "security-source-set-lifecycle-veto")
        ) {
            revert("source-set evidence lifecycle veto was bypassed");
        } catch Error(string memory reason) {
            require(keccak256(bytes(reason)) != keccak256("source-set evidence lifecycle veto was bypassed"), reason);
        } catch {}
    }

    function testEvidenceLifecycleCanVetoSourceSetCompletenessRegistration() public {
        bytes32 workflowKey = keccak256("security-completeness-lifecycle-veto");
        _registerWorkflowWithEvidenceLifecycle(
            workflowKey,
            new RejectingEvidenceLifecycleModule(AVADataTypes.Action.RegisterSourceSetCompletenessAttestation),
            "security-completeness-lifecycle-veto"
        );
        ZKStandingComputationRegistry.StandingProofInput memory input =
            _m65StandingProofInput(workflowKey, _subjectCommitmentForSecret(7), "security-completeness-lifecycle-veto");
        (, uint256 sourceSetId) = _registerM68FormulaAndSourceSet(input, "security-completeness-lifecycle-veto");
        uint256 evidenceId =
            _registerM68SourceSetEvidence(workflowKey, "security-completeness-lifecycle-veto-attestation");

        try standingFormulaRegistry.registerSourceSetCompletenessAttestation(
            AVADataTypes.Role.Panel,
            _m92SourceSetCompletenessAttestationInput(sourceSetId, evidenceId, "security-completeness-lifecycle-veto")
        ) {
            revert("completeness evidence lifecycle veto was bypassed");
        } catch Error(string memory reason) {
            require(keccak256(bytes(reason)) != keccak256("completeness evidence lifecycle veto was bypassed"), reason);
        } catch {}
    }

    function testEvidenceLifecycleCanVetoStandingComputationStatementRegistration() public {
        bytes32 workflowKey = keccak256("security-statement-lifecycle-veto");
        _registerWorkflowWithEvidenceLifecycle(
            workflowKey,
            new RejectingEvidenceLifecycleModule(AVADataTypes.Action.RegisterStandingComputationStatement),
            "security-statement-lifecycle-veto"
        );
        ZKStandingComputationRegistry.StandingProofInput memory input =
            _m65StandingProofInput(workflowKey, _subjectCommitmentForSecret(7), "security-statement-lifecycle-veto");
        (, uint256 sourceSetId) = _registerM68FormulaAndSourceSet(input, "security-statement-lifecycle-veto");
        uint256 evidenceId = _registerM68SourceSetEvidence(workflowKey, "security-statement-lifecycle-veto-statement");
        uint256 attestationId =
            _registerM92SourceSetCompletenessAttestation(sourceSetId, evidenceId, "security-statement-lifecycle-veto");

        try standingFormulaRegistry.registerStandingComputationStatement(
            AVADataTypes.Role.Panel,
            _m91ComputationStatementInput(
                sourceSetId, attestationId, input, evidenceId, "security-statement-lifecycle-veto"
            )
        ) {
            revert("statement evidence lifecycle veto was bypassed");
        } catch Error(string memory reason) {
            require(keccak256(bytes(reason)) != keccak256("statement evidence lifecycle veto was bypassed"), reason);
        } catch {}
    }

    function testEvidenceLifecycleCanVetoZKStandingProofRegistration() public {
        bytes32 workflowKey = keccak256("security-zk-proof-lifecycle-veto");
        _registerWorkflowWithEvidenceLifecycle(
            workflowKey,
            new RejectingEvidenceLifecycleModule(AVADataTypes.Action.RegisterStandingProof),
            "security-zk-proof-lifecycle-veto"
        );
        ZKStandingComputationRegistry.StandingProofInput memory input =
            _m65StandingProofInput(workflowKey, _subjectCommitmentForSecret(7), "security-zk-proof-lifecycle-veto");
        (input,,,) = _bindM93StandingProofInput(input, "security-zk-proof-lifecycle-veto");
        bytes32 contextHash = zkStandingComputationRegistry.computeStandingComputationContextHash(input);

        try zkStandingComputationRegistry.registerStandingProof(input, _makeSchnorrProof(contextHash, 7, 19)) {
            revert("zk proof evidence lifecycle veto was bypassed");
        } catch Error(string memory reason) {
            require(keccak256(bytes(reason)) != keccak256("zk proof evidence lifecycle veto was bypassed"), reason);
        } catch {}
    }

    function testEvidenceLifecycleCanVetoAuditRecord() public {
        bytes32 workflowKey = keccak256("security-attestation-lifecycle-veto");
        _registerRulePackageWithFutureProofModules(
            workflowKey,
            valueExecutionAdapter,
            standingComputationModule,
            rulePackageLifecycleModule,
            new RejectingEvidenceLifecycleModule(AVADataTypes.Action.RecordAttestation),
            disclosureExecutionModule,
            1,
            keccak256("ava-m4-21-compatible"),
            false,
            "ipfs://security-attestation-lifecycle-veto"
        );
        uint256 evidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            workflowKey,
            keccak256("security-attestation-lifecycle-evidence"),
            "ipfs://security-attestation-lifecycle-evidence",
            "audit-evidence",
            0
        );

        try auditModule.recordAttestation(
            AVADataTypes.Role.Panel,
            workflowKey,
            AVADataTypes.Action.RecordAttestation,
            bytes32(evidenceId),
            evidenceId,
            keccak256("security-attestation-hash"),
            keccak256("panel-authority"),
            "procedure-audit",
            "ipfs://security-attestation"
        ) {
            revert("attestation evidence lifecycle veto was bypassed");
        } catch Error(string memory reason) {
            require(keccak256(bytes(reason)) != keccak256("attestation evidence lifecycle veto was bypassed"), reason);
        } catch {}
    }

    function testEvidenceReceiptAttestationRejectsArbitraryObjectAlias() public {
        uint256 evidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            keccak256("security-attestation-target-evidence"),
            "ipfs://security-attestation-target-evidence",
            "audit-evidence",
            0
        );
        bool reverted;
        try auditModule.recordAttestation(
            AVADataTypes.Role.Panel,
            DEFAULT_WORKFLOW,
            AVADataTypes.Action.RecordAttestation,
            keccak256("security-unbound-attestation-object"),
            evidenceId,
            keccak256("security-unbound-attestation-hash"),
            keccak256("panel-authority"),
            "evidence-receipt-attestation",
            "ipfs://security-unbound-attestation"
        ) returns (
            uint256
        ) {}
        catch {
            reverted = true;
        }

        require(reverted, "evidence attestation accepted arbitrary object alias");
        require(auditModule.nextAttestationId() == 1, "rejected attestation wrote storage");
    }

    function testExternalOperationRejectsRegistrationAfterPackageIdentityDrift() public {
        bytes32 workflowKey = keccak256("security-external-operation-package-drift");
        MutableIdentityAntiAbuseModule mutableModule = _registerMutableWorkflow(workflowKey);
        (uint256 recognisedStateId, uint256 evidenceId) = _registerRecognisedStateForWorkflowStatusWithCurrentEvidence(
            workflowKey, AVADataTypes.RecognisedStateStatus.Vested, "security-external-operation-package-drift"
        );

        mutableModule.setBlockedAction(AVADataTypes.Action.ResolveChallenge);
        _requirePackageIdentityInvalid(workflowKey);
        try externalOperationRegistry.requestOperation(
            AVADataTypes.Role.Panel,
            workflowKey,
            AVADataTypes.ExternalOperationKind.EditorialSyncIntent,
            AVADataTypes.ExternalOperationTargetKind.RecognisedState,
            recognisedStateId,
            evidenceId,
            keccak256("panel-authority"),
            "ipfs://security-external-operation-package-drift"
        ) {
            revert("external operation recorded from identity-invalid package");
        } catch Error(string memory reason) {
            require(
                keccak256(bytes(reason)) != keccak256("external operation recorded from identity-invalid package"),
                reason
            );
        } catch {}
    }

    function testEvidenceLifecycleCanVetoExternalOperationRecord() public {
        bytes32 workflowKey = keccak256("security-external-operation-lifecycle-veto");
        _registerRulePackageWithFutureProofModules(
            workflowKey,
            valueExecutionAdapter,
            standingComputationModule,
            rulePackageLifecycleModule,
            new RejectingEvidenceLifecycleModule(AVADataTypes.Action.RecordExternalOperation),
            disclosureExecutionModule,
            1,
            keccak256("ava-m4-21-compatible"),
            false,
            "ipfs://security-external-operation-lifecycle-veto"
        );
        (uint256 recognisedStateId, uint256 evidenceId) = _registerRecognisedStateForWorkflowStatusWithCurrentEvidence(
            workflowKey, AVADataTypes.RecognisedStateStatus.Vested, "security-external-operation-lifecycle-veto"
        );

        try externalOperationRegistry.requestOperation(
            AVADataTypes.Role.Panel,
            workflowKey,
            AVADataTypes.ExternalOperationKind.EditorialSyncIntent,
            AVADataTypes.ExternalOperationTargetKind.RecognisedState,
            recognisedStateId,
            evidenceId,
            keccak256("panel-authority"),
            "ipfs://security-external-operation-lifecycle-veto"
        ) {
            revert("external operation evidence lifecycle veto was bypassed");
        } catch Error(string memory reason) {
            require(
                keccak256(bytes(reason)) != keccak256("external operation evidence lifecycle veto was bypassed"), reason
            );
        } catch {}
    }

    function testExternalOperationAcknowledgementFailsClosedButCancellationRemainsAvailableAfterPackageDrift() public {
        bytes32 workflowKey = keccak256("security-external-operation-defensive-closeout");
        MutableIdentityAntiAbuseModule mutableModule = _registerMutableWorkflow(workflowKey);
        (uint256 recognisedStateId, uint256 evidenceId) = _registerRecognisedStateForWorkflowStatusWithCurrentEvidence(
            workflowKey, AVADataTypes.RecognisedStateStatus.Vested, "security-external-operation-defensive-closeout"
        );
        uint256 operationId = externalOperationRegistry.requestOperation(
            AVADataTypes.Role.Panel,
            workflowKey,
            AVADataTypes.ExternalOperationKind.EditorialSyncIntent,
            AVADataTypes.ExternalOperationTargetKind.RecognisedState,
            recognisedStateId,
            evidenceId,
            keccak256("panel-authority"),
            "ipfs://security-external-operation-defensive-closeout-request"
        );

        mutableModule.setBlockedAction(AVADataTypes.Action.ResolveChallenge);
        _requirePackageIdentityInvalid(workflowKey);
        try externalOperationRegistry.acknowledgeOperation(
            AVADataTypes.Role.Panel,
            operationId,
            keccak256("panel-authority"),
            "ipfs://security-external-operation-defensive-closeout-ack"
        ) {
            revert("identity-invalid package allowed external operation acknowledgement");
        } catch Error(string memory reason) {
            require(
                keccak256(bytes(reason))
                    != keccak256("identity-invalid package allowed external operation acknowledgement"),
                reason
            );
        } catch {}

        uint256 cancellationId = externalOperationRegistry.cancelOperation(
            AVADataTypes.Role.Panel,
            operationId,
            keccak256("panel-authority"),
            "ipfs://security-external-operation-defensive-closeout-cancel"
        );
        require(
            externalOperationRegistry.getExternalOperation(cancellationId).status
                == AVADataTypes.ExternalOperationStatus.Cancelled,
            "defensive cancellation unavailable after package drift"
        );
    }

    function testExternalOperationDefensiveCloseoutRemainsAvailableAfterEvidenceRevocation() public {
        (uint256 recognisedStateId, uint256 evidenceId) = _registerRecognisedStateForWorkflowStatusWithCurrentEvidence(
            DEFAULT_WORKFLOW, AVADataTypes.RecognisedStateStatus.Vested, "security-external-operation-evidence-closeout"
        );
        uint256 cancellationSourceId = externalOperationRegistry.requestOperation(
            AVADataTypes.Role.Panel,
            DEFAULT_WORKFLOW,
            AVADataTypes.ExternalOperationKind.EditorialSyncIntent,
            AVADataTypes.ExternalOperationTargetKind.RecognisedState,
            recognisedStateId,
            evidenceId,
            keccak256("panel-authority"),
            "ipfs://security-external-operation-cancel-source"
        );
        uint256 supersessionSourceId = externalOperationRegistry.requestOperation(
            AVADataTypes.Role.Panel,
            DEFAULT_WORKFLOW,
            AVADataTypes.ExternalOperationKind.InvestigationIntent,
            AVADataTypes.ExternalOperationTargetKind.RecognisedState,
            recognisedStateId,
            evidenceId,
            keccak256("panel-authority"),
            "ipfs://security-external-operation-supersede-source"
        );
        reviewerActor.recordEvidenceLifecycleHook(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            DEFAULT_WORKFLOW,
            evidenceId,
            AVADataTypes.EvidenceLifecycleKind.RevocationReady,
            0,
            keccak256("security-external-operation-evidence-revoked"),
            "ipfs://security-external-operation-evidence-revoked"
        );

        bool acknowledgementReverted;
        try externalOperationRegistry.acknowledgeOperation(
            AVADataTypes.Role.Panel,
            cancellationSourceId,
            keccak256("panel-authority"),
            "ipfs://security-external-operation-revoked-ack"
        ) returns (
            uint256
        ) {}
        catch {
            acknowledgementReverted = true;
        }
        require(acknowledgementReverted, "revoked evidence allowed operation acknowledgement");

        uint256 cancellationId = externalOperationRegistry.cancelOperation(
            AVADataTypes.Role.Panel,
            cancellationSourceId,
            keccak256("panel-authority"),
            "ipfs://security-external-operation-revoked-cancel"
        );
        uint256 supersessionId = externalOperationRegistry.supersedeOperation(
            AVADataTypes.Role.Panel,
            supersessionSourceId,
            keccak256("panel-authority"),
            "ipfs://security-external-operation-revoked-supersede"
        );

        require(
            externalOperationRegistry.getExternalOperation(cancellationId).status
                == AVADataTypes.ExternalOperationStatus.Cancelled,
            "revoked-evidence operation was not cancelled"
        );
        require(
            externalOperationRegistry.getExternalOperation(supersessionId).status
                == AVADataTypes.ExternalOperationStatus.Superseded,
            "revoked-evidence operation was not superseded"
        );
        require(
            externalOperationRegistry.terminalReceiptIdByOperation(cancellationSourceId) == cancellationId,
            "cancellation receipt not linked"
        );
        require(
            externalOperationRegistry.terminalReceiptIdByOperation(supersessionSourceId) == supersessionId,
            "supersession receipt not linked"
        );
    }

    function _registerMutableWorkflow(bytes32 workflowKey)
        internal
        returns (MutableIdentityAntiAbuseModule mutableModule)
    {
        mutableModule = new MutableIdentityAntiAbuseModule(AVADataTypes.Action.RecordAttestation);
        AVARulePackageRegistry.RulePackageModules memory modules = _defaultRulePackageModules();
        modules.antiAbuseModule = mutableModule;
        modules.compatibilityKey = keccak256("ava-m4-21-compatible");
        rulePackageRegistry.registerRulePackage(
            AVADataTypes.Role.Panel, PEER_REVIEW_APP_ID, workflowKey, modules, "ipfs://security-mutable-workflow"
        );
    }

    function _registerWorkflowWithEvidenceLifecycle(
        bytes32 workflowKey,
        RejectingEvidenceLifecycleModule lifecycleModule,
        string memory seed
    ) internal {
        _registerRulePackageWithFutureProofModules(
            workflowKey,
            valueExecutionAdapter,
            standingComputationModule,
            rulePackageLifecycleModule,
            lifecycleModule,
            disclosureExecutionModule,
            1,
            keccak256("ava-m4-21-compatible"),
            false,
            string.concat("ipfs://", seed)
        );
    }

    function _requirePackageIdentityInvalid(bytes32 workflowKey) internal view {
        try rulePackageRegistry.getRulePackage(PEER_REVIEW_APP_ID, workflowKey) {
            revert("package identity drift was not detected");
        } catch {}
    }
}
