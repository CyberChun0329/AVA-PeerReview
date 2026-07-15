// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./helpers/AVASkeletonFixture.sol";

contract AVASkeletonStandingProof01ATest is AVASkeletonFixture {
    function testStandingCredentialPackageUnboundProofSelectorIsAbsent() public view {
        (bool ok,) = address(standingCredentialRegistry)
            .staticcall(
                abi.encodeWithSignature(
                    "credentialProves(uint256,bytes32,bytes32,bytes32,int256)",
                    uint256(0),
                    bytes32(0),
                    bytes32(0),
                    bytes32(0),
                    int256(0)
                )
            );
        require(!ok, "package-unbound standing proof selector exists");
    }

    function testM422StandingCredentialIssuesFromAuthorisedComputationRecord() public {
        uint256 computationId = _createM422StandingComputationRecord("m422-issue", 42);
        uint256 credentialId = _issueM422StandingCredential(computationId, "m422-issued", block.timestamp + 7 days);
        AVADataTypes.StandingCredentialRecord memory credential =
            standingCredentialRegistry.getStandingCredential(credentialId);

        require(credential.subjectId == REVIEWER_SUBJECT, "credential subject mismatch");
        require(
            credential.packageId == standingRegistry.getStandingComputationRecord(computationId).packageId,
            "package mismatch"
        );
        require(credential.standingComputationRecordId == computationId, "computation source mismatch");
        require(credential.categoryHash == _m422CategoryHash(), "category mismatch");
        require(
            credential.threshold == 40 && credential.lowerBound == 40 && credential.upperBound == 50, "range mismatch"
        );
        require(credential.holder == address(reviewerActor), "credential holder mismatch");
        _assertNoSelector(address(standingCredentialRegistry), "ownerOf(uint256)");
        _assertNoSelector(address(standingCredentialRegistry), "balanceOf(address)");
        require(standingCredentialRegistry.isCredentialActive(credentialId), "credential not active");
    }

    function testM422StandingCredentialRejectsUnknownInactiveAndRawSources() public {
        uint256 manuscriptId = _registerAuthorManuscript();
        uint256 evidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            DEFAULT_WORKFLOW,
            keccak256("m422-raw-review-evidence"),
            "ipfs://m422-raw-review-evidence",
            "review-service-occurrence",
            0
        );
        uint256 rawReviewId = reviewerActor.registerReviewContribution(
            stateMachine, AVADataTypes.Role.Reviewer, manuscriptId, REVIEWER_SUBJECT, evidenceId, 0
        );
        _assertM422CannotIssueFromSource(rawReviewId, "raw review issued credential");
        _assertM422CannotIssueFromSource(evidenceId, "raw evidence issued credential");

        uint256 challengedStateId = _createChallengeableReviewState();
        uint256 challengeEvidenceId = challengerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Challenger,
            DEFAULT_WORKFLOW,
            keccak256("m422-raw-challenge-evidence"),
            "ipfs://m422-raw-challenge-evidence",
            "review-quality-challenge",
            0
        );
        uint256 rawChallengeId = challengerActor.fileChallenge(
            challengeWorkflow,
            AVADataTypes.Role.Challenger,
            DEFAULT_WORKFLOW,
            challengedStateId,
            CHALLENGER_SUBJECT,
            challengeEvidenceId,
            0
        );
        _assertM422CannotIssueFromSource(rawChallengeId, "raw challenge issued credential");

        (uint256 unknownSubjectStateId, uint256 unknownSubjectEvidenceId) =
            _createM421EligibleState(DEFAULT_WORKFLOW, "m422-unknown-subject");
        AVADataTypes.StandingComputationContext memory unknownSubjectContext;
        unknownSubjectContext.recognisedStateId = unknownSubjectStateId;
        unknownSubjectContext.subjectId = keccak256("m422-unknown-standing-subject");
        unknownSubjectContext.dimension = "review-procedure-weight";
        unknownSubjectContext.vectorKey = _m422VectorKey();
        unknownSubjectContext.currentValue = 42;
        unknownSubjectContext.delta = 0;
        unknownSubjectContext.effectiveAt = block.timestamp;
        unknownSubjectContext.epoch = standingRegistry.nextStandingComputationRecordId();
        unknownSubjectContext.sourceRecordSetHash =
            keccak256(abi.encode("m422-unknown-subject", unknownSubjectStateId, unknownSubjectEvidenceId));
        unknownSubjectContext.computationRuleHash = _m422ComputationRuleHash();
        unknownSubjectContext.reversible = true;
        unknownSubjectContext.fieldKey = keccak256("review-service-field");
        unknownSubjectContext.evidenceReceiptId = unknownSubjectEvidenceId;
        unknownSubjectContext.authorityId = keccak256("panel-authority");
        unknownSubjectContext.actor = address(this);
        try standingRegistry.recordStandingComputationReadiness(
            AVADataTypes.Role.Panel, unknownSubjectContext, "ipfs://m422-unknown-subject-standing-computation"
        ) {
            revert("unknown subject produced credential source");
        } catch {}

        uint256 computationId = _createM422StandingComputationRecord("m422-inactive", 42);
        roleRegistry.deactivateSubject(REVIEWER_SUBJECT);
        _assertM422CannotIssueFromSource(computationId, "inactive subject issued credential");
    }

    function testM422ExpiredRevokedAndSupersededCredentialsCannotProve() public {
        uint256 expiringComputationId = _createM422StandingComputationRecord("m422-expiring", 42);
        uint256 expiringCredentialId =
            _issueM422StandingCredential(expiringComputationId, "m422-expiring", block.timestamp + 1);
        require(_m422CredentialProves(expiringCredentialId, 40), "fresh credential should prove");
        vm.warp(block.timestamp + 2);
        require(!standingCredentialRegistry.isCredentialActive(expiringCredentialId), "expired credential active");
        require(!_m422CredentialProves(expiringCredentialId, 40), "expired credential proved");

        uint256 revokedComputationId = _createM422StandingComputationRecord("m422-revoked", 42);
        uint256 revokedCredentialId =
            _issueM422StandingCredential(revokedComputationId, "m422-revoked", block.timestamp + 7 days);
        standingCredentialRegistry.revokeCredential(
            AVADataTypes.Role.Panel, revokedCredentialId, keccak256("panel-authority"), "ipfs://m422-revoke"
        );
        require(!_m422CredentialProves(revokedCredentialId, 40), "revoked credential proved");

        uint256 oldComputationId = _createM422StandingComputationRecord("m422-old", 42);
        uint256 oldCredentialId = _issueM422StandingCredential(oldComputationId, "m422-old", block.timestamp + 7 days);
        uint256 newComputationId = _createM422StandingComputationRecord("m422-new", 45);
        uint256 newCredentialId = standingCredentialRegistry.supersedeCredential(
            AVADataTypes.Role.Panel,
            oldCredentialId,
            _m422CredentialInputForComputation(newComputationId, block.timestamp + 7 days, "ipfs://m422-superseded")
        );
        require(!_m422CredentialProves(oldCredentialId, 40), "superseded credential proved");
        require(_m422CredentialProves(newCredentialId, 40), "replacement credential did not prove");
        require(
            standingCredentialRegistry.getStandingCredential(oldCredentialId).status
                == AVADataTypes.StandingCredentialStatus.Superseded,
            "old credential not superseded"
        );
    }

    function testStandingCredentialFailsClosedAfterSubjectDeactivation() public {
        uint256 computationId = _createM422StandingComputationRecord("subject-deactivation", 42);
        uint256 credentialId =
            _issueM422StandingCredential(computationId, "subject-deactivation", block.timestamp + 7 days);
        require(_m422CredentialProves(credentialId, 40), "credential not active before subject deactivation");

        roleRegistry.deactivateSubject(REVIEWER_SUBJECT);

        require(
            !standingRegistry.isStandingComputationActive(computationId), "inactive subject kept computation active"
        );
        require(!standingCredentialRegistry.isCredentialActive(credentialId), "inactive subject kept credential active");
        require(!_m422CredentialProves(credentialId, 40), "inactive subject credential still proved");
    }

    function testStandingCredentialFailsClosedAfterSourceEvidenceExpiry() public {
        uint256 computationId = _createM422StandingComputationRecord("source-evidence-expiry", 42);
        uint256 credentialId =
            _issueM422StandingCredential(computationId, "source-evidence-expiry", block.timestamp + 7 days);
        AVADataTypes.StandingComputationRecord memory computation =
            standingRegistry.getStandingComputationRecord(computationId);
        require(_m422CredentialProves(credentialId, 40), "credential not active before evidence expiry");

        _expireM51EvidenceReceipt(computation.evidenceReceiptId, "standing-computation-source-expired");

        require(
            !standingRegistry.isStandingComputationActive(computationId), "expired evidence kept computation active"
        );
        require(!standingCredentialRegistry.isCredentialActive(credentialId), "expired evidence kept credential active");
        require(!_m422CredentialProves(credentialId, 40), "expired evidence credential still proved");
    }
}

contract AVASkeletonStandingProof01BTest is AVASkeletonFixture {
    function testM422StandingCredentialIsNonTransferableAndDoesNotCreateBenefits() public {
        uint256 computationId = _createM422StandingComputationRecord("m422-non-transferable", 42);
        uint256 nextStandingUpdateId = standingRegistry.nextStandingUpdateId();
        uint256 nextAllocationId = allocationExecutor.nextAllocationExecutionId();
        uint256 nextConsequenceId = consequenceExecutor.nextConsequenceId();
        uint256 credentialId =
            _issueM422StandingCredential(computationId, "m422-non-transferable", block.timestamp + 7 days);

        try standingCredentialRegistry.transferFrom(address(reviewerActor), address(this), credentialId) {
            revert("standing credential transfer accepted");
        } catch {}
        try standingCredentialRegistry.safeTransferFrom(address(reviewerActor), address(this), credentialId) {
            revert("standing credential safe transfer accepted");
        } catch {}
        try standingCredentialRegistry.approve(address(this), credentialId) {
            revert("standing credential approval accepted");
        } catch {}
        try standingCredentialRegistry.setApprovalForAll(address(this), true) {
            revert("standing credential operator approval accepted");
        } catch {}

        require(
            standingCredentialRegistry.getStandingCredential(credentialId).holder == address(reviewerActor),
            "holder changed"
        );
        require(standingCredentialRegistry.getApproved(credentialId) == address(0), "approval exists");
        require(
            !standingCredentialRegistry.isApprovedForAll(address(reviewerActor), address(this)), "operator approved"
        );
        require(standingRegistry.nextStandingUpdateId() == nextStandingUpdateId, "credential created standing update");
        require(allocationExecutor.nextAllocationExecutionId() == nextAllocationId, "credential created allocation");
        require(consequenceExecutor.nextConsequenceId() == nextConsequenceId, "credential created consequence");

        _assertNoSelector(address(standingCredentialRegistry), "mintReward(uint256)");
        _assertNoSelector(address(standingCredentialRegistry), "transferPayment(uint256)");
        _assertNoSelector(address(standingCredentialRegistry), "mintPriorityToken(uint256)");
        _assertNoSelector(address(standingCredentialRegistry), "grantPublicationPriority(uint256)");
        _assertNoSelector(address(standingCredentialRegistry), "acceptManuscript(uint256)");
        _assertNoSelector(address(standingCredentialRegistry), "rejectManuscript(uint256)");
        _assertNoSelector(address(standingCredentialRegistry), "setManuscriptMerit(uint256,uint256)");
        _assertNoSelector(address(standingCredentialRegistry), "ownerOf(uint256)");
        _assertNoSelector(address(standingCredentialRegistry), "balanceOf(address)");
    }

    function testM422StandingCredentialProvesThresholdAndCategoryWithoutRecomputingHistory() public {
        uint256 computationId = _createM422StandingComputationRecord("m422-proof", 42);
        uint256 nextComputationId = standingRegistry.nextStandingComputationRecordId();
        uint256 credentialId = _issueM422StandingCredential(computationId, "m422-proof", block.timestamp + 7 days);

        require(_m422CredentialProves(credentialId, 40), "credential did not prove threshold");
        require(!_m422CredentialProves(credentialId, 43), "credential proved above standing value");
        require(
            !standingCredentialRegistry.credentialProvesSubjectStanding(
                credentialId,
                standingRegistry.getStandingComputationRecord(computationId).packageId,
                REVIEWER_SUBJECT,
                _m422VectorKey(),
                keccak256("wrong-category"),
                40
            ),
            "credential proved wrong category"
        );
        require(standingRegistry.nextStandingComputationRecordId() == nextComputationId, "proof recomputed standing");
    }

    function testM422StandingCredentialProvesPackageBoundSubjectStandingWithoutOwnerDisclosure() public {
        uint256 computationId = _createM422StandingComputationRecord("m422-hidden-subject-proof", 42);
        uint256 credentialId =
            _issueM422StandingCredential(computationId, "m422-hidden-subject-proof", block.timestamp + 7 days);
        AVADataTypes.StandingComputationRecord memory computation =
            standingRegistry.getStandingComputationRecord(computationId);

        require(
            standingCredentialRegistry.credentialProvesSubjectStanding(
                credentialId, computation.packageId, REVIEWER_SUBJECT, _m422VectorKey(), _m422CategoryHash(), 40
            ),
            "package-bound subject standing proof failed"
        );
        require(
            !standingCredentialRegistry.credentialProvesSubjectStanding(
                credentialId, computation.packageId + 1, REVIEWER_SUBJECT, _m422VectorKey(), _m422CategoryHash(), 40
            ),
            "credential proved wrong package"
        );
        require(
            !standingCredentialRegistry.credentialProvesSubjectStanding(
                credentialId, computation.packageId, CHALLENGER_SUBJECT, _m422VectorKey(), _m422CategoryHash(), 40
            ),
            "credential proved wrong subject"
        );
        require(
            standingCredentialRegistry.getStandingCredential(credentialId).holder == address(reviewerActor),
            "holder reference changed"
        );
    }
}

contract AVASkeletonStandingProof02ATest is AVASkeletonFixture {
    function testM63CredentialProofRequiresMatchingPackageSubjectVectorAndCategory() public {
        uint256 computationId = _createM422StandingComputationRecord("m63-proof-surface", 42);
        uint256 credentialId =
            _issueM422StandingCredential(computationId, "m63-proof-surface", block.timestamp + 7 days);
        AVADataTypes.StandingComputationRecord memory computation =
            standingRegistry.getStandingComputationRecord(computationId);

        require(
            standingCredentialRegistry.credentialProvesSubjectStanding(
                credentialId, computation.packageId, REVIEWER_SUBJECT, _m422VectorKey(), _m422CategoryHash(), 40
            ),
            "valid package-bound proof failed"
        );
        require(
            !standingCredentialRegistry.credentialProvesSubjectStanding(
                credentialId, computation.packageId + 1, REVIEWER_SUBJECT, _m422VectorKey(), _m422CategoryHash(), 40
            ),
            "credential proved wrong package"
        );
        require(
            !standingCredentialRegistry.credentialProvesSubjectStanding(
                credentialId, computation.packageId, CHALLENGER_SUBJECT, _m422VectorKey(), _m422CategoryHash(), 40
            ),
            "credential proved wrong subject"
        );
        require(
            !standingCredentialRegistry.credentialProvesSubjectStanding(
                credentialId,
                computation.packageId,
                REVIEWER_SUBJECT,
                keccak256("m63-wrong-vector"),
                _m422CategoryHash(),
                40
            ),
            "credential proved wrong vector"
        );
        require(
            !standingCredentialRegistry.credentialProvesSubjectStanding(
                credentialId,
                computation.packageId,
                REVIEWER_SUBJECT,
                _m422VectorKey(),
                keccak256("m63-wrong-category"),
                40
            ),
            "credential proved wrong category"
        );
        require(
            !standingCredentialRegistry.credentialProvesSubjectStanding(
                credentialId, computation.packageId, REVIEWER_SUBJECT, _m422VectorKey(), _m422CategoryHash(), 43
            ),
            "credential proved above standing value"
        );
        require(
            !standingCredentialRegistry.credentialProvesSubjectStanding(
                credentialId, computation.packageId, REVIEWER_SUBJECT, _m422VectorKey(), _m422CategoryHash(), 39
            ),
            "credential proved outside lower range"
        );
    }

    function testM63StandingCredentialSupersedeRequiresSamePackageCategoryAndNewerEpoch() public {
        uint256 packageOldComputationId = _createM422StandingComputationRecord("m63-package-old", 42);
        uint256 packageOldCredentialId =
            _issueM422StandingCredential(packageOldComputationId, "m63-package-old", block.timestamp + 7 days);
        bytes32 foreignWorkflowKey = keccak256("m63-foreign-standing-credential-workflow");
        _registerM421ExecutionWorkflow(foreignWorkflowKey, "ipfs://m63-foreign-standing-credential-workflow");
        uint256 foreignComputationId = _createM423StandingComputationRecord(foreignWorkflowKey, "m63-package-new", 45);
        _assertM63CannotSupersedeStandingCredential(
            packageOldCredentialId,
            _m422CredentialInputForComputation(
                foreignComputationId, block.timestamp + 7 days, "ipfs://m63-cross-package-replacement"
            ),
            "cross-package credential supersession accepted"
        );

        uint256 categoryOldComputationId = _createM422StandingComputationRecord("m63-category-old", 42);
        uint256 categoryOldCredentialId =
            _issueM422StandingCredential(categoryOldComputationId, "m63-category-old", block.timestamp + 7 days);
        uint256 categoryNewComputationId = _createM422StandingComputationRecord("m63-category-new", 45);
        IStandingCredentialIssuer.StandingCredentialInput memory categoryReplacement = _m422CredentialInputForComputation(
            categoryNewComputationId, block.timestamp + 7 days, "ipfs://m63-wrong-category-replacement"
        );
        categoryReplacement.categoryHash = keccak256("m63-wrong-category");
        _assertM63CannotSupersedeStandingCredential(
            categoryOldCredentialId, categoryReplacement, "cross-category credential supersession accepted"
        );

        uint256 epochOldComputationId = _createM422StandingComputationRecord("m63-epoch-old", 42);
        uint256 epochOldCredentialId =
            _issueM422StandingCredential(epochOldComputationId, "m63-epoch-old", block.timestamp + 7 days);
        _assertM63CannotSupersedeStandingCredential(
            epochOldCredentialId,
            _m422CredentialInputForComputation(
                epochOldComputationId, block.timestamp + 7 days, "ipfs://m63-same-epoch-replacement"
            ),
            "non-increasing epoch credential supersession accepted"
        );

        uint256 validOldComputationId = _createM422StandingComputationRecord("m63-valid-old", 42);
        uint256 validOldCredentialId =
            _issueM422StandingCredential(validOldComputationId, "m63-valid-old", block.timestamp + 7 days);
        uint256 validNewComputationId = _createM422StandingComputationRecord("m63-valid-new", 45);
        uint256 validNewCredentialId = standingCredentialRegistry.supersedeCredential(
            AVADataTypes.Role.Panel,
            validOldCredentialId,
            _m422CredentialInputForComputation(
                validNewComputationId, block.timestamp + 7 days, "ipfs://m63-valid-replacement"
            )
        );
        require(validNewCredentialId != 0, "valid replacement missing");
        require(
            !standingCredentialRegistry.isCredentialActive(validOldCredentialId), "valid supersession left old active"
        );
    }

    function testM63UnrelatedSettlementCannotSuspendCredentialUseSurface() public {
        bytes32 workflowKey = keccak256("m63-settlement-use-surface");
        _registerM421ExecutionWorkflow(workflowKey, "ipfs://m63-settlement-use-surface");
        uint256 computationId = _createM423StandingComputationRecord(workflowKey, "m63-settlement-credential", 42);
        uint256 credentialId = standingCredentialRegistry.issueCredential(
            AVADataTypes.Role.Panel,
            _m422CredentialInputForComputation(
                computationId, block.timestamp + 7 days, "ipfs://m63-settlement-credential"
            )
        );

        MockERC20 token = _m421FundedToken(100);
        uint256 sourceId =
            _createM421RewardSource(workflowKey, "m63-bound-source", token, 6, AVADataTypes.ValueExecutionMode.Claim);
        uint256 settlementId = valueSettlementExecutor.settleTokenTransfer(
            AVADataTypes.Role.ProtocolExecutor,
            AVADataTypes.ExecutionSourceType.AllocationRecord,
            sourceId,
            keccak256("executor-authority"),
            "ipfs://m63-bound-settlement"
        );
        uint256 otherSourceId =
            _createM421RewardSource(workflowKey, "m63-other-source", token, 4, AVADataTypes.ValueExecutionMode.Claim);
        uint256 otherSettlementId = valueSettlementExecutor.settleTokenTransfer(
            AVADataTypes.Role.ProtocolExecutor,
            AVADataTypes.ExecutionSourceType.AllocationRecord,
            otherSourceId,
            keccak256("executor-authority"),
            "ipfs://m63-other-settlement"
        );
        _assertM424InvalidSettlementDoesNotSuspend(
            credentialId,
            AVADataTypes.ExecutionSourceType.AllocationRecord,
            sourceId,
            otherSettlementId,
            "wrong settlement source suspended credential"
        );

        (uint256 authorSourceId, uint256 authorSettlementId) =
            _createM425AuthorRewardSettlement(workflowKey, "m63-author-source", token, 2);
        _assertM424InvalidSettlementDoesNotSuspend(
            credentialId,
            AVADataTypes.ExecutionSourceType.AllocationRecord,
            authorSourceId,
            authorSettlementId,
            "wrong settlement subject suspended credential"
        );

        standingCredentialRegistry.recordStandingRelevantSettlement(
            AVADataTypes.Role.Panel,
            credentialId,
            AVADataTypes.StandingRelevantSettlementKind.RewardExecution,
            AVADataTypes.ExecutionSourceType.AllocationRecord,
            sourceId,
            settlementId,
            keccak256("panel-authority"),
            "ipfs://m63-valid-impact"
        );
        require(!standingCredentialRegistry.isCredentialActive(credentialId), "valid settlement did not suspend");
        require(!_m422CredentialProves(credentialId, 40), "valid settlement left proof active");
    }
}

contract AVASkeletonStandingProof02BTest is AVASkeletonFixture {
    function testM65ZKStandingProofRegistersPackageBoundStandingReceipt() public {
        bytes32 subjectCommitment = _subjectCommitmentForSecret(7);
        ZKStandingComputationRegistry.StandingProofInput memory input =
            _m65StandingProofInput(DEFAULT_WORKFLOW, subjectCommitment, "m65-valid-proof");
        uint256 statementId;
        (input,,, statementId) = _bindM93StandingProofInput(input, "m65-valid-proof");
        bytes32 contextHash = zkStandingComputationRegistry.computeStandingComputationContextHash(input);
        uint256 receiptId =
            zkStandingComputationRegistry.registerStandingProof(input, _makeSchnorrProof(contextHash, 7, 11));
        ZKStandingComputationRegistry.StandingProofReceipt memory receipt =
            zkStandingComputationRegistry.getStandingProofReceipt(receiptId);
        uint256 packageId = rulePackageRegistry.getRulePackage(PEER_REVIEW_APP_ID, DEFAULT_WORKFLOW).packageId;

        require(receipt.packageId == packageId, "standing proof package missing");
        require(receipt.standingComputationStatementId == statementId, "standing proof statement missing");
        require(receipt.contextHash == contextHash, "standing proof context missing");
        require(receipt.subjectCommitment == subjectCommitment, "standing proof subject missing");
        require(receipt.vectorKey == input.vectorKey, "standing proof vector missing");
        require(receipt.categoryHash == input.categoryHash, "standing proof category missing");
        require(receipt.sourceRecordSetRoot == input.sourceRecordSetRoot, "standing proof source root missing");
        require(receipt.computationRuleHash == input.computationRuleHash, "standing proof rule missing");
        require(
            receipt.nullifierHash == zkStandingComputationRegistry.computeNullifierHash(contextHash, subjectCommitment),
            "standing proof nullifier missing"
        );
        require(
            zkStandingComputationRegistry.standingProofSupportsCredential(
                receiptId, packageId, subjectCommitment, input.vectorKey, input.categoryHash, 40
            ),
            "standing proof did not support valid credential surface"
        );
        require(
            !zkStandingComputationRegistry.standingProofSupportsCredential(
                receiptId, packageId + 1, subjectCommitment, input.vectorKey, input.categoryHash, 40
            ),
            "standing proof supported wrong package"
        );
        require(
            !zkStandingComputationRegistry.standingProofSupportsCredential(
                receiptId, packageId, _subjectCommitmentForSecret(9), input.vectorKey, input.categoryHash, 40
            ),
            "standing proof supported wrong subject"
        );
        require(
            !zkStandingComputationRegistry.standingProofSupportsCredential(
                receiptId, packageId, subjectCommitment, keccak256("m65-wrong-vector"), input.categoryHash, 40
            ),
            "standing proof supported wrong vector"
        );
        require(
            !zkStandingComputationRegistry.standingProofSupportsCredential(
                receiptId, packageId, subjectCommitment, input.vectorKey, keccak256("m65-wrong-category"), 40
            ),
            "standing proof supported wrong category"
        );
        require(
            !zkStandingComputationRegistry.standingProofSupportsCredential(
                receiptId, packageId, subjectCommitment, input.vectorKey, input.categoryHash, 43
            ),
            "standing proof supported above standing value"
        );
        require(
            !zkStandingComputationRegistry.standingProofSupportsCredential(
                receiptId, packageId, subjectCommitment, input.vectorKey, input.categoryHash, 39
            ),
            "standing proof supported outside lower range"
        );
        _assertNoSelector(address(zkStandingComputationRegistry), "revealIdentity(uint256)");
        _assertNoSelector(address(zkStandingComputationRegistry), "revealEvidence(uint256)");
        _assertNoSelector(address(zkStandingComputationRegistry), "decryptEvidence(uint256)");
        _assertNoSelector(address(zkStandingComputationRegistry), "acceptManuscript(uint256)");
        _assertNoSelector(address(zkStandingComputationRegistry), "setManuscriptMerit(uint256,uint256)");
        _assertNoSelector(address(zkStandingComputationRegistry), "mintReward(uint256)");
        _assertNoSelector(address(zkStandingComputationRegistry), "mintPriorityToken(uint256)");
        _assertNoSelector(address(zkStandingComputationRegistry), "transferStanding(uint256)");
    }

    function testM65ZKStandingProofRejectsReplayAndBadSubjectBinding() public {
        bytes32 subjectCommitment = _subjectCommitmentForSecret(7);
        ZKStandingComputationRegistry.StandingProofInput memory input =
            _m65StandingProofInput(DEFAULT_WORKFLOW, subjectCommitment, "m65-replay");
        (input,,,) = _bindM93StandingProofInput(input, "m65-replay");
        bytes32 contextHash = zkStandingComputationRegistry.computeStandingComputationContextHash(input);
        IZKProofVerifier.SchnorrProof memory proof = _makeSchnorrProof(contextHash, 7, 11);

        zkStandingComputationRegistry.registerStandingProof(input, proof);
        uint256 nextReceiptId = zkStandingComputationRegistry.nextStandingProofReceiptId();
        _assertM65CannotRegisterStandingProof(input, proof, "standing proof replay accepted");
        require(
            zkStandingComputationRegistry.nextStandingProofReceiptId() == nextReceiptId, "replay wrote proof receipt"
        );

        ZKStandingComputationRegistry.StandingProofInput memory wrongSubjectInput =
            _m65StandingProofInput(DEFAULT_WORKFLOW, _subjectCommitmentForSecret(9), "m65-wrong-subject");
        bytes32 wrongSubjectContext =
            zkStandingComputationRegistry.computeStandingComputationContextHash(wrongSubjectInput);
        _assertM65CannotRegisterStandingProof(
            wrongSubjectInput,
            _makeSchnorrProof(wrongSubjectContext, 7, 13),
            "standing proof accepted mismatched subject commitment"
        );
    }

    function testM65ZKStandingProofCannotCrossPackageAfterWorkflowReregistration() public {
        bytes32 workflowKey = keccak256("m65-reregistered-workflow");
        _ensureWorkflowPackage(workflowKey);
        bytes32 subjectCommitment = _subjectCommitmentForSecret(7);
        ZKStandingComputationRegistry.StandingProofInput memory input =
            _m65StandingProofInput(workflowKey, subjectCommitment, "m65-package-binding");
        uint256 oldStatementId;
        (input,,, oldStatementId) = _bindM93StandingProofInput(input, "m65-package-binding-old");
        bytes32 oldContextHash = zkStandingComputationRegistry.computeStandingComputationContextHash(input);
        uint256 oldPackageId = rulePackageRegistry.getRulePackage(PEER_REVIEW_APP_ID, workflowKey).packageId;

        _registerM421ExecutionWorkflow(workflowKey, "ipfs://m65-reregistered-workflow");
        uint256 newPackageId = rulePackageRegistry.getRulePackage(PEER_REVIEW_APP_ID, workflowKey).packageId;
        require(newPackageId != oldPackageId, "workflow package did not change");
        require(
            zkStandingComputationRegistry.computeStandingComputationContextHash(input) == oldContextHash,
            "active workflow rewrote old statement context"
        );
        ZKStandingComputationRegistry.StandingProofInput memory newPackageInput =
            _m65StandingProofInput(workflowKey, subjectCommitment, "m65-package-binding");
        uint256 newStatementId;
        (newPackageInput,,, newStatementId) = _bindM93StandingProofInput(newPackageInput, "m65-package-binding-new");
        bytes32 newContextHash = zkStandingComputationRegistry.computeStandingComputationContextHash(newPackageInput);
        require(newContextHash != oldContextHash, "standing proof context omitted statement package");
        ZKStandingComputationRegistry.StandingProofInput memory mixedPackageInput = newPackageInput;
        mixedPackageInput.standingComputationStatementId = oldStatementId;
        _assertM65CannotRegisterStandingProof(
            mixedPackageInput,
            _makeSchnorrProof(
                zkStandingComputationRegistry.computeStandingComputationContextHash(mixedPackageInput), 7, 13
            ),
            "new package proof accepted old computation statement"
        );
        newPackageInput.standingComputationStatementId = newStatementId;
        uint256 receiptId = zkStandingComputationRegistry.registerStandingProof(
            newPackageInput, _makeSchnorrProof(newContextHash, 7, 13)
        );
        require(
            zkStandingComputationRegistry.getStandingProofReceipt(receiptId).packageId == newPackageId,
            "standing proof used stale package"
        );
        require(
            zkStandingComputationRegistry.getStandingProofReceipt(receiptId).standingComputationStatementId
                == newStatementId,
            "standing proof used stale statement"
        );
    }
}

contract AVASkeletonStandingProof03ATest is AVASkeletonFixture {
    function testM65ZKStandingProofRejectsEmptyOrOutOfRangeContext() public {
        bytes32 subjectCommitment = _subjectCommitmentForSecret(7);
        ZKStandingComputationRegistry.StandingProofInput memory input =
            _m65StandingProofInput(DEFAULT_WORKFLOW, subjectCommitment, "m65-invalid-context");
        (input,,,) = _bindM93StandingProofInput(input, "m65-invalid-context");
        bytes32 contextHash = zkStandingComputationRegistry.computeStandingComputationContextHash(input);

        ZKStandingComputationRegistry.StandingProofInput memory zeroWorkflow = input;
        zeroWorkflow.workflowKey = bytes32(0);
        _assertM65CannotRegisterStandingProof(
            zeroWorkflow, _makeSchnorrProof(contextHash, 7, 11), "zero workflow standing proof accepted"
        );
        ZKStandingComputationRegistry.StandingProofInput memory unknownWorkflow = input;
        unknownWorkflow.workflowKey = keccak256("m65-unknown-workflow");
        _assertM65CannotRegisterStandingProof(
            unknownWorkflow, _makeSchnorrProof(contextHash, 7, 11), "unknown workflow standing proof accepted"
        );

        ZKStandingComputationRegistry.StandingProofInput memory zeroSourceRoot = input;
        zeroSourceRoot.sourceRecordSetRoot = bytes32(0);
        _assertM65CannotRegisterStandingProof(
            zeroSourceRoot, _makeSchnorrProof(contextHash, 7, 11), "zero source root standing proof accepted"
        );

        ZKStandingComputationRegistry.StandingProofInput memory badRange = input;
        badRange.threshold = 60;
        _assertM65CannotRegisterStandingProof(
            badRange, _makeSchnorrProof(contextHash, 7, 11), "out-of-range standing proof accepted"
        );
    }

    function testM68ZKStandingProofRequiresRegisteredFormulaAndSourceSetCommitment() public {
        bytes32 subjectCommitment = _subjectCommitmentForSecret(7);
        ZKStandingComputationRegistry.StandingProofInput memory input =
            _m65StandingProofInput(DEFAULT_WORKFLOW, subjectCommitment, "m68-required-source-set");
        bytes32 contextHash = zkStandingComputationRegistry.computeStandingComputationContextHash(input);
        IZKProofVerifier.SchnorrProof memory proof = _makeSchnorrProof(contextHash, 7, 11);

        _assertM65CannotRegisterStandingProof(input, proof, "unregistered formula/source set accepted");

        uint256 formulaId = _registerM68Formula(input, "m68-required-source-set");
        _assertM65CannotRegisterStandingProof(input, proof, "formula without source set accepted");

        uint256 evidenceId = _registerM68SourceSetEvidence(input.workflowKey, "m68-required-source-set");
        uint256 sourceSetCommitmentId =
            _registerM68SourceSetCommitment(formulaId, input, evidenceId, "m68-required-source-set");
        IStandingFormulaRegistry.SourceSetCommitmentRecord memory commitment =
            standingFormulaRegistry.getSourceSetCommitment(sourceSetCommitmentId);
        require(commitment.sourceRecordSetRoot == input.sourceRecordSetRoot, "source root not recorded");
        require(commitment.computationRuleHash == input.computationRuleHash, "rule hash not recorded");
        require(
            standingFormulaRegistry.proofInputMatchesRegisteredCommitment(
                PEER_REVIEW_APP_ID,
                input.workflowKey,
                input.subjectCommitment,
                input.vectorKey,
                input.categoryHash,
                input.epoch,
                input.sourceRecordSetRoot,
                input.computationRuleHash,
                address(zkStandingComputationRegistry.verifier())
            ),
            "registered proof input not matched"
        );

        _assertM65CannotRegisterStandingProof(input, proof, "source set without computation statement accepted");
        input.outputCommitmentHash =
            keccak256(abi.encode("m68-required-source-set", subjectCommitment, "standing-output"));
        uint256 attestationId =
            _registerM92SourceSetCompletenessAttestation(sourceSetCommitmentId, evidenceId, "m68-required-source-set");
        IStandingFormulaRegistry.StandingComputationStatementInput memory statementInput = _m91ComputationStatementInput(
            sourceSetCommitmentId, attestationId, input, evidenceId, "m68-required-source-set"
        );
        input.standingComputationStatementId =
            standingFormulaRegistry.registerStandingComputationStatement(AVADataTypes.Role.Panel, statementInput);
        contextHash = zkStandingComputationRegistry.computeStandingComputationContextHash(input);
        uint256 receiptId =
            zkStandingComputationRegistry.registerStandingProof(input, _makeSchnorrProof(contextHash, 7, 11));
        require(receiptId != 0, "registered source set proof rejected");
    }

    function testM68SourceSetCommitmentLookupCanUseHistoricalPackageAfterWorkflowReregistration() public {
        bytes32 workflowKey = keccak256("m68-source-set-historical-package");
        _registerRulePackageWithFutureProofModules(
            workflowKey,
            valueExecutionAdapter,
            standingComputationModule,
            rulePackageLifecycleModule,
            evidenceLifecycleModule,
            disclosureExecutionModule,
            1,
            keccak256("ava-m6-8-compatible"),
            false,
            "ipfs://m68-source-set-historical-v1"
        );
        AVARulePackageRegistry.RulePackage memory oldPackage = rulePackageRegistry.getRulePackage(PEER_REVIEW_APP_ID, workflowKey);
        bytes32 subjectCommitment = _subjectCommitmentForSecret(7);
        ZKStandingComputationRegistry.StandingProofInput memory input =
            _m65StandingProofInput(workflowKey, subjectCommitment, "m68-source-set-historical");
        uint256 formulaId = _registerM68Formula(input, "m68-source-set-historical");
        uint256 evidenceId = _registerM68SourceSetEvidence(input.workflowKey, "m68-source-set-historical");
        uint256 sourceSetCommitmentId =
            _registerM68SourceSetCommitment(formulaId, input, evidenceId, "m68-source-set-historical");

        _registerRulePackageWithFutureProofModules(
            workflowKey,
            valueExecutionAdapter,
            standingComputationModule,
            rulePackageLifecycleModule,
            evidenceLifecycleModule,
            disclosureExecutionModule,
            2,
            keccak256("ava-m6-8-compatible"),
            false,
            "ipfs://m68-source-set-historical-v2"
        );
        require(
            rulePackageRegistry.getRulePackage(PEER_REVIEW_APP_ID, workflowKey).packageId != oldPackage.packageId,
            "workflow package did not rotate"
        );
        require(
            standingFormulaRegistry.getSourceSetCommitmentIdForProofInput(
                PEER_REVIEW_APP_ID,
                workflowKey,
                input.subjectCommitment,
                input.vectorKey,
                input.categoryHash,
                input.epoch,
                input.sourceRecordSetRoot,
                input.computationRuleHash,
                address(zkStandingComputationRegistry.verifier())
            ) == 0,
            "active lookup unexpectedly returned old package commitment"
        );
        require(
            standingFormulaRegistry.getSourceSetCommitmentIdForPackageProofInput(
                oldPackage.packageId,
                workflowKey,
                input.subjectCommitment,
                input.vectorKey,
                input.categoryHash,
                input.epoch,
                input.sourceRecordSetRoot,
                input.computationRuleHash,
                address(zkStandingComputationRegistry.verifier())
            ) == sourceSetCommitmentId,
            "package-bound source-set proof lookup missed historical commitment"
        );
    }
}

contract AVASkeletonStandingProof03BTest is AVASkeletonFixture {
    function testM82StandingProofReceiptBindsExactFormulaAndSourceSetCommitment() public {
        bytes32 subjectCommitment = _subjectCommitmentForSecret(7);
        ZKStandingComputationRegistry.StandingProofInput memory input =
            _m65StandingProofInput(DEFAULT_WORKFLOW, subjectCommitment, "m82-proof-chain");
        uint256 formulaId;
        uint256 sourceSetCommitmentId;
        uint256 statementId;
        (input, formulaId, sourceSetCommitmentId, statementId) = _bindM93StandingProofInput(input, "m82-proof-chain");
        IStandingFormulaRegistry.StandingFormulaRecord memory formula =
            standingFormulaRegistry.getStandingFormula(formulaId);
        IStandingFormulaRegistry.SourceSetCommitmentRecord memory commitment =
            standingFormulaRegistry.getSourceSetCommitment(sourceSetCommitmentId);
        require(
            standingFormulaRegistry.getSourceSetCommitmentIdForProofInput(
                PEER_REVIEW_APP_ID,
                input.workflowKey,
                input.subjectCommitment,
                input.vectorKey,
                input.categoryHash,
                input.epoch,
                input.sourceRecordSetRoot,
                input.computationRuleHash,
                address(zkStandingComputationRegistry.verifier())
            ) == sourceSetCommitmentId,
            "source-set proof lookup not exact"
        );

        bytes32 contextHash = zkStandingComputationRegistry.computeStandingComputationContextHash(input);
        uint256 receiptId =
            zkStandingComputationRegistry.registerStandingProof(input, _makeSchnorrProof(contextHash, 7, 11));
        ZKStandingComputationRegistry.StandingProofReceipt memory receipt =
            zkStandingComputationRegistry.getStandingProofReceipt(receiptId);

        require(receipt.formulaId == formulaId, "standing proof formula id missing");
        require(receipt.sourceSetCommitmentId == sourceSetCommitmentId, "standing proof source-set id missing");
        require(receipt.standingComputationStatementId == statementId, "standing proof statement id missing");
        require(receipt.formulaVersion == formula.formulaVersion, "standing proof formula version missing");
        require(receipt.sourceSetPolicyHash == formula.sourceSetPolicyHash, "standing proof source policy missing");
        require(receipt.sourceSetPolicyHash == commitment.sourceSetPolicyHash, "standing proof source policy mismatch");
        require(receipt.outputCommitmentHash == input.outputCommitmentHash, "standing proof output commitment missing");
    }

    function testM91StandingComputationStatementRegistersAuthorisedComputationOutput() public {
        bytes32 subjectCommitment = _subjectCommitmentForSecret(7);
        ZKStandingComputationRegistry.StandingProofInput memory input =
            _m65StandingProofInput(DEFAULT_WORKFLOW, subjectCommitment, "m91-statement");
        (uint256 formulaId, uint256 sourceSetCommitmentId) = _registerM68FormulaAndSourceSet(input, "m91-statement");
        uint256 evidenceId = _registerM68SourceSetEvidence(input.workflowKey, "m91-statement-evidence");
        uint256 attestationId =
            _registerM92SourceSetCompletenessAttestation(sourceSetCommitmentId, evidenceId, "m91-statement");
        IStandingFormulaRegistry.StandingComputationStatementInput memory statementInput =
            _m91ComputationStatementInput(sourceSetCommitmentId, attestationId, input, evidenceId, "m91-statement");

        uint256 statementId =
            standingFormulaRegistry.registerStandingComputationStatement(AVADataTypes.Role.Panel, statementInput);
        IStandingFormulaRegistry.StandingComputationStatementRecord memory statement =
            standingFormulaRegistry.getStandingComputationStatement(statementId);
        IStandingFormulaRegistry.StandingFormulaRecord memory formula =
            standingFormulaRegistry.getStandingFormula(formulaId);

        require(statement.sourceSetCommitmentId == sourceSetCommitmentId, "statement source-set missing");
        require(statement.sourceSetCompletenessAttestationId == attestationId, "statement attestation missing");
        require(statement.formulaId == formulaId, "statement formula missing");
        require(statement.workflowKey == input.workflowKey, "statement workflow missing");
        require(statement.packageId == formula.packageId, "statement package missing");
        require(statement.subjectCommitment == input.subjectCommitment, "statement subject missing");
        require(statement.vectorKey == input.vectorKey, "statement vector missing");
        require(statement.categoryHash == input.categoryHash, "statement category missing");
        require(statement.outputCommitmentHash == statementInput.outputCommitmentHash, "statement output missing");
        require(statement.proofDomainHash == statementInput.proofDomainHash, "statement proof domain missing");
        require(statement.status == AVADataTypes.StandingComputationStatus.Active, "statement not active");
        require(
            standingFormulaRegistry.isStandingComputationStatementActive(statementId), "statement active helper false"
        );
    }

    function testM91StandingComputationStatementRejectsMismatchedFieldsAndUnauthorisedCaller() public {
        bytes32 subjectCommitment = _subjectCommitmentForSecret(7);
        ZKStandingComputationRegistry.StandingProofInput memory input =
            _m65StandingProofInput(DEFAULT_WORKFLOW, subjectCommitment, "m91-reject");
        (, uint256 sourceSetCommitmentId) = _registerM68FormulaAndSourceSet(input, "m91-reject");
        uint256 evidenceId = _registerM68SourceSetEvidence(input.workflowKey, "m91-reject-evidence");
        uint256 attestationId =
            _registerM92SourceSetCompletenessAttestation(sourceSetCommitmentId, evidenceId, "m91-reject");
        IStandingFormulaRegistry.StandingComputationStatementInput memory statementInput =
            _m91ComputationStatementInput(sourceSetCommitmentId, attestationId, input, evidenceId, "m91-reject");

        try outsiderActor.registerStandingComputationStatement(
            standingFormulaRegistry, AVADataTypes.Role.Panel, statementInput
        ) {
            revert("unauthorised computation statement registered");
        } catch {}

        IStandingFormulaRegistry.StandingComputationStatementInput memory wrongSubject = statementInput;
        wrongSubject.subjectCommitment = _subjectCommitmentForSecret(9);
        _assertM91CannotRegisterComputationStatement(wrongSubject, "wrong subject computation statement registered");

        IStandingFormulaRegistry.StandingComputationStatementInput memory zeroOutput = statementInput;
        zeroOutput.outputCommitmentHash = bytes32(0);
        _assertM91CannotRegisterComputationStatement(zeroOutput, "zero output computation statement registered");

        bytes32 workflowKey = keccak256("m91-wrong-package-workflow");
        _ensureWorkflowPackage(workflowKey);
        ZKStandingComputationRegistry.StandingProofInput memory oldInput =
            _m65StandingProofInput(workflowKey, subjectCommitment, "m91-old-package-statement");
        (, uint256 oldSourceSetCommitmentId) = _registerM68FormulaAndSourceSet(oldInput, "m91-old-package-statement");
        uint256 oldAttestationEvidenceId =
            _registerM68SourceSetEvidence(workflowKey, "m91-old-package-attestation-evidence");
        uint256 oldAttestationId = _registerM92SourceSetCompletenessAttestation(
            oldSourceSetCommitmentId, oldAttestationEvidenceId, "m91-old-package-statement"
        );
        uint256 oldPackageId = rulePackageRegistry.getRulePackage(PEER_REVIEW_APP_ID, workflowKey).packageId;
        _registerM421ExecutionWorkflow(workflowKey, "ipfs://m91-new-package-statement");
        uint256 newEvidenceId = _registerM68SourceSetEvidence(workflowKey, "m91-new-package-statement-evidence");
        require(evidenceRegistry.getEvidenceReceipt(newEvidenceId).packageId != oldPackageId, "package did not change");
        IStandingFormulaRegistry.StandingComputationStatementInput memory wrongEvidence = _m91ComputationStatementInput(
            oldSourceSetCommitmentId, oldAttestationId, oldInput, newEvidenceId, "m91-wrong-evidence"
        );
        _assertM91CannotRegisterComputationStatement(wrongEvidence, "new package evidence registered old statement");
    }
}

contract AVASkeletonStandingProof04ATest is AVASkeletonFixture {
    function testM91ComputationStatementDoesNotCreateProofCredentialOrBenefits() public {
        bytes32 subjectCommitment = _subjectCommitmentForSecret(7);
        ZKStandingComputationRegistry.StandingProofInput memory input =
            _m65StandingProofInput(DEFAULT_WORKFLOW, subjectCommitment, "m91-record-only");
        (, uint256 sourceSetCommitmentId) = _registerM68FormulaAndSourceSet(input, "m91-record-only");
        uint256 evidenceId = _registerM68SourceSetEvidence(input.workflowKey, "m91-record-only-evidence");
        uint256 attestationId =
            _registerM92SourceSetCompletenessAttestation(sourceSetCommitmentId, evidenceId, "m91-record-only");
        IStandingFormulaRegistry.StandingComputationStatementInput memory statementInput =
            _m91ComputationStatementInput(sourceSetCommitmentId, attestationId, input, evidenceId, "m91-record-only");
        uint256 nextProofReceiptId = zkStandingComputationRegistry.nextStandingProofReceiptId();
        uint256 nextCredentialId = zkStandingCredentialRegistry.nextCredentialId();

        standingFormulaRegistry.registerStandingComputationStatement(AVADataTypes.Role.Panel, statementInput);

        require(
            zkStandingComputationRegistry.nextStandingProofReceiptId() == nextProofReceiptId, "statement wrote proof"
        );
        require(zkStandingCredentialRegistry.nextCredentialId() == nextCredentialId, "statement issued credential");
        _assertNoSelector(address(standingFormulaRegistry), "mintReward(uint256)");
        _assertNoSelector(address(standingFormulaRegistry), "mintPriorityToken(uint256)");
        _assertNoSelector(address(standingFormulaRegistry), "acceptManuscript(uint256)");
        _assertNoSelector(address(standingFormulaRegistry), "setManuscriptMerit(uint256,uint256)");
        _assertNoSelector(address(standingFormulaRegistry), "revealIdentity(uint256)");
        _assertNoSelector(address(standingFormulaRegistry), "revealEvidence(uint256)");
        _assertNoSelector(address(standingFormulaRegistry), "decryptEvidence(uint256)");
    }

    function testM92SourceSetCompletenessAttestationRecordsPolicyAndEvidence() public {
        bytes32 subjectCommitment = _subjectCommitmentForSecret(7);
        ZKStandingComputationRegistry.StandingProofInput memory input =
            _m65StandingProofInput(DEFAULT_WORKFLOW, subjectCommitment, "m92-attestation");
        (uint256 formulaId, uint256 sourceSetCommitmentId) = _registerM68FormulaAndSourceSet(input, "m92-attestation");
        uint256 evidenceId = _registerM68SourceSetEvidence(input.workflowKey, "m92-attestation-evidence");
        IStandingFormulaRegistry.SourceSetCompletenessAttestationInput memory attestationInput =
            _m92SourceSetCompletenessAttestationInput(sourceSetCommitmentId, evidenceId, "m92-attestation");

        uint256 attestationId =
            standingFormulaRegistry.registerSourceSetCompletenessAttestation(AVADataTypes.Role.Panel, attestationInput);
        IStandingFormulaRegistry.SourceSetCompletenessAttestationRecord memory attestation =
            standingFormulaRegistry.getSourceSetCompletenessAttestation(attestationId);
        IStandingFormulaRegistry.StandingFormulaRecord memory formula =
            standingFormulaRegistry.getStandingFormula(formulaId);

        require(attestation.sourceSetCommitmentId == sourceSetCommitmentId, "attestation source-set missing");
        require(attestation.formulaId == formulaId, "attestation formula missing");
        require(attestation.workflowKey == input.workflowKey, "attestation workflow missing");
        require(attestation.packageId == formula.packageId, "attestation package missing");
        require(attestation.subjectCommitment == input.subjectCommitment, "attestation subject missing");
        require(attestation.vectorKey == input.vectorKey, "attestation vector missing");
        require(attestation.categoryHash == input.categoryHash, "attestation category missing");
        require(attestation.sourceRecordSetRoot == input.sourceRecordSetRoot, "attestation source root missing");
        require(attestation.computationRuleHash == input.computationRuleHash, "attestation rule missing");
        require(attestation.includedRecordClassesHash != bytes32(0), "attestation classes missing");
        require(attestation.exclusionPolicyHash != bytes32(0), "attestation exclusion missing");
        require(attestation.evidenceReceiptId == evidenceId, "attestation evidence missing");
        require(
            attestation.completenessAttestationHash == attestationInput.completenessAttestationHash,
            "attestation hash missing"
        );
        require(
            standingFormulaRegistry.isSourceSetCompletenessAttestationActive(attestationId), "attestation not active"
        );
    }

    function testM92SourceSetCompletenessAttestationRejectsUnknownWrongPackageAndZeroFields() public {
        bytes32 subjectCommitment = _subjectCommitmentForSecret(7);
        ZKStandingComputationRegistry.StandingProofInput memory input =
            _m65StandingProofInput(DEFAULT_WORKFLOW, subjectCommitment, "m92-reject");
        (, uint256 sourceSetCommitmentId) = _registerM68FormulaAndSourceSet(input, "m92-reject");
        uint256 evidenceId = _registerM68SourceSetEvidence(input.workflowKey, "m92-reject-evidence");
        IStandingFormulaRegistry.SourceSetCompletenessAttestationInput memory attestationInput =
            _m92SourceSetCompletenessAttestationInput(sourceSetCommitmentId, evidenceId, "m92-reject");

        IStandingFormulaRegistry.SourceSetCompletenessAttestationInput memory unknownSourceSet = attestationInput;
        unknownSourceSet.sourceSetCommitmentId = 999_999;
        _assertM92CannotRegisterSourceSetCompletenessAttestation(
            unknownSourceSet, "unknown source-set attestation registered"
        );

        IStandingFormulaRegistry.SourceSetCompletenessAttestationInput memory zeroClasses = attestationInput;
        zeroClasses.includedRecordClassesHash = bytes32(0);
        _assertM92CannotRegisterSourceSetCompletenessAttestation(zeroClasses, "zero included classes registered");

        IStandingFormulaRegistry.SourceSetCompletenessAttestationInput memory zeroExclusion = attestationInput;
        zeroExclusion.exclusionPolicyHash = bytes32(0);
        _assertM92CannotRegisterSourceSetCompletenessAttestation(zeroExclusion, "zero exclusion policy registered");

        IStandingFormulaRegistry.SourceSetCompletenessAttestationInput memory zeroEvidence = attestationInput;
        zeroEvidence.evidenceReceiptId = 0;
        _assertM92CannotRegisterSourceSetCompletenessAttestation(zeroEvidence, "zero attestation evidence registered");

        IStandingFormulaRegistry.SourceSetCompletenessAttestationInput memory wrongHash = attestationInput;
        wrongHash.completenessAttestationHash = keccak256("m92-wrong-completeness");
        _assertM92CannotRegisterSourceSetCompletenessAttestation(wrongHash, "wrong completeness hash registered");

        IStandingFormulaRegistry.SourceSetCompletenessAttestationInput memory wrongAuthority = attestationInput;
        wrongAuthority.authorityId = keccak256("wrong-panel-authority");
        _assertM92CannotRegisterSourceSetCompletenessAttestation(wrongAuthority, "wrong authority registered");

        bytes32 workflowKey = keccak256("m92-wrong-package-workflow");
        _ensureWorkflowPackage(workflowKey);
        ZKStandingComputationRegistry.StandingProofInput memory oldInput =
            _m65StandingProofInput(workflowKey, subjectCommitment, "m92-old-package-attestation");
        (, uint256 oldSourceSetCommitmentId) = _registerM68FormulaAndSourceSet(oldInput, "m92-old-package-attestation");
        uint256 oldPackageId = rulePackageRegistry.getRulePackage(PEER_REVIEW_APP_ID, workflowKey).packageId;
        _registerM421ExecutionWorkflow(workflowKey, "ipfs://m92-new-package-attestation");
        uint256 newPackageEvidence = _registerM68SourceSetEvidence(workflowKey, "m92-new-package-attestation-evidence");
        require(
            evidenceRegistry.getEvidenceReceipt(newPackageEvidence).packageId != oldPackageId, "package did not change"
        );
        IStandingFormulaRegistry.SourceSetCompletenessAttestationInput memory wrongPackage =
            _m92SourceSetCompletenessAttestationInput(
                oldSourceSetCommitmentId, newPackageEvidence, "m92-wrong-package-attestation"
            );
        _assertM92CannotRegisterSourceSetCompletenessAttestation(
            wrongPackage, "new package attestation evidence registered"
        );
    }
}

contract AVASkeletonStandingProof04BTest is AVASkeletonFixture {
    function testM92ComputationStatementRequiresMatchingCompletenessAttestation() public {
        bytes32 subjectCommitment = _subjectCommitmentForSecret(7);
        ZKStandingComputationRegistry.StandingProofInput memory input =
            _m65StandingProofInput(DEFAULT_WORKFLOW, subjectCommitment, "m92-statement-binding");
        (, uint256 sourceSetCommitmentId) = _registerM68FormulaAndSourceSet(input, "m92-statement-binding");
        uint256 evidenceId = _registerM68SourceSetEvidence(input.workflowKey, "m92-statement-binding-evidence");
        IStandingFormulaRegistry.StandingComputationStatementInput memory missingAttestation =
            _m91ComputationStatementInput(sourceSetCommitmentId, 0, input, evidenceId, "m92-missing-attestation");
        _assertM91CannotRegisterComputationStatement(missingAttestation, "statement without attestation registered");

        ZKStandingComputationRegistry.StandingProofInput memory otherInput =
            _m65StandingProofInput(DEFAULT_WORKFLOW, subjectCommitment, "m92-other-source-set");
        (, uint256 otherSourceSetCommitmentId) = _registerM68FormulaAndSourceSet(otherInput, "m92-other-source-set");
        uint256 otherEvidenceId = _registerM68SourceSetEvidence(input.workflowKey, "m92-other-attestation-evidence");
        uint256 otherAttestationId = _registerM92SourceSetCompletenessAttestation(
            otherSourceSetCommitmentId, otherEvidenceId, "m92-other-attestation"
        );
        IStandingFormulaRegistry.StandingComputationStatementInput memory wrongAttestation =
            _m91ComputationStatementInput(
                sourceSetCommitmentId, otherAttestationId, input, evidenceId, "m92-wrong-attestation"
            );
        _assertM91CannotRegisterComputationStatement(wrongAttestation, "mismatched attestation registered statement");

        uint256 attestationId =
            _registerM92SourceSetCompletenessAttestation(sourceSetCommitmentId, evidenceId, "m92-statement-binding");
        IStandingFormulaRegistry.StandingComputationStatementInput memory validStatement = _m91ComputationStatementInput(
            sourceSetCommitmentId, attestationId, input, evidenceId, "m92-valid-statement"
        );
        uint256 statementId =
            standingFormulaRegistry.registerStandingComputationStatement(AVADataTypes.Role.Panel, validStatement);
        require(
            standingFormulaRegistry.getStandingComputationStatement(statementId).sourceSetCompletenessAttestationId
                == attestationId,
            "valid statement did not bind attestation"
        );
    }

    function testM92SourceSetCompletenessAttestationDoesNotCreateProofCredentialOrBenefits() public {
        bytes32 subjectCommitment = _subjectCommitmentForSecret(7);
        ZKStandingComputationRegistry.StandingProofInput memory input =
            _m65StandingProofInput(DEFAULT_WORKFLOW, subjectCommitment, "m92-record-only");
        (, uint256 sourceSetCommitmentId) = _registerM68FormulaAndSourceSet(input, "m92-record-only");
        uint256 evidenceId = _registerM68SourceSetEvidence(input.workflowKey, "m92-record-only-evidence");
        IStandingFormulaRegistry.SourceSetCompletenessAttestationInput memory attestationInput =
            _m92SourceSetCompletenessAttestationInput(sourceSetCommitmentId, evidenceId, "m92-record-only");
        uint256 nextStatementId = standingFormulaRegistry.nextStandingComputationStatementId();
        uint256 nextProofReceiptId = zkStandingComputationRegistry.nextStandingProofReceiptId();
        uint256 nextCredentialId = zkStandingCredentialRegistry.nextCredentialId();

        standingFormulaRegistry.registerSourceSetCompletenessAttestation(AVADataTypes.Role.Panel, attestationInput);

        require(
            standingFormulaRegistry.nextStandingComputationStatementId() == nextStatementId,
            "attestation wrote statement"
        );
        require(
            zkStandingComputationRegistry.nextStandingProofReceiptId() == nextProofReceiptId, "attestation wrote proof"
        );
        require(zkStandingCredentialRegistry.nextCredentialId() == nextCredentialId, "attestation issued credential");
        _assertNoSelector(address(standingFormulaRegistry), "mintReward(uint256)");
        _assertNoSelector(address(standingFormulaRegistry), "mintPriorityToken(uint256)");
        _assertNoSelector(address(standingFormulaRegistry), "executePayment(uint256)");
        _assertNoSelector(address(standingFormulaRegistry), "executeSanction(uint256)");
        _assertNoSelector(address(standingFormulaRegistry), "acceptManuscript(uint256)");
        _assertNoSelector(address(standingFormulaRegistry), "setManuscriptMerit(uint256,uint256)");
        _assertNoSelector(address(standingFormulaRegistry), "revealIdentity(uint256)");
        _assertNoSelector(address(standingFormulaRegistry), "decryptEvidence(uint256)");
    }

    function testM94ZKStandingCredentialRecordsComputationStatementBinding() public {
        bytes32 subjectCommitment = _subjectCommitmentForSecret(7);
        uint256 proofReceiptId = _createM66StandingProofReceipt(DEFAULT_WORKFLOW, subjectCommitment, "m94-binding");
        ZKStandingComputationRegistry.StandingProofReceipt memory proofReceipt =
            zkStandingComputationRegistry.getStandingProofReceipt(proofReceiptId);
        uint256 packageId = rulePackageRegistry.getRulePackage(PEER_REVIEW_APP_ID, DEFAULT_WORKFLOW).packageId;
        IZKStandingCredentialIssuer.ZKStandingCredentialInput memory input =
            _m66CredentialInput(proofReceiptId, packageId, subjectCommitment, "m94-binding");

        uint256 credentialId = zkStandingCredentialRegistry.issueCredential(AVADataTypes.Role.Panel, input);
        IZKStandingCredentialIssuer.ZKStandingCredentialRecord memory credential =
            zkStandingCredentialRegistry.getCredential(credentialId);

        require(proofReceipt.standingComputationStatementId != 0, "proof receipt missing statement");
        require(
            credential.standingComputationStatementId == proofReceipt.standingComputationStatementId,
            "credential statement binding missing"
        );
        require(
            zkStandingComputationRegistry.standingProofSupportsCredential(
                proofReceiptId,
                packageId,
                subjectCommitment,
                proofReceipt.vectorKey,
                proofReceipt.categoryHash,
                input.threshold
            ),
            "statement-bound proof did not support credential"
        );
    }
}

contract AVASkeletonStandingProof05ATest is AVASkeletonFixture {
    function testM95ExpiredStatementEvidenceStopsProofAndCredential() public {
        bytes32 subjectCommitment = _subjectCommitmentForSecret(7);
        uint256 proofReceiptId =
            _createM66StandingProofReceipt(DEFAULT_WORKFLOW, subjectCommitment, "m95-statement-evidence-expiry");
        ZKStandingComputationRegistry.StandingProofReceipt memory proofReceipt =
            zkStandingComputationRegistry.getStandingProofReceipt(proofReceiptId);
        IStandingFormulaRegistry.StandingComputationStatementRecord memory statement =
            standingFormulaRegistry.getStandingComputationStatement(proofReceipt.standingComputationStatementId);
        uint256 credentialId = zkStandingCredentialRegistry.issueCredential(
            AVADataTypes.Role.Panel,
            _m66CredentialInput(
                proofReceiptId, proofReceipt.packageId, subjectCommitment, "m95-statement-evidence-expiry"
            )
        );
        require(
            _m95ZkCredentialProves(credentialId, proofReceipt.packageId, subjectCommitment, 40),
            "credential not active before statement evidence expiry"
        );

        _expireM51EvidenceReceipt(statement.evidenceReceiptId, "m95-statement-evidence-expired");

        require(
            !standingFormulaRegistry.isStandingComputationStatementActive(statement.id),
            "expired statement evidence kept statement active"
        );
        require(
            !zkStandingComputationRegistry.standingProofSupportsCredential(
                proofReceiptId,
                proofReceipt.packageId,
                subjectCommitment,
                proofReceipt.vectorKey,
                proofReceipt.categoryHash,
                40
            ),
            "expired statement evidence kept proof active"
        );
        require(
            !_m95ZkCredentialProves(credentialId, proofReceipt.packageId, subjectCommitment, 40),
            "expired statement evidence credential still proved"
        );
    }

    function testM95ExpiredSourceSetEvidenceStopsProofAndCredential() public {
        bytes32 subjectCommitment = _subjectCommitmentForSecret(7);
        uint256 proofReceiptId =
            _createM66StandingProofReceipt(DEFAULT_WORKFLOW, subjectCommitment, "m95-source-evidence-expiry");
        ZKStandingComputationRegistry.StandingProofReceipt memory proofReceipt =
            zkStandingComputationRegistry.getStandingProofReceipt(proofReceiptId);
        IStandingFormulaRegistry.StandingComputationStatementRecord memory statement =
            standingFormulaRegistry.getStandingComputationStatement(proofReceipt.standingComputationStatementId);
        IStandingFormulaRegistry.SourceSetCommitmentRecord memory commitment =
            standingFormulaRegistry.getSourceSetCommitment(statement.sourceSetCommitmentId);
        uint256 credentialId = zkStandingCredentialRegistry.issueCredential(
            AVADataTypes.Role.Panel,
            _m66CredentialInput(proofReceiptId, proofReceipt.packageId, subjectCommitment, "m95-source-evidence-expiry")
        );
        require(
            _m95ZkCredentialProves(credentialId, proofReceipt.packageId, subjectCommitment, 40),
            "credential not active before source evidence expiry"
        );

        _expireM51EvidenceReceipt(commitment.evidenceReceiptId, "m95-source-set-evidence-expired");

        require(
            !standingFormulaRegistry.isStandingComputationStatementActive(statement.id),
            "expired source evidence kept statement active"
        );
        require(
            !zkStandingComputationRegistry.standingProofSupportsCredential(
                proofReceiptId,
                proofReceipt.packageId,
                subjectCommitment,
                proofReceipt.vectorKey,
                proofReceipt.categoryHash,
                40
            ),
            "expired source evidence kept proof active"
        );
        require(
            !_m95ZkCredentialProves(credentialId, proofReceipt.packageId, subjectCommitment, 40),
            "expired source evidence credential still proved"
        );
    }

    function testM95SupersededComputationStatementStopsOldCredentialProof() public {
        bytes32 subjectCommitment = _subjectCommitmentForSecret(7);
        uint256 proofReceiptId =
            _createM66StandingProofReceipt(DEFAULT_WORKFLOW, subjectCommitment, "m95-supersede-old");
        ZKStandingComputationRegistry.StandingProofReceipt memory proofReceipt =
            zkStandingComputationRegistry.getStandingProofReceipt(proofReceiptId);
        uint256 packageId = rulePackageRegistry.getRulePackage(PEER_REVIEW_APP_ID, DEFAULT_WORKFLOW).packageId;
        IZKStandingCredentialIssuer.ZKStandingCredentialInput memory credentialInput =
            _m66CredentialInput(proofReceiptId, packageId, subjectCommitment, "m95-supersede-old");
        uint256 credentialId = zkStandingCredentialRegistry.issueCredential(AVADataTypes.Role.Panel, credentialInput);
        require(
            _m95ZkCredentialProves(credentialId, packageId, subjectCommitment, 40), "old credential not active first"
        );

        ZKStandingComputationRegistry.StandingProofInput memory newProofInput =
            _m65StandingProofInput(DEFAULT_WORKFLOW, subjectCommitment, "m95-supersede-new");
        newProofInput.epoch = proofReceipt.epoch + 1;
        newProofInput.sourceRecordSetRoot = keccak256(
            abi.encode("m95-supersede-new", subjectCommitment, newProofInput.epoch, "source-record-set-root")
        );
        IStandingFormulaRegistry.StandingComputationStatementInput memory newStatementInput =
            _m95PreparedStatementInput(newProofInput, "m95-supersede-new");
        uint256 newStatementId = standingFormulaRegistry.supersedeStandingComputationStatement(
            AVADataTypes.Role.Panel, proofReceipt.standingComputationStatementId, newStatementInput
        );
        IStandingFormulaRegistry.StandingComputationStatementRecord memory oldStatement =
            standingFormulaRegistry.getStandingComputationStatement(proofReceipt.standingComputationStatementId);
        require(
            oldStatement.status == AVADataTypes.StandingComputationStatus.Superseded, "old statement not superseded"
        );
        require(oldStatement.supersededBy == newStatementId, "old statement successor missing");

        require(
            !zkStandingComputationRegistry.standingProofSupportsCredential(
                proofReceiptId, packageId, subjectCommitment, proofReceipt.vectorKey, proofReceipt.categoryHash, 40
            ),
            "superseded statement still supports proof"
        );
        require(!_m95ZkCredentialProves(credentialId, packageId, subjectCommitment, 40), "old credential still proved");
        IZKStandingCredentialIssuer.ZKStandingCredentialInput memory staleIssue =
            _m66CredentialInput(proofReceiptId, packageId, subjectCommitment, "m95-stale-issue");
        _assertM66CannotIssueCredential(staleIssue, "superseded statement issued new credential");

        _assertM95CanIssueFromReplacementStatement(newProofInput, newStatementId, packageId, subjectCommitment);
    }

    function testM95InvalidatedComputationStatementStopsOldCredentialProof() public {
        bytes32 subjectCommitment = _subjectCommitmentForSecret(7);
        uint256 proofReceiptId = _createM66StandingProofReceipt(DEFAULT_WORKFLOW, subjectCommitment, "m95-invalidate");
        ZKStandingComputationRegistry.StandingProofReceipt memory proofReceipt =
            zkStandingComputationRegistry.getStandingProofReceipt(proofReceiptId);
        uint256 packageId = rulePackageRegistry.getRulePackage(PEER_REVIEW_APP_ID, DEFAULT_WORKFLOW).packageId;
        IZKStandingCredentialIssuer.ZKStandingCredentialInput memory credentialInput =
            _m66CredentialInput(proofReceiptId, packageId, subjectCommitment, "m95-invalidate");
        uint256 credentialId = zkStandingCredentialRegistry.issueCredential(AVADataTypes.Role.Panel, credentialInput);
        require(_m95ZkCredentialProves(credentialId, packageId, subjectCommitment, 40), "credential not active first");

        uint256 invalidationEvidenceId = _registerM68SourceSetEvidence(DEFAULT_WORKFLOW, "m95-invalidation-evidence");
        standingFormulaRegistry.invalidateStandingComputationStatement(
            AVADataTypes.Role.Panel,
            proofReceipt.standingComputationStatementId,
            invalidationEvidenceId,
            keccak256("panel-authority"),
            "ipfs://m95-invalidation"
        );
        IStandingFormulaRegistry.StandingComputationStatementRecord memory statement =
            standingFormulaRegistry.getStandingComputationStatement(proofReceipt.standingComputationStatementId);
        require(statement.status == AVADataTypes.StandingComputationStatus.Invalidated, "statement not invalidated");
        require(
            statement.invalidatedByEvidenceReceiptId == invalidationEvidenceId,
            "statement invalidation evidence missing"
        );
        require(
            !zkStandingComputationRegistry.standingProofSupportsCredential(
                proofReceiptId, packageId, subjectCommitment, proofReceipt.vectorKey, proofReceipt.categoryHash, 40
            ),
            "invalidated statement still supports proof"
        );
        require(
            !_m95ZkCredentialProves(credentialId, packageId, subjectCommitment, 40),
            "invalidated credential still proved"
        );
        IZKStandingCredentialIssuer.ZKStandingCredentialInput memory staleIssue =
            _m66CredentialInput(proofReceiptId, packageId, subjectCommitment, "m95-invalidated-issue");
        _assertM66CannotIssueCredential(staleIssue, "invalidated statement issued new credential");
    }

    function testM68StandingFormulaRegistryRejectsUnauthorisedWrongPackageEvidenceAndWrongVerifier() public {
        bytes32 subjectCommitment = _subjectCommitmentForSecret(7);
        ZKStandingComputationRegistry.StandingProofInput memory input =
            _m65StandingProofInput(DEFAULT_WORKFLOW, subjectCommitment, "m68-boundary");
        IStandingFormulaRegistry.StandingFormulaInput memory formulaInput =
            _m68FormulaInput(input.workflowKey, input.vectorKey, input.computationRuleHash, "m68-unauthorised");
        try outsiderActor.registerStandingFormula(standingFormulaRegistry, AVADataTypes.Role.Panel, formulaInput) {
            revert("unauthorised standing formula registered");
        } catch {}

        IStandingFormulaRegistry.StandingFormulaInput memory wrongVerifierFormula =
            _m68FormulaInput(input.workflowKey, input.vectorKey, input.computationRuleHash, "m68-wrong-verifier");
        wrongVerifierFormula.verifier = address(new SchnorrDisclosureProofVerifier());
        uint256 wrongVerifierFormulaId =
            standingFormulaRegistry.registerStandingFormula(AVADataTypes.Role.Panel, wrongVerifierFormula);
        uint256 evidenceId = _registerM68SourceSetEvidence(input.workflowKey, "m68-wrong-verifier");
        _registerM68SourceSetCommitment(wrongVerifierFormulaId, input, evidenceId, "m68-wrong-verifier");
        bytes32 contextHash = zkStandingComputationRegistry.computeStandingComputationContextHash(input);
        _assertM65CannotRegisterStandingProof(
            input, _makeSchnorrProof(contextHash, 7, 11), "standing proof accepted formula with wrong verifier"
        );

        bytes32 workflowKey = keccak256("m68-wrong-package-evidence");
        _ensureWorkflowPackage(workflowKey);
        ZKStandingComputationRegistry.StandingProofInput memory oldPackageInput =
            _m65StandingProofInput(workflowKey, subjectCommitment, "m68-old-package-source");
        uint256 oldFormulaId = _registerM68Formula(oldPackageInput, "m68-old-package-source");
        uint256 oldPackageId = rulePackageRegistry.getRulePackage(PEER_REVIEW_APP_ID, workflowKey).packageId;
        _registerM421ExecutionWorkflow(workflowKey, "ipfs://m68-new-package");
        require(rulePackageRegistry.getRulePackage(PEER_REVIEW_APP_ID, workflowKey).packageId != oldPackageId, "package did not change");
        uint256 newPackageEvidence = _registerM68SourceSetEvidence(workflowKey, "m68-new-package-evidence");
        try standingFormulaRegistry.registerSourceSetCommitment(
            AVADataTypes.Role.Panel,
            _m68SourceSetCommitmentInput(oldFormulaId, oldPackageInput, newPackageEvidence, "m68-wrong-package")
        ) {
            revert("wrong package evidence accepted for old standing formula");
        } catch {}
    }
}

contract AVASkeletonStandingProof05BTest is AVASkeletonFixture {
    function testM68StandingRegistryRejectsNewPackageEvidenceForOldRecognisedState() public {
        bytes32 workflowKey = keccak256("m68-standing-registry-package-evidence");
        _ensureWorkflowPackage(workflowKey);
        uint256 oldEvidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            workflowKey,
            keccak256("m68-old-standing-evidence"),
            "ipfs://m68-old-standing-evidence",
            "m68-standing-evidence",
            0
        );
        uint256 recognisedStateId = _registerRecognisedStateForWorkflowStatus(
            workflowKey, AVADataTypes.RecognisedStateStatus.Vested, oldEvidenceId, "m68-old-standing-state"
        );
        uint256 oldPackageId = stateMachine.getRecognisedState(recognisedStateId).packageId;
        uint256 computationId = standingRegistry.recordStandingComputationReadiness(
            AVADataTypes.Role.Panel,
            _m68StandingComputationContext(recognisedStateId, oldEvidenceId, "m68-old-standing-computation", 1),
            "ipfs://m68-old-standing-computation"
        );

        _registerM421ExecutionWorkflow(workflowKey, "ipfs://m68-standing-registry-new-package");
        uint256 newEvidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            workflowKey,
            keccak256("m68-new-standing-evidence"),
            "ipfs://m68-new-standing-evidence",
            "m68-standing-evidence",
            0
        );
        require(evidenceRegistry.getEvidenceReceipt(newEvidenceId).packageId != oldPackageId, "package did not change");

        _assertM68StandingUpdateRejectsWrongPackageEvidence(
            recognisedStateId, newEvidenceId, "standing update accepted new-package evidence"
        );
        _assertM68StandingComputationRejectsWrongPackageEvidence(
            recognisedStateId, newEvidenceId, "standing computation accepted new-package evidence"
        );
        _assertM68StandingInvalidationRejectsWrongPackageEvidence(
            computationId, newEvidenceId, "standing invalidation accepted new-package evidence"
        );
    }

    function testM68PackageEvidenceCannotCrossStateChallengeAllocationOrConsequenceAfterReregistration() public {
        bytes32 workflowKey = keccak256("m68-substrate-package-evidence");
        _ensureWorkflowPackage(workflowKey);
        uint256 oldEvidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            workflowKey,
            keccak256("m68-substrate-old-evidence"),
            "ipfs://m68-substrate-old-evidence",
            "m68-substrate-evidence",
            0
        );
        uint256 vestedStateId = _registerRecognisedStateForWorkflowStatus(
            workflowKey, AVADataTypes.RecognisedStateStatus.Vested, oldEvidenceId, "m68-substrate-old-vested"
        );
        uint256 challengeableStateId = _registerRecognisedStateForWorkflowStatus(
            workflowKey,
            AVADataTypes.RecognisedStateStatus.Challengeable,
            oldEvidenceId,
            "m68-substrate-old-challengeable"
        );
        uint256 oldChallengeEvidenceId = challengerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Challenger,
            workflowKey,
            keccak256("m68-substrate-old-challenge-evidence"),
            "ipfs://m68-substrate-old-challenge-evidence",
            "m68-substrate-challenge-evidence",
            0
        );

        _registerM421ExecutionWorkflow(workflowKey, "ipfs://m68-substrate-new-package");
        uint256 newEvidenceId = reviewerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Reviewer,
            workflowKey,
            keccak256("m68-substrate-new-evidence"),
            "ipfs://m68-substrate-new-evidence",
            "m68-substrate-evidence",
            0
        );
        uint256 newChallengeEvidenceId = challengerActor.registerEvidenceReceipt(
            evidenceRegistry,
            AVADataTypes.Role.Challenger,
            workflowKey,
            keccak256("m68-substrate-new-challenge-evidence"),
            "ipfs://m68-substrate-new-challenge-evidence",
            "m68-substrate-challenge-evidence",
            0
        );

        _assertM68StateRejectsWrongPackageEvidence(
            workflowKey, oldEvidenceId, "old-package evidence entered new-package recognised state"
        );
        _assertM68ChallengeRejectsWrongPackageEvidence(
            workflowKey,
            challengeableStateId,
            oldChallengeEvidenceId,
            "old-package evidence entered new challenge package"
        );
        _assertM68ChallengeRejectsWrongPackageEvidence(
            workflowKey,
            challengeableStateId,
            newChallengeEvidenceId,
            "incompatible new challenge package entered old target package"
        );
        _assertM68AllocationRejectsWrongPackageEvidence(
            vestedStateId, newEvidenceId, "new-package evidence entered old-package allocation"
        );
        _assertM68ConsequenceRejectsWrongPackageEvidence(
            vestedStateId, newEvidenceId, "new-package evidence entered old-package consequence"
        );
        _assertM68ExternalOperationRejectsWrongPackageEvidence(
            workflowKey, vestedStateId, newEvidenceId, "new-package evidence entered old-package external operation"
        );
    }

    function testM66ZKStandingCredentialIssuesFromProofReceiptWithoutAccountOwner() public {
        bytes32 subjectCommitment = _subjectCommitmentForSecret(7);
        uint256 proofReceiptId = _createM66StandingProofReceipt(DEFAULT_WORKFLOW, subjectCommitment, "m66-issue");
        uint256 packageId = rulePackageRegistry.getRulePackage(PEER_REVIEW_APP_ID, DEFAULT_WORKFLOW).packageId;
        IZKStandingCredentialIssuer.ZKStandingCredentialInput memory input =
            _m66CredentialInput(proofReceiptId, packageId, subjectCommitment, "m66-issue");

        uint256 credentialId = zkStandingCredentialRegistry.issueCredential(AVADataTypes.Role.Panel, input);
        IZKStandingCredentialIssuer.ZKStandingCredentialRecord memory credential =
            zkStandingCredentialRegistry.getCredential(credentialId);

        require(credential.standingProofReceiptId == proofReceiptId, "proof receipt missing");
        require(credential.packageId == packageId, "credential package missing");
        require(credential.subjectCommitment == subjectCommitment, "credential subject commitment missing");
        require(credential.credentialCommitment == input.credentialCommitment, "credential commitment missing");
        require(credential.credentialNullifierHash == input.credentialNullifierHash, "credential nullifier missing");
        require(credential.vectorKey == input.vectorKey, "credential vector missing");
        require(credential.categoryHash == input.categoryHash, "credential category missing");
        require(credential.status == AVADataTypes.StandingCredentialStatus.Active, "credential not active");
        require(
            zkStandingCredentialRegistry.credentialProves(
                credentialId, packageId, subjectCommitment, input.vectorKey, input.categoryHash, 40
            ),
            "credential did not prove threshold"
        );

        _assertNoSelector(address(zkStandingCredentialRegistry), "ownerOf(uint256)");
        _assertNoSelector(address(zkStandingCredentialRegistry), "balanceOf(address)");
        _assertNoSelector(address(zkStandingCredentialRegistry), "transferFrom(address,address,uint256)");
        _assertNoSelector(address(zkStandingCredentialRegistry), "approve(address,uint256)");
        _assertNoSelector(address(zkStandingCredentialRegistry), "setApprovalForAll(address,bool)");
        _assertNoSelector(address(zkStandingCredentialRegistry), "mintReward(uint256)");
        _assertNoSelector(address(zkStandingCredentialRegistry), "mintPriorityToken(uint256)");
        _assertNoSelector(address(zkStandingCredentialRegistry), "acceptManuscript(uint256)");
        _assertNoSelector(address(zkStandingCredentialRegistry), "setManuscriptMerit(uint256,uint256)");
        _assertNoSelector(address(zkStandingCredentialRegistry), "revealIdentity(uint256)");
        _assertNoSelector(address(zkStandingCredentialRegistry), "revealEvidence(uint256)");
        _assertNoSelector(address(zkStandingCredentialRegistry), "decryptEvidence(uint256)");
        _assertNoSelector(address(zkStandingCredentialRegistry), "isCredentialActive(uint256)");
    }
}

contract AVASkeletonStandingProof06ATest is AVASkeletonFixture {
    function testM66ZKStandingCredentialRejectsWrongProofBindings() public {
        bytes32 subjectCommitment = _subjectCommitmentForSecret(7);
        uint256 proofReceiptId = _createM66StandingProofReceipt(DEFAULT_WORKFLOW, subjectCommitment, "m66-binding");
        uint256 packageId = rulePackageRegistry.getRulePackage(PEER_REVIEW_APP_ID, DEFAULT_WORKFLOW).packageId;
        IZKStandingCredentialIssuer.ZKStandingCredentialInput memory input =
            _m66CredentialInput(proofReceiptId, packageId, subjectCommitment, "m66-binding");

        IZKStandingCredentialIssuer.ZKStandingCredentialInput memory unknownReceipt = input;
        unknownReceipt.standingProofReceiptId = proofReceiptId + 1000;
        _assertM66CannotIssueCredential(unknownReceipt, "unknown proof receipt issued credential");

        IZKStandingCredentialIssuer.ZKStandingCredentialInput memory wrongPackage = input;
        wrongPackage.packageId = packageId + 1;
        _assertM66CannotIssueCredential(wrongPackage, "wrong package issued credential");

        IZKStandingCredentialIssuer.ZKStandingCredentialInput memory wrongSubject = input;
        wrongSubject.subjectCommitment = _subjectCommitmentForSecret(9);
        _assertM66CannotIssueCredential(wrongSubject, "wrong subject commitment issued credential");

        IZKStandingCredentialIssuer.ZKStandingCredentialInput memory wrongVector = input;
        wrongVector.vectorKey = keccak256("m66-wrong-vector");
        _assertM66CannotIssueCredential(wrongVector, "wrong vector issued credential");

        IZKStandingCredentialIssuer.ZKStandingCredentialInput memory wrongCategory = input;
        wrongCategory.categoryHash = keccak256("m66-wrong-category");
        _assertM66CannotIssueCredential(wrongCategory, "wrong category issued credential");

        IZKStandingCredentialIssuer.ZKStandingCredentialInput memory badThreshold = input;
        badThreshold.threshold = 43;
        _assertM66CannotIssueCredential(badThreshold, "threshold above proof value issued credential");

        IZKStandingCredentialIssuer.ZKStandingCredentialInput memory wrongEpoch = input;
        wrongEpoch.epoch = input.epoch + 1;
        _assertM66CannotIssueCredential(wrongEpoch, "wrong epoch issued credential");

        IZKStandingCredentialIssuer.ZKStandingCredentialInput memory wrongSourceRoot = input;
        wrongSourceRoot.sourceRecordSetRoot = keccak256("m66-wrong-source-root");
        _assertM66CannotIssueCredential(wrongSourceRoot, "wrong source root issued credential");

        IZKStandingCredentialIssuer.ZKStandingCredentialInput memory wrongRule = input;
        wrongRule.computationRuleHash = keccak256("m66-wrong-rule");
        _assertM66CannotIssueCredential(wrongRule, "wrong computation rule issued credential");
    }

    function testM66ZKStandingCredentialRejectsDuplicateCommitmentAndNullifier() public {
        bytes32 subjectCommitment = _subjectCommitmentForSecret(7);
        uint256 proofReceiptId = _createM66StandingProofReceipt(DEFAULT_WORKFLOW, subjectCommitment, "m66-duplicate");
        uint256 packageId = rulePackageRegistry.getRulePackage(PEER_REVIEW_APP_ID, DEFAULT_WORKFLOW).packageId;
        IZKStandingCredentialIssuer.ZKStandingCredentialInput memory input =
            _m66CredentialInput(proofReceiptId, packageId, subjectCommitment, "m66-duplicate");

        uint256 credentialId = zkStandingCredentialRegistry.issueCredential(AVADataTypes.Role.Panel, input);
        require(credentialId != 0, "valid credential not issued");
        _assertM66CannotIssueCredential(input, "duplicate credential nullifier issued credential");

        IZKStandingCredentialIssuer.ZKStandingCredentialInput memory duplicateCommitment =
            _m66CredentialInput(proofReceiptId, packageId, subjectCommitment, "m66-duplicate-commitment");
        duplicateCommitment.credentialCommitment = input.credentialCommitment;
        _assertM66CannotIssueCredential(duplicateCommitment, "duplicate credential commitment issued credential");
    }

    function testM66ZKStandingCredentialProofUseRejectsNullifierReplay() public {
        bytes32 subjectCommitment = _subjectCommitmentForSecret(7);
        string memory seed = "m66-use-active";
        uint256 activeCredentialId =
            _issueM66ZKStandingCredential(DEFAULT_WORKFLOW, subjectCommitment, seed, 1, block.timestamp + 7 days);
        IZKStandingCredentialIssuer.ZKStandingCredentialRecord memory credential =
            zkStandingCredentialRegistry.getCredential(activeCredentialId);
        bytes32 targetContext = keccak256("m66-target-context");

        uint256 useRecordId =
            _recordM66CredentialUseWithSecret(activeCredentialId, 40, targetContext, _m66CredentialSecret(seed), 19);
        IZKStandingCredentialIssuer.ZKStandingCredentialUseRecord memory useRecord =
            zkStandingCredentialRegistry.getCredentialUseRecord(useRecordId);
        require(useRecord.credentialId == activeCredentialId, "credential use target missing");
        require(useRecord.targetContextHash == targetContext, "target context missing");
        require(useRecord.vectorKey == credential.vectorKey, "use vector missing");
        _assertM66CannotRecordCredentialUseWithSecret(
            activeCredentialId, 40, targetContext, _m66CredentialSecret(seed), "proof-use nullifier replay accepted"
        );
    }

    function testM66CopiedZKStandingCredentialUseCannotFrontRunBeneficiary() public {
        bytes32 subjectCommitment = _subjectCommitmentForSecret(7);
        string memory seed = "m66-front-run";
        uint256 credentialId = _issueM66ZKStandingCredential(
            DEFAULT_WORKFLOW, subjectCommitment, seed, 1, block.timestamp + 7 days
        );
        bytes32 targetContext = keccak256("m66-front-run-target");
        IZKStandingCredentialIssuer.ZKStandingCredentialUseInput memory input =
            _m66CredentialUseInput(credentialId, 40, targetContext);
        bytes32 useContext = _m66CredentialUseContext(input);
        IZKProofVerifier.SchnorrProof memory proof =
            _makeSchnorrProof(useContext, _m66CredentialSecret(seed), 73);

        vm.prank(address(outsiderActor));
        try zkStandingCredentialRegistry.recordCredentialUse(input, proof) {
            revert("copied standing credential use front-ran beneficiary");
        } catch {}

        uint256 useRecordId = zkStandingCredentialRegistry.recordCredentialUse(input, proof);
        require(
            zkStandingCredentialRegistry.getCredentialUseRecord(useRecordId).usedBy == address(this),
            "beneficiary use was not recorded"
        );
    }

    function testStandingCredentialValidityIsBounded() public {
        uint256 computationId = _createM422StandingComputationRecord("bounded-standing-credential", 42);
        try standingCredentialRegistry.issueCredential(
            AVADataTypes.Role.Panel,
            _m422CredentialInputForComputation(
                computationId, block.timestamp + 365 days + 1, "ipfs://overlong-standing-credential"
            )
        ) {
            revert("overlong standing credential was issued");
        } catch {}
    }

    function testZKStandingCredentialValidityIsBounded() public {
        bytes32 subjectCommitment = _subjectCommitmentForSecret(7);
        uint256 proofReceiptId =
            _createM66StandingProofReceipt(DEFAULT_WORKFLOW, subjectCommitment, "bounded-zk-credential");
        IZKStandingCredentialIssuer.ZKStandingCredentialInput memory input = _m66CredentialInput(
            proofReceiptId,
            rulePackageRegistry.getRulePackage(PEER_REVIEW_APP_ID, DEFAULT_WORKFLOW).packageId,
            subjectCommitment,
            "bounded-zk-credential"
        );
        input.expiresAt = block.timestamp + 365 days + 1;
        _assertM66CannotIssueCredential(input, "overlong standing ZK credential was issued");
    }

    function testZKCredentialUseContextChangesAcrossChainId() public {
        uint256 originalChainId = block.chainid;
        bytes32 subjectCommitment = _subjectCommitmentForSecret(7);
        uint256 credentialId = _issueM66ZKStandingCredential(
            DEFAULT_WORKFLOW, subjectCommitment, "m66-chain-domain", 1, block.timestamp + 7 days
        );
        IZKStandingCredentialIssuer.ZKStandingCredentialUseInput memory useInput =
            _m66CredentialUseInput(credentialId, 40, keccak256("m66-chain-domain-target"));
        bytes32 credentialContextBefore = _m66CredentialUseContext(useInput);
        vm.chainId(originalChainId + 1);
        require(_m66CredentialUseContext(useInput) != credentialContextBefore, "credential context crossed chain");
        vm.chainId(originalChainId);
    }

    function testZKStandingComputationContextChangesAcrossChainId() public {
        uint256 originalChainId = block.chainid;
        ZKStandingComputationRegistry.StandingProofInput memory standingInput = _m65StandingProofInput(
            DEFAULT_WORKFLOW, _subjectCommitmentForSecret(7), "m66-chain-standing"
        );
        (standingInput,,,) = _bindM93StandingProofInput(standingInput, "m66-chain-standing");
        bytes32 standingContextBefore =
            zkStandingComputationRegistry.computeStandingComputationContextHash(standingInput);
        vm.chainId(originalChainId + 1);
        require(
            zkStandingComputationRegistry.computeStandingComputationContextHash(standingInput)
                != standingContextBefore,
            "standing computation context crossed chain"
        );
        vm.chainId(originalChainId);
    }

    function testZKDisclosureContextChangesAcrossChainId() public {
        uint256 originalChainId = block.chainid;
        uint256 policyId = _registerDisclosurePolicy("m66-chain-disclosure");
        bytes32 subjectCommitment = _subjectCommitmentForSecret(7);
        bytes32 disclosureContextBefore = _m66DisclosureDomainContext(policyId, subjectCommitment);
        vm.chainId(originalChainId + 1);
        require(
            _m66DisclosureDomainContext(policyId, subjectCommitment) != disclosureContextBefore,
            "disclosure context crossed chain"
        );
        vm.chainId(originalChainId);
    }

    function _m66DisclosureDomainContext(uint256 policyId, bytes32 subjectCommitment)
        private
        view
        returns (bytes32)
    {
        return zkProofRegistry.computeDisclosureContextHash(
            PEER_REVIEW_APP_ID,
            DEFAULT_WORKFLOW,
            AVADataTypes.AVAStage.Verification,
            AVADataTypes.Action.RegisterEvidence,
            keccak256("m66-chain-disclosure-object"),
            AVADataTypes.Role.Panel,
            policyId,
            subjectCommitment
        );
    }
}

contract AVASkeletonStandingProof06BTest is AVASkeletonFixture {
    function testM66ZKStandingCredentialUseRequiresCredentialHolderProof() public {
        bytes32 subjectCommitment = _subjectCommitmentForSecret(7);
        string memory seed = "m66-use-holder-proof";
        uint256 credentialId =
            _issueM66ZKStandingCredential(DEFAULT_WORKFLOW, subjectCommitment, seed, 1, block.timestamp + 7 days);
        bytes32 targetContext = keccak256("m66-holder-proof-target");

        _assertM66CannotRecordCredentialUseWithSecret(
            credentialId,
            40,
            targetContext,
            _m66CredentialSecret("m66-wrong-holder"),
            "credential use accepted wrong holder proof"
        );

        uint256 useRecordId =
            _recordM66CredentialUseWithSecret(credentialId, 40, targetContext, _m66CredentialSecret(seed), 31);
        require(
            zkStandingCredentialRegistry.getCredentialUseRecord(useRecordId).credentialId == credentialId, "use missing"
        );
    }

    function testM66RevokedCredentialCannotProve() public {
        bytes32 subjectCommitment = _subjectCommitmentForSecret(7);
        uint256 packageId = rulePackageRegistry.getRulePackage(PEER_REVIEW_APP_ID, DEFAULT_WORKFLOW).packageId;
        uint256 revokedId = _issueM66ZKStandingCredential(
            DEFAULT_WORKFLOW, subjectCommitment, "m66-revoke", 1, block.timestamp + 7 days
        );
        IZKStandingCredentialIssuer.ZKStandingCredentialRecord memory credential =
            zkStandingCredentialRegistry.getCredential(revokedId);
        zkStandingCredentialRegistry.revokeCredential(
            AVADataTypes.Role.Panel, revokedId, subjectCommitment, keccak256("panel-authority"), "ipfs://m66-revoke"
        );
        credential = zkStandingCredentialRegistry.getCredential(revokedId);
        require(credential.statusReference == keccak256(bytes("ipfs://m66-revoke")), "revoke reference missing");
        require(keccak256(bytes(credential.statusURI)) == keccak256(bytes("ipfs://m66-revoke")), "revoke uri missing");
        require(
            credential.status == AVADataTypes.StandingCredentialStatus.Revoked,
            "revoked credential carrier status missing"
        );
        require(
            !zkStandingCredentialRegistry.credentialProves(
                revokedId, packageId, subjectCommitment, credential.vectorKey, credential.categoryHash, 40
            ),
            "revoked credential proved"
        );
    }

    function testM66SupersededCredentialCannotProve() public {
        bytes32 subjectCommitment = _subjectCommitmentForSecret(7);
        uint256 packageId = rulePackageRegistry.getRulePackage(PEER_REVIEW_APP_ID, DEFAULT_WORKFLOW).packageId;
        uint256 supersededId =
            _issueM66ZKStandingCredential(DEFAULT_WORKFLOW, subjectCommitment, "m66-old", 1, block.timestamp + 7 days);
        uint256 supersedingProofId = _createM66StandingProofReceipt(DEFAULT_WORKFLOW, subjectCommitment, "m66-new", 2);
        IZKStandingCredentialIssuer.ZKStandingCredentialInput memory supersedingInput =
            _m66CredentialInput(supersedingProofId, packageId, subjectCommitment, "m66-new");
        uint256 newCredentialId =
            zkStandingCredentialRegistry.supersedeCredential(AVADataTypes.Role.Panel, supersededId, supersedingInput);
        require(newCredentialId != 0, "superseding credential missing");
        IZKStandingCredentialIssuer.ZKStandingCredentialRecord memory oldCredential =
            zkStandingCredentialRegistry.getCredential(supersededId);
        require(oldCredential.statusReference == bytes32(newCredentialId), "supersession reference missing");
        require(
            oldCredential.status == AVADataTypes.StandingCredentialStatus.Superseded,
            "superseded credential carrier status missing"
        );
    }
}

contract AVASkeletonStandingProof07ATest is AVASkeletonFixture {
    function testM66SuspendedAndExpiredCredentialsCannotProve() public {
        bytes32 subjectCommitment = _subjectCommitmentForSecret(7);
        Actor zkSubjectActor = new Actor();
        roleRegistry.assignRole(
            address(zkSubjectActor), AVADataTypes.Role.Challenger, subjectCommitment, "ipfs://m66-zk-subject"
        );
        _registerM421ExecutionWorkflow(DEFAULT_WORKFLOW, "ipfs://m66-source-bound-suspension-workflow");
        uint256 suspendedId = _issueM66ZKStandingCredential(
            DEFAULT_WORKFLOW, subjectCommitment, "m66-suspend", 1, block.timestamp + 7 days
        );
        _assertNoSelector(
            address(zkStandingCredentialRegistry),
            "suspendCredential(uint8,uint256,uint256,bytes32,bytes32,bytes32,string)"
        );
        require(
            zkStandingCredentialRegistry.getCredential(suspendedId).status
                == AVADataTypes.StandingCredentialStatus.Active,
            "credential inactive before source suspension"
        );

        MockERC20 token = _m421FundedToken(20);
        uint256 sourceId = _createM69RewardSource(
            DEFAULT_WORKFLOW,
            subjectCommitment,
            "m66-source-bound-suspension",
            token,
            5,
            AVADataTypes.ValueExecutionMode.Claim
        );
        uint256 settlementId = valueSettlementExecutor.settleTokenTransfer(
            AVADataTypes.Role.ProtocolExecutor,
            AVADataTypes.ExecutionSourceType.AllocationRecord,
            sourceId,
            keccak256("executor-authority"),
            "ipfs://m66-source-bound-settlement"
        );
        uint256 suspensionRecordId = zkStandingCredentialRegistry.recordSettlementBoundSuspension(
            AVADataTypes.Role.Panel,
            suspendedId,
            AVADataTypes.StandingRelevantSettlementKind.RewardExecution,
            AVADataTypes.ExecutionSourceType.AllocationRecord,
            sourceId,
            settlementId,
            keccak256("panel-authority"),
            "ipfs://m66-source-bound-suspension"
        );
        IZKStandingCredentialIssuer.ZKStandingCredentialRecord memory suspendedCredential =
            zkStandingCredentialRegistry.getCredential(suspendedId);
        require(suspendedCredential.statusReference == bytes32(suspensionRecordId), "suspension reference missing");
        require(
            keccak256(bytes(suspendedCredential.statusURI)) == keccak256(bytes("ipfs://m66-source-bound-suspension")),
            "suspension uri missing"
        );
        require(
            suspendedCredential.status == AVADataTypes.StandingCredentialStatus.Suspended,
            "suspended credential carrier status missing"
        );

        uint256 expiringId =
            _issueM66ZKStandingCredential(DEFAULT_WORKFLOW, subjectCommitment, "m66-expire", 2, block.timestamp + 1);
        IZKStandingCredentialIssuer.ZKStandingCredentialRecord memory expiringCredential =
            zkStandingCredentialRegistry.getCredential(expiringId);
        vm.warp(block.timestamp + 2);
        require(block.timestamp >= expiringCredential.expiresAt, "credential did not expire");
        require(
            !zkStandingCredentialRegistry.credentialProves(
                expiringId,
                expiringCredential.packageId,
                subjectCommitment,
                expiringCredential.vectorKey,
                expiringCredential.categoryHash,
                40
            ),
            "expired credential proved"
        );
    }

    function testM66UnauthorisedCallerCannotManageZKStandingCredential() public {
        bytes32 subjectCommitment = _subjectCommitmentForSecret(7);
        uint256 packageId = rulePackageRegistry.getRulePackage(PEER_REVIEW_APP_ID, DEFAULT_WORKFLOW).packageId;
        uint256 proofReceiptId = _createM66StandingProofReceipt(DEFAULT_WORKFLOW, subjectCommitment, "m66-unauthorised");
        IZKStandingCredentialIssuer.ZKStandingCredentialInput memory input =
            _m66CredentialInput(proofReceiptId, packageId, subjectCommitment, "m66-unauthorised");

        try outsiderActor.issueZKStandingCredential(zkStandingCredentialRegistry, AVADataTypes.Role.Panel, input) {
            revert("unauthorised actor issued zk standing credential");
        } catch {}

        uint256 credentialId = zkStandingCredentialRegistry.issueCredential(AVADataTypes.Role.Panel, input);
        try outsiderActor.revokeZKStandingCredential(
            zkStandingCredentialRegistry,
            AVADataTypes.Role.Panel,
            credentialId,
            subjectCommitment,
            keccak256("panel-authority"),
            "ipfs://m66-bad-revoke"
        ) {
            revert("unauthorised actor revoked zk standing credential");
        } catch {}

        uint256 replacementProofId =
            _createM66StandingProofReceipt(DEFAULT_WORKFLOW, subjectCommitment, "m66-unauthorised-replacement", 2);
        IZKStandingCredentialIssuer.ZKStandingCredentialInput memory replacement =
            _m66CredentialInput(replacementProofId, packageId, subjectCommitment, "m66-unauthorised-replacement");
        try outsiderActor.supersedeZKStandingCredential(
            zkStandingCredentialRegistry, AVADataTypes.Role.Panel, credentialId, replacement
        ) {
            revert("unauthorised actor superseded zk standing credential");
        } catch {}

        _assertNoSelector(
            address(zkStandingCredentialRegistry),
            "suspendCredential(uint8,uint256,uint256,bytes32,bytes32,bytes32,string)"
        );
        require(
            zkStandingCredentialRegistry.getCredential(credentialId).status
                == AVADataTypes.StandingCredentialStatus.Active,
            "unauthorised action changed credential"
        );
    }

    function testM69ZKStandingCredentialSettlementBoundSuspensionRequiresRealSourcePackageAndSubject() public {
        bytes32 workflowKey = keccak256("m69-zk-settlement-workflow");
        _registerM421ExecutionWorkflow(workflowKey, "ipfs://m69-zk-settlement-workflow");
        bytes32 subjectCommitment = _subjectCommitmentForSecret(7);
        Actor zkSubjectActor = new Actor();
        roleRegistry.assignRole(
            address(zkSubjectActor), AVADataTypes.Role.Challenger, subjectCommitment, "ipfs://m69-zk-subject"
        );
        uint256 credentialId = _issueM66ZKStandingCredential(
            workflowKey, subjectCommitment, "m69-zk-settlement", 1, block.timestamp + 7 days
        );

        MockERC20 token = _m421FundedToken(100);
        uint256 sourceId = _createM69RewardSource(
            workflowKey, subjectCommitment, "m69-zk-bound-source", token, 9, AVADataTypes.ValueExecutionMode.Claim
        );
        uint256 settlementId = valueSettlementExecutor.settleTokenTransfer(
            AVADataTypes.Role.ProtocolExecutor,
            AVADataTypes.ExecutionSourceType.AllocationRecord,
            sourceId,
            keccak256("executor-authority"),
            "ipfs://m69-zk-bound-settlement"
        );

        _assertM69SettlementSuspensionRejectsInvalidBindings(
            credentialId, workflowKey, subjectCommitment, token, sourceId, settlementId
        );

        uint256 suspensionId = zkStandingCredentialRegistry.recordSettlementBoundSuspension(
            AVADataTypes.Role.Panel,
            credentialId,
            AVADataTypes.StandingRelevantSettlementKind.RewardExecution,
            AVADataTypes.ExecutionSourceType.AllocationRecord,
            sourceId,
            settlementId,
            keccak256("panel-authority"),
            "ipfs://m69-zk-valid-settlement-suspension"
        );
        IZKStandingCredentialIssuer.ZKStandingCredentialSuspensionRecord memory suspension =
            zkStandingCredentialRegistry.getCredentialSuspensionRecord(suspensionId);
        require(
            suspension.sourceKind
                == IZKStandingCredentialIssuer.ZKStandingCredentialSuspensionSourceKind.ValueSettlement,
            "wrong suspension source kind"
        );
        require(suspension.credentialId == credentialId, "credential not recorded");
        require(suspension.sourceRecordId == sourceId, "source not recorded");
        require(suspension.settlementId == settlementId, "settlement not recorded");
        require(suspension.subjectCommitment == subjectCommitment, "subject not recorded");
        require(
            zkStandingCredentialRegistry.getCredential(credentialId).status
                == AVADataTypes.StandingCredentialStatus.Suspended,
            "valid source-bound suspension not active"
        );
    }
}

contract AVASkeletonStandingProof07BTest is AVASkeletonFixture {
    function testM69ZKStandingCredentialChallengeBoundSuspensionRejectsGoodFaithAndAcceptsMaliciousRecord() public {
        bytes32 subjectCommitment = _subjectCommitmentForSecret(7);
        Actor zkChallengerActor = new Actor();
        roleRegistry.assignRole(
            address(zkChallengerActor), AVADataTypes.Role.Challenger, subjectCommitment, "ipfs://m69-zk-challenger"
        );
        uint256 credentialId = _issueM66ZKStandingCredential(
            DEFAULT_WORKFLOW, subjectCommitment, "m69-zk-challenge", 1, block.timestamp + 7 days
        );

        uint256 goodFaithTransitionId = _createM69ChallengeResolutionTransition(
            zkChallengerActor, subjectCommitment, "m69-good-faith", AVADataTypes.ChallengeOutcome.RejectedGoodFaith
        );
        _assertM69InvalidChallengeBoundSuspensionDoesNotDisable(
            credentialId, goodFaithTransitionId, "good-faith rejected challenge suspended zk credential"
        );

        uint256 maliciousTransitionId = _createM69ChallengeResolutionTransition(
            zkChallengerActor, subjectCommitment, "m69-malicious", AVADataTypes.ChallengeOutcome.MaliciousOrFabricated
        );
        uint256 nextConsequenceId = consequenceExecutor.nextConsequenceId();
        uint256 nextStandingUpdateId = standingRegistry.nextStandingUpdateId();
        uint256 suspensionId = zkStandingCredentialRegistry.recordChallengeTransitionBoundSuspension(
            AVADataTypes.Role.Panel,
            credentialId,
            maliciousTransitionId,
            keccak256("panel-authority"),
            "ipfs://m69-malicious-source-bound-suspension"
        );
        IZKStandingCredentialIssuer.ZKStandingCredentialSuspensionRecord memory suspension =
            zkStandingCredentialRegistry.getCredentialSuspensionRecord(suspensionId);
        require(
            suspension.sourceKind
                == IZKStandingCredentialIssuer.ZKStandingCredentialSuspensionSourceKind.ChallengeTransition,
            "wrong challenge suspension source kind"
        );
        require(suspension.challengeTransitionId == maliciousTransitionId, "challenge transition not recorded");
        require(
            suspension.challengeOutcome == AVADataTypes.ChallengeOutcome.MaliciousOrFabricated,
            "malicious outcome missing"
        );
        require(
            zkStandingCredentialRegistry.getCredential(credentialId).status
                == AVADataTypes.StandingCredentialStatus.Suspended,
            "malicious suspension not applied"
        );
        require(consequenceExecutor.nextConsequenceId() == nextConsequenceId, "challenge suspension executed sanction");
        require(
            standingRegistry.nextStandingUpdateId() == nextStandingUpdateId, "challenge suspension updated standing"
        );
        _assertNoSelector(address(zkStandingCredentialRegistry), "executeSanction(uint256)");
        _assertNoSelector(address(zkStandingCredentialRegistry), "mintReward(uint256)");
        _assertNoSelector(address(zkStandingCredentialRegistry), "mintPriorityToken(uint256)");
        _assertNoSelector(address(zkStandingCredentialRegistry), "acceptManuscript(uint256)");
        _assertNoSelector(address(zkStandingCredentialRegistry), "setManuscriptMerit(uint256,uint256)");
    }

    function testM423StandingRelevantSettlementSuspendsOldCredentialUntilRecomputed() public {
        bytes32 workflowKey = keccak256("m423-standing-settlement-workflow");
        _registerM421ExecutionWorkflow(workflowKey, "ipfs://m423-standing-settlement-workflow");
        uint256 computationId = _createM423StandingComputationRecord(workflowKey, "m423-settlement-old", 42);
        uint256 credentialId = standingCredentialRegistry.issueCredential(
            AVADataTypes.Role.Panel,
            _m422CredentialInputForComputation(computationId, block.timestamp + 7 days, "ipfs://m423-old-credential")
        );
        require(_m422CredentialProves(credentialId, 40), "fresh credential did not prove");

        MockERC20 token = _m421FundedToken(100);
        uint256 sourceId = _createM421RewardSource(
            workflowKey, "m423-standing-settlement-source", token, 9, AVADataTypes.ValueExecutionMode.Claim
        );
        uint256 settlementId = valueSettlementExecutor.settleTokenTransfer(
            AVADataTypes.Role.ProtocolExecutor,
            AVADataTypes.ExecutionSourceType.AllocationRecord,
            sourceId,
            keccak256("executor-authority"),
            "ipfs://m423-reward-execution"
        );
        uint256 settlementRecordId = standingCredentialRegistry.recordStandingRelevantSettlement(
            AVADataTypes.Role.Panel,
            credentialId,
            AVADataTypes.StandingRelevantSettlementKind.RewardExecution,
            AVADataTypes.ExecutionSourceType.AllocationRecord,
            sourceId,
            settlementId,
            keccak256("panel-authority"),
            "ipfs://m423-standing-impact"
        );
        AVADataTypes.StandingCredentialSettlementRecord memory settlementImpact =
            standingCredentialRegistry.getStandingCredentialSettlement(settlementRecordId);
        require(
            settlementImpact.kind == AVADataTypes.StandingRelevantSettlementKind.RewardExecution, "wrong impact kind"
        );
        require(settlementImpact.sourceRecordId == sourceId, "source not recorded");
        require(settlementImpact.settlementId == settlementId, "settlement not recorded");
        require(!standingCredentialRegistry.isCredentialActive(credentialId), "settlement credential still active");
        require(!_m422CredentialProves(credentialId, 40), "settlement credential still proved");
        require(
            standingCredentialRegistry.getStandingCredential(credentialId).status
                == AVADataTypes.StandingCredentialStatus.Suspended,
            "credential not suspended"
        );

        uint256 recomputedId = _createM423StandingComputationRecord(workflowKey, "m423-settlement-new", 45);
        uint256 refreshedCredentialId = standingCredentialRegistry.issueCredential(
            AVADataTypes.Role.Panel,
            _m422CredentialInputForComputation(
                recomputedId, block.timestamp + 7 days, "ipfs://m423-refreshed-credential"
            )
        );
        require(_m422CredentialProves(refreshedCredentialId, 40), "refreshed credential did not prove");
    }

    function testM424StandingRelevantSettlementRequiresRealBoundSettlementRecord() public {
        bytes32 workflowKey = keccak256("m424-settlement-binding-workflow");
        _registerM421ExecutionWorkflow(workflowKey, "ipfs://m424-settlement-binding-workflow");
        uint256 computationId = _createM423StandingComputationRecord(workflowKey, "m424-binding-credential", 42);
        uint256 credentialId = standingCredentialRegistry.issueCredential(
            AVADataTypes.Role.Panel,
            _m422CredentialInputForComputation(
                computationId, block.timestamp + 7 days, "ipfs://m424-binding-credential"
            )
        );

        MockERC20 token = _m421FundedToken(100);
        uint256 sourceId =
            _createM421RewardSource(workflowKey, "m424-bound-source", token, 9, AVADataTypes.ValueExecutionMode.Claim);
        uint256 settlementId = valueSettlementExecutor.settleTokenTransfer(
            AVADataTypes.Role.ProtocolExecutor,
            AVADataTypes.ExecutionSourceType.AllocationRecord,
            sourceId,
            keccak256("executor-authority"),
            "ipfs://m424-bound-settlement"
        );
        _assertM424InvalidSettlementDoesNotSuspend(
            credentialId,
            AVADataTypes.ExecutionSourceType.AllocationRecord,
            sourceId,
            settlementId + 1000,
            "unknown settlement suspended credential"
        );

        uint256 otherSourceId =
            _createM421RewardSource(workflowKey, "m424-other-source", token, 3, AVADataTypes.ValueExecutionMode.Claim);
        uint256 otherSettlementId = valueSettlementExecutor.settleTokenTransfer(
            AVADataTypes.Role.ProtocolExecutor,
            AVADataTypes.ExecutionSourceType.AllocationRecord,
            otherSourceId,
            keccak256("executor-authority"),
            "ipfs://m424-wrong-source-settlement"
        );
        _assertM424InvalidSettlementDoesNotSuspend(
            credentialId,
            AVADataTypes.ExecutionSourceType.AllocationRecord,
            sourceId,
            otherSettlementId,
            "wrong source settlement suspended credential"
        );

        bytes32 foreignWorkflowKey = keccak256("m424-foreign-workflow");
        _registerM421ExecutionWorkflow(foreignWorkflowKey, "ipfs://m424-foreign-workflow");
        uint256 foreignSourceId = _createM421RewardSource(
            foreignWorkflowKey, "m424-foreign-source", token, 4, AVADataTypes.ValueExecutionMode.Claim
        );
        uint256 foreignSettlementId = valueSettlementExecutor.settleTokenTransfer(
            AVADataTypes.Role.ProtocolExecutor,
            AVADataTypes.ExecutionSourceType.AllocationRecord,
            foreignSourceId,
            keccak256("executor-authority"),
            "ipfs://m424-wrong-package-settlement"
        );
        _assertM424InvalidSettlementDoesNotSuspend(
            credentialId,
            AVADataTypes.ExecutionSourceType.AllocationRecord,
            sourceId,
            foreignSettlementId,
            "wrong package settlement suspended credential"
        );

        (uint256 authorSourceId, uint256 authorSettlementId) =
            _createM425AuthorRewardSettlement(workflowKey, "m424-author-source", token, 2);
        _assertM424InvalidSettlementDoesNotSuspend(
            credentialId,
            AVADataTypes.ExecutionSourceType.AllocationRecord,
            authorSourceId,
            authorSettlementId,
            "wrong subject settlement suspended credential"
        );

        uint256 impactId = standingCredentialRegistry.recordStandingRelevantSettlement(
            AVADataTypes.Role.Panel,
            credentialId,
            AVADataTypes.StandingRelevantSettlementKind.RewardExecution,
            AVADataTypes.ExecutionSourceType.AllocationRecord,
            sourceId,
            settlementId,
            keccak256("panel-authority"),
            "ipfs://m424-valid-impact"
        );
        require(
            standingCredentialRegistry.getStandingCredentialSettlement(impactId).settlementId == settlementId,
            "valid settlement missing"
        );
        require(!standingCredentialRegistry.isCredentialActive(credentialId), "valid settlement did not suspend");
    }
}

contract AVASkeletonStandingProof08ATest is AVASkeletonFixture {
    function testM425StandingRelevantSettlementKindMustMatchValueSettlementKind() public {
        bytes32 workflowKey = keccak256("m425-standing-kind-workflow");
        _registerM421ExecutionWorkflow(workflowKey, "ipfs://m425-standing-kind-workflow");
        uint256 computationId = _createM423StandingComputationRecord(workflowKey, "m425-standing-kind", 42);
        uint256 credentialId = standingCredentialRegistry.issueCredential(
            AVADataTypes.Role.Panel,
            _m422CredentialInputForComputation(computationId, block.timestamp + 7 days, "ipfs://m425-standing-kind")
        );

        MockERC20 token = _m421FundedToken(100);
        uint256 sourceId = _createM421RewardSource(
            workflowKey, "m425-standing-kind-source", token, 6, AVADataTypes.ValueExecutionMode.Claim
        );
        uint256 settlementId = valueSettlementExecutor.settleTokenTransfer(
            AVADataTypes.Role.ProtocolExecutor,
            AVADataTypes.ExecutionSourceType.AllocationRecord,
            sourceId,
            keccak256("executor-authority"),
            "ipfs://m425-token-settlement"
        );

        try standingCredentialRegistry.recordStandingRelevantSettlement(
            AVADataTypes.Role.Panel,
            credentialId,
            AVADataTypes.StandingRelevantSettlementKind.Waiver,
            AVADataTypes.ExecutionSourceType.AllocationRecord,
            sourceId,
            settlementId,
            keccak256("panel-authority"),
            "ipfs://m425-wrong-standing-kind"
        ) {
            revert("standing settlement accepted mismatched kind");
        } catch {}
        require(
            standingCredentialRegistry.getStandingCredential(credentialId).status
                == AVADataTypes.StandingCredentialStatus.Active,
            "mismatched standing kind mutated credential carrier status"
        );

        uint256 impactId = standingCredentialRegistry.recordStandingRelevantSettlement(
            AVADataTypes.Role.Panel,
            credentialId,
            AVADataTypes.StandingRelevantSettlementKind.RewardExecution,
            AVADataTypes.ExecutionSourceType.AllocationRecord,
            sourceId,
            settlementId,
            keccak256("panel-authority"),
            "ipfs://m425-valid-standing-kind"
        );
        require(
            standingCredentialRegistry.getStandingCredentialSettlement(impactId).settlementId == settlementId,
            "valid standing kind rejected"
        );
    }

    function testM54StandingComputationRecordsProvenanceAndCredentialRequiresMatch() public {
        uint256 computationId = _createM422StandingComputationRecord("m54-provenance", 42);
        AVADataTypes.StandingComputationRecord memory computation =
            standingRegistry.getStandingComputationRecord(computationId);
        require(computation.status == AVADataTypes.StandingComputationStatus.Active, "computation not active");
        require(computation.epoch == 1, "epoch missing");
        require(computation.sourceRecordSetHash != bytes32(0), "source set hash missing");
        require(computation.computationRuleHash == _m422ComputationRuleHash(), "rule hash missing");

        IStandingCredentialIssuer.StandingCredentialInput memory wrongEpoch =
            _m422CredentialInputForComputation(computationId, block.timestamp + 7 days, "ipfs://m54-wrong-epoch");
        wrongEpoch.epoch = wrongEpoch.epoch + 1;
        try standingCredentialRegistry.issueCredential(AVADataTypes.Role.Panel, wrongEpoch) {
            revert("credential accepted mismatched computation epoch");
        } catch {}

        IStandingCredentialIssuer.StandingCredentialInput memory wrongRule =
            _m422CredentialInputForComputation(computationId, block.timestamp + 7 days, "ipfs://m54-wrong-rule");
        wrongRule.computationRuleHash = keccak256("m54-wrong-standing-rule");
        try standingCredentialRegistry.issueCredential(AVADataTypes.Role.Panel, wrongRule) {
            revert("credential accepted mismatched computation rule");
        } catch {}

        uint256 credentialId = standingCredentialRegistry.issueCredential(
            AVADataTypes.Role.Panel,
            _m422CredentialInputForComputation(computationId, block.timestamp + 7 days, "ipfs://m54-valid-credential")
        );
        require(_m422CredentialProves(credentialId, 40), "valid credential did not prove");
    }

    function testM54SupersededStandingComputationStopsOldCredentialProof() public {
        uint256 oldComputationId = _createM422StandingComputationRecord("m54-old-computation", 42);
        uint256 oldCredentialId = standingCredentialRegistry.issueCredential(
            AVADataTypes.Role.Panel,
            _m422CredentialInputForComputation(oldComputationId, block.timestamp + 7 days, "ipfs://m54-old-credential")
        );
        require(_m422CredentialProves(oldCredentialId, 40), "old credential did not prove before supersession");

        AVADataTypes.StandingComputationContext memory replacementContext =
            _m54ReplacementComputationContext(oldComputationId, "m54-new-computation", 45, 2);
        uint256 newComputationId = standingRegistry.supersedeStandingComputationReadiness(
            AVADataTypes.Role.Panel, oldComputationId, replacementContext, "ipfs://m54-new-computation"
        );
        AVADataTypes.StandingComputationRecord memory oldComputation =
            standingRegistry.getStandingComputationRecord(oldComputationId);
        require(
            oldComputation.status == AVADataTypes.StandingComputationStatus.Superseded, "old computation not superseded"
        );
        require(oldComputation.supersededBy == newComputationId, "superseding computation missing");
        require(!standingCredentialRegistry.isCredentialActive(oldCredentialId), "old credential still active");
        require(
            !_m422CredentialProves(oldCredentialId, 40), "old credential still proved after computation supersession"
        );

        uint256 newCredentialId = standingCredentialRegistry.issueCredential(
            AVADataTypes.Role.Panel,
            _m422CredentialInputForComputation(newComputationId, block.timestamp + 7 days, "ipfs://m54-new-credential")
        );
        require(_m422CredentialProves(newCredentialId, 40), "new credential did not prove");
    }
}

contract AVASkeletonStandingProof08BTest is AVASkeletonFixture {
    function testM54InvalidatedStandingComputationStopsCredentialProof() public {
        uint256 computationId = _createM422StandingComputationRecord("m54-invalidated", 42);
        uint256 credentialId = standingCredentialRegistry.issueCredential(
            AVADataTypes.Role.Panel,
            _m422CredentialInputForComputation(
                computationId, block.timestamp + 7 days, "ipfs://m54-invalidated-credential"
            )
        );
        AVADataTypes.StandingComputationRecord memory computation =
            standingRegistry.getStandingComputationRecord(computationId);
        uint256 invalidationId = standingRegistry.invalidateStandingComputation(
            AVADataTypes.Role.Panel,
            computationId,
            computation.evidenceReceiptId,
            keccak256("panel-authority"),
            "ipfs://m54-invalidation"
        );
        AVADataTypes.StandingComputationRecord memory invalidated =
            standingRegistry.getStandingComputationRecord(computationId);
        require(invalidated.status == AVADataTypes.StandingComputationStatus.Invalidated, "computation not invalidated");
        require(
            invalidated.invalidatedByEvidenceReceiptId == computation.evidenceReceiptId, "invalidation evidence missing"
        );
        require(invalidationId == computationId, "invalidation target not returned");
        require(
            !standingCredentialRegistry.isCredentialActive(credentialId), "credential still active after invalidation"
        );
        require(!_m422CredentialProves(credentialId, 40), "credential still proved after invalidation");
    }
}
