// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./helpers/AVASkeletonFixture.sol";

contract AVASkeletonDisclosureExternal01ATest is AVASkeletonFixture {
    function testM421PrivacyAccessGrantRevocationAndDisclosureIntentAreRecordOnly() public {
        uint256 policyId = _registerDisclosurePolicy("m421-access-policy");
        uint256 evidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            DEFAULT_WORKFLOW,
            keccak256("m421-access-evidence"),
            "ipfs://m421-access-evidence",
            "privacy-access-reference",
            policyId
        );
        uint256 grantId = disclosureAccessExecutor.recordAccessGrant(
            AVADataTypes.Role.Panel,
            PEER_REVIEW_APP_ID, DEFAULT_WORKFLOW,
            AVADataTypes.DisclosureTargetKind.EvidenceReceipt,
            evidenceId,
            policyId,
            REVIEWER_SUBJECT,
            block.timestamp + 1 days,
            keccak256("panel-authority"),
            "ipfs://m421-access-grant"
        );
        require(
            disclosureAccessExecutor.getDisclosureExecution(grantId).kind
                == AVADataTypes.DisclosureExecutionKind.AccessGrant,
            "access grant not recorded"
        );
        uint256 revocationId = disclosureAccessExecutor.recordAccessRevocation(
            AVADataTypes.Role.Panel, grantId, keccak256("panel-authority"), "ipfs://m421-access-revocation"
        );
        require(
            disclosureAccessExecutor.getDisclosureExecution(grantId).status
                == AVADataTypes.DisclosureExecutionStatus.Revoked,
            "grant not marked revoked"
        );
        require(
            disclosureAccessExecutor.getDisclosureExecution(revocationId).kind
                == AVADataTypes.DisclosureExecutionKind.AccessRevocation,
            "revocation not recorded"
        );
        uint256 intentId = disclosureAccessExecutor.recordVoluntaryDisclosureIntent(
            AVADataTypes.Role.Panel,
            PEER_REVIEW_APP_ID, DEFAULT_WORKFLOW,
            AVADataTypes.DisclosureTargetKind.EvidenceReceipt,
            evidenceId,
            policyId,
            keccak256("panel-authority"),
            "ipfs://m421-voluntary-intent"
        );
        require(
            disclosureAccessExecutor.getDisclosureExecution(intentId).kind
                == AVADataTypes.DisclosureExecutionKind.VoluntaryDisclosureIntent,
            "voluntary intent not recorded"
        );

        bytes32 rejectingWorkflow = keccak256("m421-rejecting-disclosure-workflow");
        KindRejectingDisclosureExecutionModule rejectingModule =
            new KindRejectingDisclosureExecutionModule(AVADataTypes.DisclosureExecutionKind.AccessGrant);
        _registerM421ExecutionWorkflowWithDisclosureExecution(
            rejectingWorkflow, rejectingModule, "ipfs://m421-rejecting-disclosure-workflow"
        );
        uint256 rejectingPolicyId = _registerDisclosurePolicy("m421-rejecting-access-policy");
        uint256 rejectingEvidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            rejectingWorkflow,
            keccak256("m421-rejecting-access-evidence"),
            "ipfs://m421-rejecting-access-evidence",
            "privacy-access-reference",
            rejectingPolicyId
        );
        try disclosureAccessExecutor.recordAccessGrant(
            AVADataTypes.Role.Panel,
            PEER_REVIEW_APP_ID, rejectingWorkflow,
            AVADataTypes.DisclosureTargetKind.EvidenceReceipt,
            rejectingEvidenceId,
            rejectingPolicyId,
            REVIEWER_SUBJECT,
            block.timestamp + 1 days,
            keccak256("panel-authority"),
            "ipfs://m421-rejected-access-grant"
        ) {
            revert("workflow-specific disclosure execution module was bypassed");
        } catch {}
        disclosureAccessExecutor.recordVoluntaryDisclosureIntent(
            AVADataTypes.Role.Panel,
            PEER_REVIEW_APP_ID, rejectingWorkflow,
            AVADataTypes.DisclosureTargetKind.EvidenceReceipt,
            rejectingEvidenceId,
            rejectingPolicyId,
            keccak256("panel-authority"),
            "ipfs://m421-rejecting-workflow-voluntary-intent"
        );
        _assertNoSelector(address(disclosureAccessExecutor), "revealIdentity(uint256)");
        _assertNoSelector(address(disclosureAccessExecutor), "revealEvidence(uint256)");
        _assertNoSelector(address(disclosureAccessExecutor), "decryptEvidence(uint256)");
    }

    function testM53AccessGrantExpiryPreventsLateRevocationAndLinksClosureRecords() public {
        uint256 policyId = _registerDisclosurePolicy("m53-access-expiry-policy");
        uint256 evidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            DEFAULT_WORKFLOW,
            keccak256("m53-access-expiry-evidence"),
            "ipfs://m53-access-expiry-evidence",
            "privacy-access-reference",
            policyId
        );
        uint256 grantExpiry = block.timestamp + 1 days;
        uint256 grantId = disclosureAccessExecutor.recordAccessGrant(
            AVADataTypes.Role.Panel,
            PEER_REVIEW_APP_ID, DEFAULT_WORKFLOW,
            AVADataTypes.DisclosureTargetKind.EvidenceReceipt,
            evidenceId,
            policyId,
            REVIEWER_SUBJECT,
            grantExpiry,
            keccak256("panel-authority"),
            "ipfs://m53-access-grant"
        );

        try disclosureAccessExecutor.recordAccessExpiry(
            AVADataTypes.Role.Panel, grantId, keccak256("panel-authority"), "ipfs://m53-too-early-expiry"
        ) {
            revert("access expiry accepted before expiry time");
        } catch {}

        vm.warp(grantExpiry + 1);
        try disclosureAccessExecutor.recordAccessRevocation(
            AVADataTypes.Role.Panel, grantId, keccak256("panel-authority"), "ipfs://m53-late-revocation"
        ) {
            revert("late revocation accepted instead of explicit expiry");
        } catch {}

        uint256 expiryRecordId = disclosureAccessExecutor.recordAccessExpiry(
            AVADataTypes.Role.Panel, grantId, keccak256("panel-authority"), "ipfs://m53-access-expiry"
        );
        AVADataTypes.DisclosureExecutionRecord memory grant = disclosureAccessExecutor.getDisclosureExecution(grantId);
        AVADataTypes.DisclosureExecutionRecord memory expiry =
            disclosureAccessExecutor.getDisclosureExecution(expiryRecordId);
        require(grant.status == AVADataTypes.DisclosureExecutionStatus.Expired, "grant not marked expired");
        require(expiry.kind == AVADataTypes.DisclosureExecutionKind.ExpiryExecuted, "expiry record kind wrong");
        require(expiry.status == AVADataTypes.DisclosureExecutionStatus.Expired, "expiry record status wrong");
        require(expiry.sourceDisclosureExecutionId == grantId, "expiry not linked to grant");
    }

    function testM73AccessGrantSupersessionClosesGrantAndRejectsDuplicateClosure() public {
        uint256 policyId = _registerDisclosurePolicy("m73-access-supersession-policy");
        uint256 evidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            DEFAULT_WORKFLOW,
            keccak256("m73-access-supersession-evidence"),
            "ipfs://m73-access-supersession-evidence",
            "privacy-access-reference",
            policyId
        );
        uint256 grantId = disclosureAccessExecutor.recordAccessGrant(
            AVADataTypes.Role.Panel,
            PEER_REVIEW_APP_ID, DEFAULT_WORKFLOW,
            AVADataTypes.DisclosureTargetKind.EvidenceReceipt,
            evidenceId,
            policyId,
            REVIEWER_SUBJECT,
            block.timestamp + 1 days,
            keccak256("panel-authority"),
            "ipfs://m73-access-grant"
        );

        uint256 supersessionId = disclosureAccessExecutor.recordAccessSupersession(
            AVADataTypes.Role.Panel, grantId, keccak256("panel-authority"), "ipfs://m73-access-supersession"
        );
        AVADataTypes.DisclosureExecutionRecord memory grant = disclosureAccessExecutor.getDisclosureExecution(grantId);
        AVADataTypes.DisclosureExecutionRecord memory supersession =
            disclosureAccessExecutor.getDisclosureExecution(supersessionId);
        require(grant.status == AVADataTypes.DisclosureExecutionStatus.Superseded, "grant not superseded");
        require(
            supersession.kind == AVADataTypes.DisclosureExecutionKind.SupersessionExecuted,
            "supersession kind wrong"
        );
        require(
            supersession.status == AVADataTypes.DisclosureExecutionStatus.Superseded,
            "supersession status wrong"
        );
        require(supersession.sourceDisclosureExecutionId == grantId, "supersession not linked to grant");
        require(supersession.packageId == grant.packageId, "supersession package drifted");

        try disclosureAccessExecutor.recordAccessRevocation(
            AVADataTypes.Role.Panel, grantId, keccak256("panel-authority"), "ipfs://m73-revoke-superseded-grant"
        ) {
            revert("revocation accepted superseded grant");
        } catch {}
        try disclosureAccessExecutor.recordAccessSupersession(
            AVADataTypes.Role.Panel, grantId, keccak256("panel-authority"), "ipfs://m73-duplicate-supersession"
        ) {
            revert("duplicate supersession accepted");
        } catch {}
    }
}
contract AVASkeletonDisclosureExternal01BTest is AVASkeletonFixture {
    function testM53AccessRevocationLinksClosedGrantAndRejectsInvalidExpiry() public {
        uint256 policyId = _registerDisclosurePolicy("m53-revocation-policy");
        uint256 evidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            DEFAULT_WORKFLOW,
            keccak256("m53-revocation-evidence"),
            "ipfs://m53-revocation-evidence",
            "privacy-access-reference",
            policyId
        );
        try disclosureAccessExecutor.recordAccessGrant(
            AVADataTypes.Role.Panel,
            PEER_REVIEW_APP_ID, DEFAULT_WORKFLOW,
            AVADataTypes.DisclosureTargetKind.EvidenceReceipt,
            evidenceId,
            policyId,
            REVIEWER_SUBJECT,
            block.timestamp,
            keccak256("panel-authority"),
            "ipfs://m53-zero-duration-grant"
        ) {
            revert("access grant accepted non-future expiry");
        } catch {}

        uint256 grantId = disclosureAccessExecutor.recordAccessGrant(
            AVADataTypes.Role.Panel,
            PEER_REVIEW_APP_ID, DEFAULT_WORKFLOW,
            AVADataTypes.DisclosureTargetKind.EvidenceReceipt,
            evidenceId,
            policyId,
            REVIEWER_SUBJECT,
            block.timestamp + 1 days,
            keccak256("panel-authority"),
            "ipfs://m53-revocable-grant"
        );
        uint256 revocationId = disclosureAccessExecutor.recordAccessRevocation(
            AVADataTypes.Role.Panel, grantId, keccak256("panel-authority"), "ipfs://m53-revocation"
        );
        AVADataTypes.DisclosureExecutionRecord memory revocation =
            disclosureAccessExecutor.getDisclosureExecution(revocationId);
        require(revocation.sourceDisclosureExecutionId == grantId, "revocation not linked to grant");
        require(
            disclosureAccessExecutor.getDisclosureExecution(grantId).status
                == AVADataTypes.DisclosureExecutionStatus.Revoked,
            "grant not revoked"
        );
        try disclosureAccessExecutor.recordAccessExpiry(
            AVADataTypes.Role.Panel, grantId, keccak256("panel-authority"), "ipfs://m53-expire-revoked"
        ) {
            revert("revoked grant accepted expiry");
        } catch {}
    }

    function testM53DisclosureLifecycleExecutionStoresExpiryAndSupersessionStatuses() public {
        uint256 policyId = _registerDisclosurePolicy("m53-policy-lifecycle");
        uint256 expiryRecordId = disclosureAccessExecutor.recordDisclosureLifecycleExecution(
            AVADataTypes.Role.Panel,
            PEER_REVIEW_APP_ID, DEFAULT_WORKFLOW,
            AVADataTypes.DisclosureExecutionKind.ExpiryExecuted,
            AVADataTypes.DisclosureTargetKind.DisclosurePolicy,
            policyId,
            policyId,
            keccak256("panel-authority"),
            "ipfs://m53-policy-expiry"
        );
        uint256 supersessionRecordId = disclosureAccessExecutor.recordDisclosureLifecycleExecution(
            AVADataTypes.Role.Panel,
            PEER_REVIEW_APP_ID, DEFAULT_WORKFLOW,
            AVADataTypes.DisclosureExecutionKind.SupersessionExecuted,
            AVADataTypes.DisclosureTargetKind.DisclosurePolicy,
            policyId,
            policyId,
            keccak256("panel-authority"),
            "ipfs://m53-policy-supersession"
        );

        require(
            disclosureAccessExecutor.getDisclosureExecution(expiryRecordId).status
                == AVADataTypes.DisclosureExecutionStatus.Expired,
            "policy expiry status missing"
        );
        require(
            disclosureAccessExecutor.getDisclosureExecution(supersessionRecordId).status
                == AVADataTypes.DisclosureExecutionStatus.Superseded,
            "policy supersession status missing"
        );
        _assertNoSelector(address(disclosureAccessExecutor), "enforceAccess(uint256)");
        _assertNoSelector(address(disclosureAccessExecutor), "revealIdentity(uint256)");
        _assertNoSelector(address(disclosureAccessExecutor), "decryptEvidence(uint256)");
    }

    function testM426DisclosureExecutionUsesTargetPackageAfterWorkflowReconfiguration() public {
        bytes32 workflowKey = keccak256("m426-disclosure-execution-package");
        _registerM421ExecutionWorkflow(workflowKey, "ipfs://m426-disclosure-execution-v1");
        uint256 policyId = _registerDisclosurePolicy("m426-disclosure-execution-policy");
        uint256 oldEvidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            workflowKey,
            keccak256("m426-old-disclosure-evidence"),
            "ipfs://m426-old-disclosure-evidence",
            "disclosure-execution-package-basis",
            policyId
        );
        uint256 oldPackageId = evidenceRegistry.getEvidenceReceipt(oldEvidenceId).packageId;

        KindRejectingDisclosureExecutionModule rejectingModule =
            new KindRejectingDisclosureExecutionModule(AVADataTypes.DisclosureExecutionKind.AccessGrant);
        _registerM421ExecutionWorkflowWithDisclosureExecution(
            workflowKey, rejectingModule, "ipfs://m426-disclosure-execution-v2"
        );
        uint256 newEvidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            workflowKey,
            keccak256("m426-new-disclosure-evidence"),
            "ipfs://m426-new-disclosure-evidence",
            "disclosure-execution-package-basis",
            policyId
        );

        uint256 oldGrantId = disclosureAccessExecutor.recordAccessGrant(
            AVADataTypes.Role.Panel,
            PEER_REVIEW_APP_ID, workflowKey,
            AVADataTypes.DisclosureTargetKind.EvidenceReceipt,
            oldEvidenceId,
            policyId,
            REVIEWER_SUBJECT,
            block.timestamp + 1 days,
            keccak256("panel-authority"),
            "ipfs://m426-old-access-grant"
        );
        require(disclosureAccessExecutor.getDisclosureExecution(oldGrantId).packageId == oldPackageId, "old package not used");

        try disclosureAccessExecutor.recordAccessGrant(
            AVADataTypes.Role.Panel,
            PEER_REVIEW_APP_ID, workflowKey,
            AVADataTypes.DisclosureTargetKind.EvidenceReceipt,
            newEvidenceId,
            policyId,
            REVIEWER_SUBJECT,
            block.timestamp + 1 days,
            keccak256("panel-authority"),
            "ipfs://m426-new-access-grant"
        ) {
            revert("new package disclosure execution module was not used");
        } catch {}
    }
}

contract AVASkeletonDisclosureExternal02ATest is AVASkeletonFixture {
    function testM426DisclosureExecutionHasNoRuntimeConfigurationEntrypoint() public {
        bytes32 workflowKey = keccak256("m426-legacy-disclosure-config");
        _registerM421ExecutionWorkflow(workflowKey, "ipfs://m426-legacy-disclosure-config");
        KindRejectingDisclosureExecutionModule rejectingModule =
            new KindRejectingDisclosureExecutionModule(AVADataTypes.DisclosureExecutionKind.AccessGrant);
        address packageModule = address(disclosureAccessExecutor.getWorkflowExecutionModule(PEER_REVIEW_APP_ID, workflowKey));

        (bool ok,) = address(disclosureAccessExecutor).call(
            abi.encodeWithSignature(
                "configureWorkflowExecutionModule(uint8,bytes32,address,bytes32)",
                AVADataTypes.Role.Panel,
                workflowKey,
                address(rejectingModule),
                keccak256("panel-authority")
            )
        );
        require(!ok, "removed disclosure runtime configuration entrypoint remained callable");

        require(
            address(disclosureAccessExecutor.getWorkflowExecutionModule(PEER_REVIEW_APP_ID, workflowKey)) == packageModule,
            "removed config path changed package-bound module"
        );
    }

    function testM421AnonymousChallengeProofUseRejectsNullifierReplay() public {
        uint256 policyId = _registerDisclosurePolicy("m421-anonymous-policy");
        bytes32 subjectCommitment = _subjectCommitmentForSecret(7);
        roleRegistry.assignRole(
            address(this), AVADataTypes.Role.Challenger, subjectCommitment, "ipfs://m421-anonymous-challenger"
        );
        uint256 recognisedStateId = _createChallengeableReviewState();
        uint256 evidenceId = evidenceRegistry.registerEvidenceReceipt(
            AVADataTypes.Role.Challenger,
            PEER_REVIEW_APP_ID, DEFAULT_WORKFLOW,
            keccak256("m421-anonymous-evidence"),
            "ipfs://m421-anonymous-evidence",
            "anonymous-challenge-proof",
            policyId
        );
        uint256 challengeId = challengeWorkflow.fileChallenge(
            AVADataTypes.Role.Challenger, PEER_REVIEW_APP_ID, DEFAULT_WORKFLOW, recognisedStateId, subjectCommitment, evidenceId, policyId
        );
        uint256 proofReceiptId =
            _registerDefaultAnonymousChallengeDisclosureProof(challengeId, policyId, subjectCommitment);
        ZKProofRegistry.ProofReceipt memory receipt = zkProofRegistry.getProofReceipt(proofReceiptId);
        uint256 useId = disclosureAccessExecutor.recordAnonymousChallengeProofUse(
            AVADataTypes.Role.Challenger,
            challengeId,
            policyId,
            proofReceiptId,
            subjectCommitment,
            receipt.nullifierHash,
            "ipfs://m421-anonymous-proof-use"
        );
        require(
            disclosureAccessExecutor.getDisclosureExecution(useId).kind
                == AVADataTypes.DisclosureExecutionKind.AnonymousChallengeUse,
            "anonymous proof use not recorded"
        );
        try disclosureAccessExecutor.recordAnonymousChallengeProofUse(
            AVADataTypes.Role.Challenger,
            challengeId,
            policyId,
            proofReceiptId,
            subjectCommitment,
            receipt.nullifierHash,
            "ipfs://m421-anonymous-proof-replay"
        ) {
            revert("anonymous challenge nullifier replay accepted");
        } catch {}
    }

    function testM83AnonymousProofUseRecordStoresProofContextVerifierAndDomain() public {
        uint256 policyId = _registerDisclosurePolicy("m83-anonymous-proof-use-policy");
        bytes32 subjectCommitment = _subjectCommitmentForSecret(7);
        roleRegistry.assignRole(
            address(this), AVADataTypes.Role.Challenger, subjectCommitment, "ipfs://m83-anonymous-challenger"
        );
        uint256 recognisedStateId = _createChallengeableReviewState();
        uint256 evidenceId = evidenceRegistry.registerEvidenceReceipt(
            AVADataTypes.Role.Challenger,
            PEER_REVIEW_APP_ID, DEFAULT_WORKFLOW,
            keccak256("m83-anonymous-proof-use-evidence"),
            "ipfs://m83-anonymous-proof-use-evidence",
            "anonymous-challenge-proof",
            policyId
        );
        uint256 challengeId = challengeWorkflow.fileChallenge(
            AVADataTypes.Role.Challenger, PEER_REVIEW_APP_ID, DEFAULT_WORKFLOW, recognisedStateId, subjectCommitment, evidenceId, policyId
        );
        uint256 proofReceiptId =
            _registerDefaultAnonymousChallengeDisclosureProof(challengeId, policyId, subjectCommitment);
        ZKProofRegistry.ProofReceipt memory proofReceipt = zkProofRegistry.getProofReceipt(proofReceiptId);
        uint256 useId = disclosureAccessExecutor.recordAnonymousChallengeProofUse(
            AVADataTypes.Role.Challenger,
            challengeId,
            policyId,
            proofReceiptId,
            subjectCommitment,
            proofReceipt.nullifierHash,
            "ipfs://m83-anonymous-proof-use"
        );
        AVADataTypes.DisclosureExecutionRecord memory useRecord =
            disclosureAccessExecutor.getDisclosureExecution(useId);
        require(useRecord.proofReceiptId == proofReceiptId, "proof receipt id missing");
        require(useRecord.proofContextHash == proofReceipt.contextHash, "proof context missing");
        require(useRecord.proofVerifier == proofReceipt.verifier, "proof verifier missing");
        require(useRecord.proofDomainHash == proofReceipt.proofDomainHash, "proof domain missing");
    }
}
contract AVASkeletonDisclosureExternal02BTest is AVASkeletonFixture {
    function testM426AnonymousChallengeProofUseRejectsNewPackageProofForOldChallenge() public {
        uint256 policyId = _registerDisclosurePolicy("m426-anonymous-package-policy");
        bytes32 subjectCommitment = _subjectCommitmentForSecret(7);
        roleRegistry.assignRole(
            address(this), AVADataTypes.Role.Challenger, subjectCommitment, "ipfs://m426-package-challenger"
        );
        uint256 recognisedStateId = _createChallengeableReviewState();
        uint256 evidenceId = evidenceRegistry.registerEvidenceReceipt(
            AVADataTypes.Role.Challenger,
            PEER_REVIEW_APP_ID, DEFAULT_WORKFLOW,
            keccak256("m426-anonymous-package-evidence"),
            "ipfs://m426-anonymous-package-evidence",
            "anonymous-challenge-proof",
            policyId
        );
        uint256 challengeId = challengeWorkflow.fileChallenge(
            AVADataTypes.Role.Challenger, PEER_REVIEW_APP_ID, DEFAULT_WORKFLOW, recognisedStateId, subjectCommitment, evidenceId, policyId
        );
        uint256 oldChallengePackageId = challengeWorkflow.getChallenge(challengeId).packageId;

        _registerM421ExecutionWorkflow(DEFAULT_WORKFLOW, "ipfs://m426-anonymous-package-v2");
        uint256 activePackageId = rulePackageRegistry.getRulePackage(PEER_REVIEW_APP_ID, DEFAULT_WORKFLOW).packageId;
        require(activePackageId != oldChallengePackageId, "workflow package was not replaced");

        uint256 proofReceiptId =
            _registerDefaultAnonymousChallengeDisclosureProof(challengeId, policyId, subjectCommitment);
        ZKProofRegistry.ProofReceipt memory receipt = zkProofRegistry.getProofReceipt(proofReceiptId);
        require(receipt.packageId == activePackageId, "proof did not bind active package");

        try disclosureAccessExecutor.recordAnonymousChallengeProofUse(
            AVADataTypes.Role.Challenger,
            challengeId,
            policyId,
            proofReceiptId,
            subjectCommitment,
            receipt.nullifierHash,
            "ipfs://m426-cross-package-proof-use"
        ) {
            revert("anonymous challenge proof use accepted proof from replaced package");
        } catch {}
    }

    function testM426AnonymousChallengeProofUseCanRegisterOldPackageProofAfterWorkflowReregistration() public {
        uint256 policyId = _registerDisclosurePolicy("m426-old-package-proof-policy");
        bytes32 subjectCommitment = _subjectCommitmentForSecret(7);
        roleRegistry.assignRole(
            address(this), AVADataTypes.Role.Challenger, subjectCommitment, "ipfs://m426-old-package-challenger"
        );
        uint256 recognisedStateId = _createChallengeableReviewState();
        uint256 evidenceId = evidenceRegistry.registerEvidenceReceipt(
            AVADataTypes.Role.Challenger,
            PEER_REVIEW_APP_ID, DEFAULT_WORKFLOW,
            keccak256("m426-old-package-proof-evidence"),
            "ipfs://m426-old-package-proof-evidence",
            "anonymous-challenge-proof",
            policyId
        );
        uint256 challengeId = challengeWorkflow.fileChallenge(
            AVADataTypes.Role.Challenger, PEER_REVIEW_APP_ID, DEFAULT_WORKFLOW, recognisedStateId, subjectCommitment, evidenceId, policyId
        );
        uint256 oldChallengePackageId = challengeWorkflow.getChallenge(challengeId).packageId;

        _registerM421ExecutionWorkflow(DEFAULT_WORKFLOW, "ipfs://m426-old-package-proof-v2");
        require(
            rulePackageRegistry.getRulePackage(PEER_REVIEW_APP_ID, DEFAULT_WORKFLOW).packageId != oldChallengePackageId,
            "workflow package was not replaced"
        );

        bytes32 oldContextHash = zkProofRegistry.computeDisclosureContextHashForPackage(
            oldChallengePackageId,
            PEER_REVIEW_APP_ID,
            DEFAULT_WORKFLOW,
            AVADataTypes.AVAStage.Verification,
            AVADataTypes.Action.RecordDisclosureExecution,
            bytes32(challengeId),
            AVADataTypes.Role.Challenger,
            policyId,
            subjectCommitment
        );
        _assertPackageBoundDisclosureProofRejectsWrongWorkflow(
            oldChallengePackageId, challengeId, policyId, subjectCommitment, oldContextHash
        );
        uint256 proofReceiptId = _registerDefaultAnonymousChallengeDisclosureProofForPackage(
            oldChallengePackageId, challengeId, policyId, subjectCommitment
        );
        ZKProofRegistry.ProofReceipt memory receipt = zkProofRegistry.getProofReceipt(proofReceiptId);
        require(receipt.packageId == oldChallengePackageId, "proof did not bind old package");

        uint256 useId = disclosureAccessExecutor.recordAnonymousChallengeProofUse(
            AVADataTypes.Role.Challenger,
            challengeId,
            policyId,
            proofReceiptId,
            subjectCommitment,
            receipt.nullifierHash,
            "ipfs://m426-old-package-proof-use"
        );
        AVADataTypes.DisclosureExecutionRecord memory useRecord =
            disclosureAccessExecutor.getDisclosureExecution(useId);
        require(useRecord.packageId == oldChallengePackageId, "proof use did not bind old package");
        require(useRecord.proofContextHash == oldContextHash, "old proof context missing");
    }

    function testM426AnonymousChallengeProofUseRequiresTargetBoundProofContext() public {
        uint256 policyId = _registerDisclosurePolicy("m426-anonymous-context-policy");
        bytes32 subjectCommitment = _subjectCommitmentForSecret(7);
        roleRegistry.assignRole(
            address(this), AVADataTypes.Role.Challenger, subjectCommitment, "ipfs://m426-anonymous-challenger"
        );
        uint256 recognisedStateId = _createChallengeableReviewState();
        uint256 evidenceId = evidenceRegistry.registerEvidenceReceipt(
            AVADataTypes.Role.Challenger,
            PEER_REVIEW_APP_ID, DEFAULT_WORKFLOW,
            keccak256("m426-anonymous-context-evidence"),
            "ipfs://m426-anonymous-context-evidence",
            "anonymous-challenge-proof",
            policyId
        );
        uint256 challengeId = challengeWorkflow.fileChallenge(
            AVADataTypes.Role.Challenger, PEER_REVIEW_APP_ID, DEFAULT_WORKFLOW, recognisedStateId, subjectCommitment, evidenceId, policyId
        );
        bytes32 wrongObjectId = bytes32(challengeId + 100);
        bytes32 wrongContextHash = zkProofRegistry.computeDisclosureContextHash(
            PEER_REVIEW_APP_ID,
            DEFAULT_WORKFLOW,
            AVADataTypes.AVAStage.Verification,
            AVADataTypes.Action.RecordDisclosureExecution,
            wrongObjectId,
            AVADataTypes.Role.Challenger,
            policyId,
            subjectCommitment
        );
        uint256 proofReceiptId = zkProofRegistry.registerProof(
            PEER_REVIEW_APP_ID,
            DEFAULT_WORKFLOW,
            AVADataTypes.AVAStage.Verification,
            AVADataTypes.Action.RecordDisclosureExecution,
            wrongObjectId,
            AVADataTypes.Role.Challenger,
            policyId,
            subjectCommitment,
            _makeSchnorrProof(wrongContextHash, 7, 11)
        );
        ZKProofRegistry.ProofReceipt memory receipt = zkProofRegistry.getProofReceipt(proofReceiptId);

        try disclosureAccessExecutor.recordAnonymousChallengeProofUse(
            AVADataTypes.Role.Challenger,
            challengeId,
            policyId,
            proofReceiptId,
            subjectCommitment,
            receipt.nullifierHash,
            "ipfs://m426-wrong-context-proof-use"
        ) {
            revert("anonymous challenge proof use accepted wrong proof context");
        } catch {}
    }
}

contract AVASkeletonDisclosureExternal03ATest is AVASkeletonFixture {
    function testM426AnonymousChallengeProofUseRequiresChallengeSubjectMatch() public {
        uint256 policyId = _registerDisclosurePolicy("m426-anonymous-subject-policy");
        bytes32 originalSubject = _subjectCommitmentForSecret(7);
        bytes32 otherSubject = _subjectCommitmentForSecret(9);
        roleRegistry.assignRole(
            address(this), AVADataTypes.Role.Challenger, originalSubject, "ipfs://m426-original-anonymous-challenger"
        );
        uint256 recognisedStateId = _createChallengeableReviewState();
        uint256 evidenceId = evidenceRegistry.registerEvidenceReceipt(
            AVADataTypes.Role.Challenger,
            PEER_REVIEW_APP_ID, DEFAULT_WORKFLOW,
            keccak256("m426-anonymous-subject-evidence"),
            "ipfs://m426-anonymous-subject-evidence",
            "anonymous-challenge-proof",
            policyId
        );
        uint256 challengeId = challengeWorkflow.fileChallenge(
            AVADataTypes.Role.Challenger, PEER_REVIEW_APP_ID, DEFAULT_WORKFLOW, recognisedStateId, originalSubject, evidenceId, policyId
        );
        roleRegistry.deactivateSubject(originalSubject);
        roleRegistry.assignRole(
            address(this), AVADataTypes.Role.Challenger, otherSubject, "ipfs://m426-other-anonymous-challenger"
        );
        bytes32 contextHash = zkProofRegistry.computeDisclosureContextHash(
            PEER_REVIEW_APP_ID,
            DEFAULT_WORKFLOW,
            AVADataTypes.AVAStage.Verification,
            AVADataTypes.Action.RecordDisclosureExecution,
            bytes32(challengeId),
            AVADataTypes.Role.Challenger,
            policyId,
            otherSubject
        );
        uint256 proofReceiptId = zkProofRegistry.registerProof(
            PEER_REVIEW_APP_ID,
            DEFAULT_WORKFLOW,
            AVADataTypes.AVAStage.Verification,
            AVADataTypes.Action.RecordDisclosureExecution,
            bytes32(challengeId),
            AVADataTypes.Role.Challenger,
            policyId,
            otherSubject,
            _makeSchnorrProof(contextHash, 9, 11)
        );
        ZKProofRegistry.ProofReceipt memory receipt = zkProofRegistry.getProofReceipt(proofReceiptId);

        try disclosureAccessExecutor.recordAnonymousChallengeProofUse(
            AVADataTypes.Role.Challenger,
            challengeId,
            policyId,
            proofReceiptId,
            otherSubject,
            receipt.nullifierHash,
            "ipfs://m426-wrong-subject-proof-use"
        ) {
            revert("anonymous challenge proof use accepted non-challenger subject");
        } catch {}
    }

    function testM421ExternalOperationIntentRecordsCannotExecutePublicationDecisions() public {
        uint256 evidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            DEFAULT_WORKFLOW,
            keccak256("m421-external-operation-evidence"),
            "ipfs://m421-external-operation-evidence",
            "external-operation-reference",
            0
        );
        uint256 recognisedStateId = _registerRecognisedStateForWorkflowStatus(
            DEFAULT_WORKFLOW, AVADataTypes.RecognisedStateStatus.Vested, evidenceId, "m421-external-operation-state"
        );
        uint256 operationId = externalOperationRegistry.requestOperation(
            AVADataTypes.Role.Panel,
            DEFAULT_WORKFLOW,
            AVADataTypes.ExternalOperationKind.EditorialSyncIntent,
            AVADataTypes.ExternalOperationTargetKind.RecognisedState,
            recognisedStateId,
            evidenceId,
            keccak256("panel-authority"),
            "ipfs://m421-external-operation"
        );
        require(
            externalOperationRegistry.getExternalOperation(operationId).status
                == AVADataTypes.ExternalOperationStatus.Requested,
            "external operation request not recorded"
        );
        uint256 acknowledgementId = externalOperationRegistry.acknowledgeOperation(
            AVADataTypes.Role.Panel, operationId, keccak256("panel-authority"), "ipfs://m421-external-ack"
        );
        AVADataTypes.ExternalOperationRecord memory acknowledgement =
            externalOperationRegistry.getExternalOperation(acknowledgementId);
        require(
            acknowledgement.status == AVADataTypes.ExternalOperationStatus.Acknowledged,
            "external operation acknowledgement not recorded"
        );
        require(acknowledgement.sourceOperationId == operationId, "terminal receipt missing source operation");
        require(
            externalOperationRegistry.terminalReceiptIdByOperation(operationId) == acknowledgementId,
            "terminal operation receipt not linked"
        );
        try externalOperationRegistry.cancelOperation(
            AVADataTypes.Role.Panel, operationId, keccak256("panel-authority"), "ipfs://m421-external-cancel-again"
        ) {
            revert("external operation terminal status changed twice");
        } catch {}
        _assertNoSelector(address(externalOperationRegistry), "acceptManuscript(uint256)");
        _assertNoSelector(address(externalOperationRegistry), "rejectManuscript(uint256)");
        _assertNoSelector(address(externalOperationRegistry), "setManuscriptMerit(uint256,uint256)");
        _assertNoSelector(address(externalOperationRegistry), "grantPublicationPriority(uint256)");
        _assertNoSelector(address(externalOperationRegistry), "executeQueue(uint256)");
    }

    function testM56ExternalOperationTargetsAllBoundRecordTypes() public {
        bytes32 workflowKey = keccak256("m56-target-bound-workflow");
        _registerM421ExecutionWorkflow(workflowKey, "ipfs://m56-target-bound-workflow");
        MockERC20 token = _m421FundedToken(100);
        uint256 evidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            workflowKey,
            keccak256("m56-target-evidence"),
            "ipfs://m56-target-evidence",
            "external-operation-reference",
            0
        );
        uint256 recognisedStateId = _registerRecognisedStateForWorkflowStatus(
            workflowKey, AVADataTypes.RecognisedStateStatus.Vested, evidenceId, "m56-target-state"
        );

        AVARulePackageRegistry.RulePackage memory rulePackage = rulePackageRegistry.getRulePackage(PEER_REVIEW_APP_ID, workflowKey);
        uint256 challengeStateId = _createChallengeableReviewStateThroughPackage(rulePackage, workflowKey);
        uint256 challengeEvidenceId = challengerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Challenger,
            workflowKey,
            keccak256("m56-target-challenge-evidence"),
            "ipfs://m56-target-challenge-evidence",
            "external-operation-challenge-reference",
            0
        );
        uint256 challengeId = challengerActor.fileChallenge(
            challengeWorkflow,
            AVADataTypes.Role.Challenger,
            workflowKey,
            challengeStateId,
            CHALLENGER_SUBJECT,
            challengeEvidenceId,
            0
        );
        uint256 allocationId =
            _createM421RewardSource(workflowKey, "m56-target-allocation", token, 3, AVADataTypes.ValueExecutionMode.Claim);
        uint256 consequenceId = consequenceExecutor.registerConsequence(
            AVADataTypes.Role.Panel,
            recognisedStateId,
            AVADataTypes.ConsequenceKind.AdministrativeNote,
            REVIEWER_SUBJECT,
            evidenceId,
            keccak256("panel-authority"),
            "ipfs://m56-target-consequence"
        );

        _assertM56OperationTarget(
            workflowKey,
            AVADataTypes.ExternalOperationTargetKind.RecognisedState,
            recognisedStateId,
            evidenceId
        );
        _assertM56OperationTarget(workflowKey, AVADataTypes.ExternalOperationTargetKind.Challenge, challengeId, challengeEvidenceId);
        _assertM56OperationTarget(workflowKey, AVADataTypes.ExternalOperationTargetKind.EvidenceReceipt, evidenceId, evidenceId);
        _assertM56OperationTarget(workflowKey, AVADataTypes.ExternalOperationTargetKind.AllocationRecord, allocationId, evidenceId);
        _assertM56OperationTarget(workflowKey, AVADataTypes.ExternalOperationTargetKind.ConsequenceRecord, consequenceId, evidenceId);
    }
}
contract AVASkeletonDisclosureExternal03BTest is AVASkeletonFixture {
    function testM56ExternalOperationRejectsWrongWorkflowAndTerminalConflict() public {
        bytes32 workflowKey = keccak256("m56-terminal-workflow");
        _registerM421ExecutionWorkflow(workflowKey, "ipfs://m56-terminal-workflow");
        uint256 evidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            workflowKey,
            keccak256("m56-terminal-evidence"),
            "ipfs://m56-terminal-evidence",
            "external-operation-reference",
            0
        );
        uint256 recognisedStateId = _registerRecognisedStateForWorkflowStatus(
            workflowKey, AVADataTypes.RecognisedStateStatus.Vested, evidenceId, "m56-terminal-state"
        );

        try externalOperationRegistry.requestOperation(
            AVADataTypes.Role.Panel,
            DEFAULT_WORKFLOW,
            AVADataTypes.ExternalOperationKind.QueueAdjustmentIntent,
            AVADataTypes.ExternalOperationTargetKind.RecognisedState,
            recognisedStateId,
            evidenceId,
            keccak256("panel-authority"),
            "ipfs://m56-wrong-workflow"
        ) {
            revert("external operation accepted wrong workflow target");
        } catch {}

        uint256 operationId = externalOperationRegistry.requestOperation(
            AVADataTypes.Role.Panel,
            workflowKey,
            AVADataTypes.ExternalOperationKind.QueueAdjustmentIntent,
            AVADataTypes.ExternalOperationTargetKind.RecognisedState,
            recognisedStateId,
            evidenceId,
            keccak256("panel-authority"),
            "ipfs://m56-terminal-request"
        );
        uint256 cancelId = externalOperationRegistry.cancelOperation(
            AVADataTypes.Role.Panel, operationId, keccak256("panel-authority"), "ipfs://m56-terminal-cancel"
        );
        AVADataTypes.ExternalOperationRecord memory cancellation = externalOperationRegistry.getExternalOperation(cancelId);
        require(cancellation.sourceOperationId == operationId, "cancel receipt not linked");
        require(cancellation.status == AVADataTypes.ExternalOperationStatus.Cancelled, "cancel status missing");
        try externalOperationRegistry.supersedeOperation(
            AVADataTypes.Role.Panel, operationId, keccak256("panel-authority"), "ipfs://m56-terminal-supersede"
        ) {
            revert("external operation terminal receipt changed twice");
        } catch {}
    }

    function testM84ExternalOperationReceiptsRecordStableOperationContext() public {
        bytes32 workflowKey = keccak256("m84-operation-context-workflow");
        _registerM421ExecutionWorkflow(workflowKey, "ipfs://m84-operation-context-workflow");
        uint256 evidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            workflowKey,
            keccak256("m84-operation-context-evidence"),
            "ipfs://m84-operation-context-evidence",
            "external-operation-reference",
            0
        );
        uint256 recognisedStateId = _registerRecognisedStateForWorkflowStatus(
            workflowKey, AVADataTypes.RecognisedStateStatus.Vested, evidenceId, "m84-operation-context-state"
        );

        uint256 operationId = externalOperationRegistry.requestOperation(
            AVADataTypes.Role.Panel,
            workflowKey,
            AVADataTypes.ExternalOperationKind.QueueAdjustmentIntent,
            AVADataTypes.ExternalOperationTargetKind.RecognisedState,
            recognisedStateId,
            evidenceId,
            keccak256("panel-authority"),
            "ipfs://m84-operation-context-request"
        );
        AVADataTypes.ExternalOperationRecord memory operation = externalOperationRegistry.getExternalOperation(operationId);
        bytes32 expectedContextHash = externalOperationRegistry.computeOperationContextHash(
            workflowKey,
            operation.packageId,
            AVADataTypes.ExternalOperationKind.QueueAdjustmentIntent,
            AVADataTypes.ExternalOperationTargetKind.RecognisedState,
            recognisedStateId,
            evidenceId
        );
        require(operation.operationContextHash == expectedContextHash, "operation context hash mismatch");

        uint256 acknowledgementId = externalOperationRegistry.acknowledgeOperation(
            AVADataTypes.Role.Panel, operationId, keccak256("panel-authority"), "ipfs://m84-operation-context-ack"
        );
        AVADataTypes.ExternalOperationRecord memory acknowledgement =
            externalOperationRegistry.getExternalOperation(acknowledgementId);
        require(acknowledgement.sourceOperationId == operationId, "ack source missing");
        require(acknowledgement.operationContextHash == operation.operationContextHash, "ack context changed");
        require(acknowledgement.packageId == operation.packageId, "ack package changed");
        require(acknowledgement.targetId == operation.targetId, "ack target changed");
        require(acknowledgement.evidenceReceiptId == operation.evidenceReceiptId, "ack evidence changed");
    }
}
