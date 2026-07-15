// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./helpers/AVASkeletonFixture.sol";

contract AVASecurityStandingCommitmentRevisionTest is AVASkeletonFixture {
    function testAnonymousStandingCommitmentRevisionInvalidatesStaleCredentialWithoutIdentityLink() public {
        bytes32 subjectCommitment = _subjectCommitmentForSecret(7);
        uint256 proofReceiptId =
            _createM66StandingProofReceipt(DEFAULT_WORKFLOW, subjectCommitment, "security-anonymous-revision-old");
        uint256 packageId = rulePackageRegistry.getRulePackage(PEER_REVIEW_APP_ID, DEFAULT_WORKFLOW).packageId;
        IZKStandingCredentialIssuer.ZKStandingCredentialInput memory credentialInput =
            _m66CredentialInput(proofReceiptId, packageId, subjectCommitment, "security-anonymous-revision-old");
        uint256 credentialId =
            zkStandingCredentialRegistry.issueCredential(AVADataTypes.Role.Panel, credentialInput);
        require(
            zkStandingCredentialRegistry.credentialProves(
                credentialId,
                packageId,
                subjectCommitment,
                credentialInput.vectorKey,
                credentialInput.categoryHash,
                credentialInput.threshold
            ),
            "fresh anonymous credential did not prove"
        );

        uint256 revisionEvidenceId = _registerM68SourceSetEvidence(
            DEFAULT_WORKFLOW, "security-anonymous-standing-commitment-revision"
        );
        (uint256 revisionRecordId, uint256 revision) = standingRevisionRegistry.recordStandingCommitmentRevision(
            AVADataTypes.Role.Panel,
            StandingRevisionRegistry.StandingCommitmentRevisionInput({
                workflowKey: DEFAULT_WORKFLOW,
                packageId: packageId,
                subjectCommitment: subjectCommitment,
                evidenceReceiptId: revisionEvidenceId,
                authorityId: keccak256("panel-authority"),
                uri: "ipfs://security-anonymous-standing-commitment-revision"
            })
        );

        require(revisionRecordId != 0, "anonymous commitment revision receipt missing");
        require(revision == 1, "anonymous commitment revision not advanced");
        StandingRevisionRegistry.StandingCommitmentRevisionRecord memory revisionRecord =
            standingRevisionRegistry.getStandingCommitmentRevisionRecord(revisionRecordId);
        require(revisionRecord.packageId == packageId, "commitment revision package missing");
        require(revisionRecord.subjectCommitment == subjectCommitment, "commitment revision subject missing");
        require(revisionRecord.previousRevision == 0 && revisionRecord.revision == 1, "revision lineage missing");
        require(revisionRecord.evidenceReceiptId == revisionEvidenceId, "commitment revision evidence missing");
        require(
            standingRevisionRegistry.currentRevision(packageId, subjectCommitment) == revision,
            "anonymous commitment revision watermark missing"
        );
        require(
            !zkStandingCredentialRegistry.credentialProves(
                credentialId,
                packageId,
                subjectCommitment,
                credentialInput.vectorKey,
                credentialInput.categoryHash,
                credentialInput.threshold
            ),
            "stale anonymous credential survived commitment revision"
        );
        _assertM66CannotIssueCredential(
            _m66CredentialInput(
                proofReceiptId, packageId, subjectCommitment, "security-anonymous-revision-stale-reissue"
            ),
            "stale anonymous proof reissued credential after commitment revision"
        );

        uint256 refreshedProofReceiptId = _createM66StandingProofReceipt(
            DEFAULT_WORKFLOW, subjectCommitment, "security-anonymous-revision-refreshed", 2
        );
        IZKStandingCredentialIssuer.ZKStandingCredentialInput memory refreshedInput = _m66CredentialInput(
            refreshedProofReceiptId, packageId, subjectCommitment, "security-anonymous-revision-refreshed"
        );
        uint256 refreshedCredentialId =
            zkStandingCredentialRegistry.issueCredential(AVADataTypes.Role.Panel, refreshedInput);
        require(
            zkStandingCredentialRegistry.credentialProves(
                refreshedCredentialId,
                packageId,
                subjectCommitment,
                refreshedInput.vectorKey,
                refreshedInput.categoryHash,
                refreshedInput.threshold
            ),
            "refreshed anonymous credential did not prove at current revision"
        );
    }

    function testStandingCommitmentRevisionRejectsWeakAuthorityContextAndReplay() public {
        uint256 packageId = rulePackageRegistry.getRulePackage(PEER_REVIEW_APP_ID, DEFAULT_WORKFLOW).packageId;
        bytes32 subjectCommitment = keccak256("security-anonymous-revision-boundary");
        uint256 evidenceId =
            _registerM68SourceSetEvidence(DEFAULT_WORKFLOW, "security-anonymous-revision-boundary");
        StandingRevisionRegistry.StandingCommitmentRevisionInput memory input =
            StandingRevisionRegistry.StandingCommitmentRevisionInput({
                workflowKey: DEFAULT_WORKFLOW,
                packageId: packageId,
                subjectCommitment: subjectCommitment,
                evidenceReceiptId: evidenceId,
                authorityId: keccak256("panel-authority"),
                uri: "ipfs://security-anonymous-revision-boundary"
            });

        StandingRevisionRegistry.StandingCommitmentRevisionInput memory wrongAuthority = input;
        wrongAuthority.authorityId = keccak256("other-panel-authority");
        try standingRevisionRegistry.recordStandingCommitmentRevision(AVADataTypes.Role.Panel, wrongAuthority) returns (
            uint256,
            uint256
        ) {
            revert("wrong authority recorded anonymous commitment revision");
        } catch {}
        input.authorityId = keccak256("panel-authority");

        StandingRevisionRegistry.StandingCommitmentRevisionInput memory knownSubject = input;
        knownSubject.subjectCommitment = REVIEWER_SUBJECT;
        try standingRevisionRegistry.recordStandingCommitmentRevision(AVADataTypes.Role.Panel, knownSubject) returns (
            uint256,
            uint256
        ) {
            revert("known active subject used anonymous commitment revision path");
        } catch {}
        input.subjectCommitment = subjectCommitment;

        StandingRevisionRegistry.StandingCommitmentRevisionInput memory wrongWorkflow = input;
        wrongWorkflow.workflowKey = keccak256("security-wrong-anonymous-revision-workflow");
        try standingRevisionRegistry.recordStandingCommitmentRevision(AVADataTypes.Role.Panel, wrongWorkflow) returns (
            uint256,
            uint256
        ) {
            revert("wrong workflow recorded anonymous commitment revision");
        } catch {}
        input.workflowKey = DEFAULT_WORKFLOW;

        StandingRevisionRegistry.StandingCommitmentRevisionInput memory unknownEvidence = input;
        unknownEvidence.evidenceReceiptId = evidenceId + 10_000;
        try standingRevisionRegistry.recordStandingCommitmentRevision(AVADataTypes.Role.Panel, unknownEvidence) returns (
            uint256,
            uint256
        ) {
            revert("unknown evidence recorded anonymous commitment revision");
        } catch {}
        input.evidenceReceiptId = evidenceId;

        standingRevisionRegistry.recordStandingCommitmentRevision(AVADataTypes.Role.Panel, input);
        try standingRevisionRegistry.recordStandingCommitmentRevision(AVADataTypes.Role.Panel, input) returns (
            uint256,
            uint256
        ) {
            revert("same evidence replayed anonymous commitment revision");
        } catch {}

        require(
            standingRevisionRegistry.currentRevision(packageId, subjectCommitment) == 1,
            "invalid or replayed commitment revision changed watermark"
        );
        require(
            standingRevisionRegistry.nextStandingCommitmentRevisionRecordId() == 2,
            "invalid or replayed commitment revision wrote receipt"
        );
    }
}
