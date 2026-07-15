// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AVACoreTypes} from "../src/core/AVACoreTypes.sol";
import {AVACapabilityKeys} from "../src/core/AVACapabilityKeys.sol";
import {AVACoreRulePackageRegistry} from "../src/core/AVACoreRulePackageRegistry.sol";
import {IAVAApplicationModule} from "../src/interfaces/IAVAApplicationModule.sol";
import {AVAChallengeExtension} from "../src/extensions/challenge/AVAChallengeExtension.sol";
import {
    AVAStandingComputationExtension,
    AVAStandingCredentialExtension
} from "../src/extensions/standing/AVAStandingCredentialExtensions.sol";
import {AVAStandingRevisionExtension} from "../src/extensions/standing/AVAStandingRevisionExtension.sol";
import {
    AVAStandingRecordExtension,
    AVAAllocationRecordExtension
} from "../src/extensions/downstream/AVADownstreamRecordExtensions.sol";
import {IAVADownstreamRecordSource} from "../src/extensions/downstream/IAVADownstreamRecordSource.sol";
import {
    DefaultAVARewardPolicyModule,
    DefaultAVAPriorityPolicyModule,
    DefaultAVAPenaltyPolicyModule,
    DefaultAVARestorationPolicyModule,
    AVARewardPriorityExtension,
    AVAPenaltyRestorationExtension
} from "../src/extensions/governance/AVABoundedGovernanceExtensions.sol";
import {
    DefaultAVAValueExecutionPolicyModule,
    AVAValueLifecycleExtension
} from "../src/extensions/settlement/AVAValueLifecycleExtension.sol";
import {
    DefaultStandingComputationPolicyModule,
    DefaultStandingCredentialPolicyModule
} from "../src/extensions/standing/DefaultStandingCredentialModules.sol";
import {PeerReviewTypes} from "../src/apps/peerreview/PeerReviewTypes.sol";
import {CanonicalPeerReviewActor, CanonicalPeerReviewFixture} from "../script/helpers/CanonicalPeerReviewFixture.sol";

abstract contract CanonicalInvariantTargetRegistry {
    struct FuzzSelector {
        address addr;
        bytes4[] selectors;
    }

    struct FuzzArtifactSelector {
        string artifact;
        bytes4[] selectors;
    }

    struct FuzzInterface {
        address addr;
        string[] artifacts;
    }

    address[] private targets;

    function _targetContract(address target) internal {
        targets.push(target);
    }

    function targetContracts() public view returns (address[] memory) {
        return targets;
    }

    function excludeContracts() public pure returns (address[] memory values) {}
    function targetSenders() public pure returns (address[] memory values) {}
    function excludeSenders() public pure returns (address[] memory values) {}
    function targetSelectors() public pure returns (FuzzSelector[] memory values) {}
    function excludeSelectors() public pure returns (FuzzSelector[] memory values) {}
    function targetArtifactSelectors() public pure returns (FuzzArtifactSelector[] memory values) {}
    function targetArtifacts() public pure returns (string[] memory values) {}
    function excludeArtifacts() public pure returns (string[] memory values) {}
    function targetInterfaces() public pure returns (FuzzInterface[] memory values) {}
}

abstract contract CanonicalExtendedPeerReviewFixture is CanonicalPeerReviewFixture {
    function _canonicalBindings(IAVAApplicationModule applicationModule)
        internal
        override
        returns (AVACoreRulePackageRegistry.ModuleBinding[] memory bindings)
    {
        AVACoreRulePackageRegistry.ModuleBinding[] memory scenarioBindings = super._canonicalBindings(applicationModule);
        bindings = new AVACoreRulePackageRegistry.ModuleBinding[](19);
        for (uint256 i; i < scenarioBindings.length; ++i) {
            bindings[i] = scenarioBindings[i];
        }
        bindings[12] =
            _binding(AVACapabilityKeys.STANDING_COMPUTATION, address(new DefaultStandingComputationPolicyModule()));
        bindings[13] =
            _binding(AVACapabilityKeys.STANDING_CREDENTIAL, address(new DefaultStandingCredentialPolicyModule()));
        bindings[14] = _binding(AVACapabilityKeys.REWARD, address(new DefaultAVARewardPolicyModule()));
        bindings[15] = _binding(AVACapabilityKeys.PRIORITY, address(new DefaultAVAPriorityPolicyModule()));
        bindings[16] = _binding(AVACapabilityKeys.PENALTY, address(new DefaultAVAPenaltyPolicyModule()));
        bindings[17] = _binding(AVACapabilityKeys.RESTORATION, address(new DefaultAVARestorationPolicyModule()));
        bindings[18] = _binding(AVACapabilityKeys.VALUE_EXECUTION, address(new DefaultAVAValueExecutionPolicyModule()));
    }
}

contract CanonicalChallengeInvariantHandler {
    AVAChallengeExtension public immutable EXTENSION;
    CanonicalPeerReviewActor public immutable EDITOR;
    CanonicalPeerReviewActor public immutable PANEL;
    bytes32 public immutable EDITOR_AUTHORITY;
    bytes32 public immutable PANEL_AUTHORITY;
    uint256[2] private challengeIds;

    constructor(
        AVAChallengeExtension extension,
        CanonicalPeerReviewActor editor,
        CanonicalPeerReviewActor panel,
        bytes32 editorAuthority,
        bytes32 panelAuthority,
        uint256 firstChallengeId,
        uint256 secondChallengeId
    ) {
        EXTENSION = extension;
        EDITOR = editor;
        PANEL = panel;
        EDITOR_AUTHORITY = editorAuthority;
        PANEL_AUTHORITY = panelAuthority;
        challengeIds[0] = firstChallengeId;
        challengeIds[1] = secondChallengeId;
    }

    function screen(uint256 seed) external {
        uint256 selectedChallengeId = challengeIds[seed % challengeIds.length];
        try EDITOR.screenChallenge(EXTENSION, selectedChallengeId, EDITOR_AUTHORITY) {} catch {}
    }

    function resolve(uint256 seed, uint256 outcomeSeed) external {
        uint256 selectedChallengeId = challengeIds[seed % challengeIds.length];
        AVAChallengeExtension.ChallengeRecord memory challenge = EXTENSION.getChallenge(selectedChallengeId);
        AVACoreTypes.RecognisedStateStatus currentStatus =
        EXTENSION.GOVERNANCE_KERNEL().getRecognisedState(challenge.challengedRecognisedStateId).status;
        AVAChallengeExtension.ChallengeOutcome outcome = _outcome(outcomeSeed);
        AVACoreTypes.RecognisedStateStatus correctionStatus = outcome == AVAChallengeExtension.ChallengeOutcome.Upheld
            ? AVACoreTypes.RecognisedStateStatus.Downgraded
            : currentStatus;
        try PANEL.resolveChallenge(
            EXTENSION,
            AVAChallengeExtension.ChallengeResolutionInput({
                challengeId: selectedChallengeId,
                roleKey: PeerReviewTypes.ROLE_PANEL,
                authorityId: PANEL_AUTHORITY,
                outcome: outcome,
                correctionStatus: correctionStatus,
                reasonHash: keccak256(abi.encode("canonical-invariant-resolution", seed, outcomeSeed)),
                reasonURI: "ipfs://canonical-invariant-resolution"
            })
        ) {}
            catch {}
    }

    function makeRestorationAvailable(uint256 seed) external {
        uint256 selectedChallengeId = challengeIds[seed % challengeIds.length];
        try PANEL.recordRestorationAvailability(
            EXTENSION,
            selectedChallengeId,
            PANEL_AUTHORITY,
            keccak256(abi.encode("canonical-invariant-restoration-available", seed))
        ) {}
            catch {}
    }

    function applyRestoration(uint256 seed) external {
        uint256 selectedChallengeId = challengeIds[seed % challengeIds.length];
        try PANEL.applyRestoration(
            EXTENSION,
            selectedChallengeId,
            PANEL_AUTHORITY,
            keccak256(abi.encode("canonical-invariant-restoration", seed))
        ) {}
            catch {}
    }

    function close(uint256 seed) external {
        uint256 selectedChallengeId = challengeIds[seed % challengeIds.length];
        try PANEL.closeChallenge(
            EXTENSION, selectedChallengeId, PANEL_AUTHORITY, keccak256(abi.encode("canonical-invariant-close", seed))
        ) {}
            catch {}
    }

    function challengeId(uint256 index) external view returns (uint256) {
        return challengeIds[index];
    }

    function _outcome(uint256 seed) private pure returns (AVAChallengeExtension.ChallengeOutcome) {
        uint256 choice = seed % 4;
        if (choice == 0) return AVAChallengeExtension.ChallengeOutcome.Upheld;
        if (choice == 1) return AVAChallengeExtension.ChallengeOutcome.RejectedGoodFaith;
        if (choice == 2) return AVAChallengeExtension.ChallengeOutcome.Negligent;
        return AVAChallengeExtension.ChallengeOutcome.MaliciousOrFabricated;
    }
}

contract CanonicalChallengeInvariantTest is CanonicalPeerReviewFixture, CanonicalInvariantTargetRegistry {
    uint256 private targetStateId;
    CanonicalChallengeInvariantHandler private handler;

    function setUp() public {
        _deployCanonicalPeerReview();
        ReviewPath memory review = _createReviewPath("canonical-invariant-concurrent", true);
        targetStateId = review.recognisedStateId;
        ChallengePath memory first = _createChallengePath(targetStateId, "canonical-invariant-first");

        CanonicalPeerReviewActor secondChallenger = new CanonicalPeerReviewActor();
        bytes32 secondSubject = keccak256("canonical.peer-review.second-challenger.v1");
        identityRegistry.assignSubject(
            address(secondChallenger),
            PeerReviewTypes.APP_ID,
            PeerReviewTypes.ROLE_CHALLENGER,
            secondSubject,
            "ipfs://canonical-second-challenger"
        );
        ChallengePath memory second =
            _createChallengePathFor(secondChallenger, secondSubject, targetStateId, "canonical-invariant-second");
        handler = new CanonicalChallengeInvariantHandler(
            challengeExtension,
            editorActor,
            panelActor,
            EDITOR_SUBJECT,
            PANEL_SUBJECT,
            first.challengeId,
            second.challengeId
        );
        _targetContract(address(handler));
    }

    function invariantOpenChallengeCountMatchesLifecycle() public view {
        uint256 expectedOpen;
        for (uint256 i; i < 2; ++i) {
            AVAChallengeExtension.ChallengeRecord memory challenge =
                challengeExtension.getChallenge(handler.challengeId(i));
            if (challenge.status != AVAChallengeExtension.ChallengeStatus.Closed) ++expectedOpen;
        }
        require(
            challengeExtension.openChallengeCountByRecognisedState(targetStateId) == expectedOpen,
            "open challenge count drifted"
        );
    }

    function invariantHighImpactTargetStatusAlwaysHasSourceBoundLineage() public view {
        AVACoreTypes.RecognisedStateRecord memory target = governanceKernel.getRecognisedState(targetStateId);
        if (
            target.status != AVACoreTypes.RecognisedStateStatus.Downgraded
                && target.status != AVACoreTypes.RecognisedStateStatus.Voided
                && target.status != AVACoreTypes.RecognisedStateStatus.Restored
        ) return;
        AVACoreTypes.RecognisedStateTransitionRecord memory transition =
            governanceKernel.getRecognisedStateTransition(target.lastTransitionId);
        require(
            transition.kind == AVACoreTypes.TransitionKind.ChallengeCorrection
                || transition.kind == AVACoreTypes.TransitionKind.Restoration,
            "high-impact state lacked source-bound transition"
        );
        require(
            transition.sourceRecordId == handler.challengeId(0) || transition.sourceRecordId == handler.challengeId(1),
            "transition source was not a challenge"
        );
        require(transition.decisionPackageId == challengePackageId, "wrong decision package");
    }

    function invariantChallengeWorkflowAndTargetPackagesRemainPinned() public view {
        for (uint256 i; i < 2; ++i) {
            AVAChallengeExtension.ChallengeRecord memory challenge =
                challengeExtension.getChallenge(handler.challengeId(i));
            require(challenge.packageId == challengePackageId, "challenge package drifted");
            require(challenge.targetPackageId == reviewPackageId, "target package drifted");
            require(challenge.packageId != challenge.targetPackageId, "recursive workflow collapsed");
            AVACoreTypes.RecognisedStateRecord memory challengeState =
                governanceKernel.getRecognisedState(challenge.challengeRecognisedStateId);
            require(challengeState.packageId == challengePackageId, "challenge state package drifted");
            if (challenge.outcome == AVAChallengeExtension.ChallengeOutcome.Upheld) {
                require(
                    challengeState.status == AVACoreTypes.RecognisedStateStatus.Vested,
                    "upheld challenge state not vested"
                );
            }
        }
    }
}

contract CanonicalStandingInvariantHandler {
    struct Config {
        CanonicalPeerReviewActor panel;
        AVAStandingComputationExtension computation;
        AVAStandingCredentialExtension credential;
        AVAStandingRecordExtension standing;
        AVAStandingRevisionExtension revision;
        uint256 stateId;
        uint256 evidenceId;
        uint256 packageId;
        uint256 credentialId;
        bytes32 subjectId;
        bytes32 panelAuthority;
        bytes32 vectorKey;
        bytes32 categoryHash;
    }

    CanonicalPeerReviewActor public immutable PANEL;
    AVAStandingComputationExtension public immutable COMPUTATION;
    AVAStandingCredentialExtension public immutable CREDENTIAL;
    AVAStandingRecordExtension public immutable STANDING;
    AVAStandingRevisionExtension public immutable REVISION;
    uint256 public immutable STATE_ID;
    uint256 public immutable EVIDENCE_ID;
    uint256 public immutable PACKAGE_ID;
    uint256 public immutable CREDENTIAL_ID;
    bytes32 public immutable SUBJECT_ID;
    bytes32 public immutable PANEL_AUTHORITY;
    bytes32 public immutable VECTOR_KEY;
    bytes32 public immutable CATEGORY_HASH;
    bool public staleProofObserved;

    constructor(Config memory config) {
        PANEL = config.panel;
        COMPUTATION = config.computation;
        CREDENTIAL = config.credential;
        STANDING = config.standing;
        REVISION = config.revision;
        STATE_ID = config.stateId;
        EVIDENCE_ID = config.evidenceId;
        PACKAGE_ID = config.packageId;
        CREDENTIAL_ID = config.credentialId;
        SUBJECT_ID = config.subjectId;
        PANEL_AUTHORITY = config.panelAuthority;
        VECTOR_KEY = config.vectorKey;
        CATEGORY_HASH = config.categoryHash;
    }

    function advanceRevision(uint256 seed) external {
        try PANEL.recordStanding(
            STANDING,
            AVAStandingRecordExtension.StandingInput({
                recognisedStateId: STATE_ID,
                roleKey: PeerReviewTypes.ROLE_PANEL,
                authorityId: PANEL_AUTHORITY,
                subjectId: SUBJECT_ID,
                evidenceId: EVIDENCE_ID,
                dimensionKey: keccak256(abi.encode("canonical-invariant-standing-dimension", seed)),
                delta: 1,
                reasonHash: keccak256(abi.encode("canonical-invariant-standing-update", seed)),
                uri: "ipfs://canonical-invariant-standing-update"
            })
        ) {}
            catch {}
        _observeProof();
    }

    function observeProof() external {
        _observeProof();
    }

    function _observeProof() private {
        AVAStandingCredentialExtension.CredentialRecord memory credential = CREDENTIAL.getCredential(CREDENTIAL_ID);
        uint256 revision = REVISION.currentRevision(PACKAGE_ID, SUBJECT_ID);
        bool proves = CREDENTIAL.credentialProves(
            PACKAGE_ID, CREDENTIAL_ID, SUBJECT_ID, VECTOR_KEY, CATEGORY_HASH, credential.lowerBound
        );
        if (revision != credential.revision && proves) staleProofObserved = true;
    }
}

contract CanonicalStandingInvariantTest is CanonicalExtendedPeerReviewFixture, CanonicalInvariantTargetRegistry {
    bytes32 private constant VECTOR_KEY = keccak256("canonical.standing.vector.v1");
    bytes32 private constant CATEGORY_HASH = keccak256("canonical.standing.category.v1");

    AVAStandingComputationExtension private computationExtension;
    AVAStandingCredentialExtension private credentialExtension;
    CanonicalStandingInvariantHandler private handler;
    uint256 private computationId;
    uint256 private credentialId;

    function setUp() public {
        _deployCanonicalPeerReviewWithRevision();
        _finalizeRevisionHooks();
        ReviewPath memory review = _createReviewPath("canonical-invariant-standing", true);
        computationExtension = new AVAStandingComputationExtension(
            governanceKernel, authorityMatrix, identityRegistry, packageRegistry, evidenceRegistry, revisionExtension
        );
        credentialExtension = new AVAStandingCredentialExtension(
            authorityMatrix,
            identityRegistry,
            packageRegistry,
            evidenceRegistry,
            revisionExtension,
            computationExtension
        );
        computationId = panelActor.recordStandingComputation(
            computationExtension,
            AVAStandingComputationExtension.ComputationInput({
                recognisedStateId: review.recognisedStateId,
                roleKey: PeerReviewTypes.ROLE_PANEL,
                authorityId: PANEL_SUBJECT,
                subjectId: REVIEWER_SUBJECT,
                evidenceId: review.reviewEvidenceId,
                vectorKey: VECTOR_KEY,
                categoryHash: CATEGORY_HASH,
                lowerBound: 10,
                upperBound: 20,
                thresholdSetHash: keccak256("canonical.standing.thresholds.v1"),
                computationRuleHash: keccak256("canonical.standing.rule.v1"),
                sourceSetCommitment: keccak256("canonical.standing.source-set.v1"),
                outputCommitment: keccak256("canonical.standing.output.v1"),
                epoch: 1,
                uri: "ipfs://canonical-standing-computation"
            })
        );
        credentialId = panelActor.issueStandingCredential(
            credentialExtension,
            AVAStandingCredentialExtension.CredentialInput({
                computationId: computationId,
                roleKey: PeerReviewTypes.ROLE_PANEL,
                authorityId: PANEL_SUBJECT,
                expiresAt: uint64(block.timestamp + 365 days),
                uri: "ipfs://canonical-standing-credential"
            })
        );
        CanonicalStandingInvariantHandler.Config memory config;
        config.panel = panelActor;
        config.computation = computationExtension;
        config.credential = credentialExtension;
        config.standing = standingExtension;
        config.revision = revisionExtension;
        config.stateId = review.recognisedStateId;
        config.evidenceId = review.reviewEvidenceId;
        config.packageId = reviewPackageId;
        config.credentialId = credentialId;
        config.subjectId = REVIEWER_SUBJECT;
        config.panelAuthority = PANEL_SUBJECT;
        config.vectorKey = VECTOR_KEY;
        config.categoryHash = CATEGORY_HASH;
        handler = new CanonicalStandingInvariantHandler(config);
        _targetContract(address(handler));
    }

    function invariantStaleStandingCredentialNeverProves() public view {
        require(!handler.staleProofObserved(), "stale standing credential proved");
        AVAStandingCredentialExtension.CredentialRecord memory credential =
            credentialExtension.getCredential(credentialId);
        uint256 revision = revisionExtension.currentRevision(reviewPackageId, REVIEWER_SUBJECT);
        bool active = credentialExtension.isCredentialActive(credentialId);
        bool proves = credentialExtension.credentialProves(
            reviewPackageId, credentialId, REVIEWER_SUBJECT, VECTOR_KEY, CATEGORY_HASH, 10
        );
        if (revision == credential.revision) {
            require(active && proves, "current credential became unusable");
        } else {
            require(!active && !proves, "stale credential remained usable");
            require(!computationExtension.isComputationCurrent(computationId), "stale computation remained current");
        }
    }
}

contract CanonicalRecoveryInvariantHandler {
    AVAValueLifecycleExtension public immutable LIFECYCLE;
    CanonicalPeerReviewActor public immutable PROTOCOL_ACTOR;
    uint256 public immutable OBLIGATION_ID;
    bytes32 public immutable AUTHORITY_ID;

    constructor(
        AVAValueLifecycleExtension lifecycle,
        CanonicalPeerReviewActor protocolActor,
        uint256 obligationId,
        bytes32 authorityId
    ) {
        LIFECYCLE = lifecycle;
        PROTOCOL_ACTOR = protocolActor;
        OBLIGATION_ID = obligationId;
        AUTHORITY_ID = authorityId;
    }

    function recordTerminalOutcome(uint256 seed) external {
        AVAValueLifecycleExtension.RecoveryOutcome outcome = AVAValueLifecycleExtension.RecoveryOutcome((seed % 4) + 1);
        try PROTOCOL_ACTOR.recordRecoveryOutcome(
            LIFECYCLE,
            AVAValueLifecycleExtension.RecoveryOutcomeInput({
                obligationId: OBLIGATION_ID,
                roleKey: PeerReviewTypes.ROLE_PROTOCOL_EXECUTOR,
                authorityId: AUTHORITY_ID,
                outcome: outcome,
                referenceHash: keccak256(abi.encode("canonical-invariant-recovery", seed)),
                uri: "ipfs://canonical-invariant-recovery"
            })
        ) {}
            catch {}
    }
}

contract CanonicalRecoveryInvariantTest is CanonicalExtendedPeerReviewFixture, CanonicalInvariantTargetRegistry {
    bytes32 private constant PROTOCOL_SUBJECT = keccak256("canonical.peer-review.protocol-subject.v1");

    AVARewardPriorityExtension private rewardExtension;
    AVAPenaltyRestorationExtension private penaltyExtension;
    AVAValueLifecycleExtension private lifecycleExtension;
    CanonicalPeerReviewActor private protocolActor;
    CanonicalRecoveryInvariantHandler private handler;
    uint256 private originSettlementId;
    uint256 private obligationId;
    uint256 private penaltyId;

    function setUp() public {
        _deployCanonicalPeerReviewWithRevision();
        rewardExtension = new AVARewardPriorityExtension(
            governanceKernel,
            authorityMatrix,
            identityRegistry,
            packageRegistry,
            evidenceRegistry,
            disclosureRegistry,
            IAVADownstreamRecordSource(address(allocationExtension))
        );
        penaltyExtension = new AVAPenaltyRestorationExtension(
            governanceKernel,
            authorityMatrix,
            identityRegistry,
            packageRegistry,
            evidenceRegistry,
            disclosureRegistry,
            challengeExtension,
            revisionExtension
        );
        lifecycleExtension = new AVAValueLifecycleExtension(
            governanceKernel,
            authorityMatrix,
            identityRegistry,
            packageRegistry,
            evidenceRegistry,
            disclosureRegistry,
            rewardExtension,
            penaltyExtension,
            revisionExtension
        );
        revisionExtension.bindRevisionWriter(reviewPackageId, address(penaltyExtension));
        revisionExtension.bindRevisionWriter(challengePackageId, address(penaltyExtension));
        revisionExtension.bindRevisionWriter(reviewPackageId, address(lifecycleExtension));
        revisionExtension.bindRevisionWriter(challengePackageId, address(lifecycleExtension));
        _finalizeRevisionHooks();
        _configureProtocolActor();
        _createRecoveryChain();
        handler =
            new CanonicalRecoveryInvariantHandler(lifecycleExtension, protocolActor, obligationId, PROTOCOL_SUBJECT);
        _targetContract(address(handler));
    }

    function invariantRecoveryHasAtMostOneTerminalOutcome() public view {
        uint256 outcomeId = lifecycleExtension.recoveryOutcomeIdByObligation(obligationId);
        require(lifecycleExtension.nextRecoveryOutcomeId() <= 2, "multiple terminal outcomes recorded");
        if (outcomeId == 0) return;
        AVAValueLifecycleExtension.RecoveryOutcomeRecord memory outcome =
            lifecycleExtension.getRecoveryOutcome(outcomeId);
        require(outcome.obligationId == obligationId, "terminal outcome used wrong obligation");
        require(outcome.originSettlementId == originSettlementId, "terminal outcome used wrong settlement");
        require(outcome.penaltyId == penaltyId, "terminal outcome used wrong finding");
        require(outcome.outcome != AVAValueLifecycleExtension.RecoveryOutcome.None, "empty terminal outcome");
    }

    function invariantRepaymentObligationRemainsBoundToCompletedOrigin() public view {
        AVAValueLifecycleExtension.RepaymentObligationRecord memory obligation =
            lifecycleExtension.getRepaymentObligation(obligationId);
        AVAValueLifecycleExtension.ValueSettlementRecord memory origin =
            lifecycleExtension.getValueSettlement(originSettlementId);
        AVAPenaltyRestorationExtension.PenaltyRecord memory penalty = penaltyExtension.getPenalty(penaltyId);
        require(obligation.originSettlementId == origin.id, "obligation origin drifted");
        require(obligation.penaltyId == penaltyId, "obligation finding drifted");
        require(obligation.packageId == origin.packageId, "obligation package drifted");
        require(obligation.subjectId == origin.subjectId, "obligation subject drifted");
        require(obligation.evidenceId == origin.evidenceId, "obligation evidence drifted");
        require(obligation.units == origin.units, "obligation amount drifted");
        require(origin.recognisedStateId == penalty.recognisedStateId, "obligation state lineage drifted");
        require(
            lifecycleExtension.obligationIdByOriginSettlement(originSettlementId) == obligationId,
            "origin admitted duplicate obligation"
        );
    }

    function _configureProtocolActor() private {
        protocolActor = new CanonicalPeerReviewActor();
        identityRegistry.assignSubject(
            address(protocolActor),
            PeerReviewTypes.APP_ID,
            PeerReviewTypes.ROLE_PROTOCOL_EXECUTOR,
            PROTOCOL_SUBJECT,
            "ipfs://canonical-protocol-subject"
        );
        _permitProtocol(AVACoreTypes.ACTION_RECORD_ALLOCATION);
        _permitProtocol(AVACoreTypes.ACTION_RECORD_REWARD);
        _permitProtocol(AVACoreTypes.ACTION_RECORD_REWARD_LIFECYCLE);
        _permitProtocol(AVACoreTypes.ACTION_RECORD_VALUE_SETTLEMENT);
        _permitProtocol(AVACoreTypes.ACTION_RECORD_REPAYMENT_OBLIGATION);
        _permitProtocol(AVACoreTypes.ACTION_RECORD_RECOVERY_OUTCOME);
        authorityMatrix.setPermission(
            PeerReviewTypes.APP_ID, PeerReviewTypes.ROLE_PANEL, AVACoreTypes.ACTION_RECORD_PENALTY, true
        );
    }

    function _permitProtocol(bytes32 actionKey) private {
        authorityMatrix.setPermission(PeerReviewTypes.APP_ID, PeerReviewTypes.ROLE_PROTOCOL_EXECUTOR, actionKey, true);
    }

    function _createRecoveryChain() private {
        ReviewPath memory review = _createReviewPath("canonical-invariant-recovery", true);
        uint256 allocationId = protocolActor.recordAllocation(
            allocationExtension,
            AVAAllocationRecordExtension.AllocationInput({
                recognisedStateId: review.recognisedStateId,
                roleKey: PeerReviewTypes.ROLE_PROTOCOL_EXECUTOR,
                authorityId: PROTOCOL_SUBJECT,
                subjectId: REVIEWER_SUBJECT,
                evidenceId: review.reviewEvidenceId,
                allocationKindKey: keccak256("canonical.recovery.allocation.v1"),
                units: 7,
                reasonHash: keccak256("canonical-recovery-allocation"),
                uri: "ipfs://canonical-recovery-allocation"
            })
        );
        uint256 rewardId = protocolActor.recordReward(
            rewardExtension,
            AVARewardPriorityExtension.RewardPriorityInput({
                allocationId: allocationId,
                roleKey: PeerReviewTypes.ROLE_PROTOCOL_EXECUTOR,
                authorityId: PROTOCOL_SUBJECT,
                subjectId: REVIEWER_SUBJECT,
                evidenceId: review.reviewEvidenceId,
                kindKey: keccak256("canonical.recovery.record-only-reward.v1"),
                units: 7,
                reasonHash: keccak256("canonical-recovery-reward"),
                uri: "ipfs://canonical-recovery-reward"
            })
        );
        protocolActor.recordRewardLifecycle(
            lifecycleExtension,
            AVAValueLifecycleExtension.RewardLifecycleInput({
                rewardId: rewardId,
                roleKey: PeerReviewTypes.ROLE_PROTOCOL_EXECUTOR,
                authorityId: PROTOCOL_SUBJECT,
                kind: AVAValueLifecycleExtension.RewardLifecycleKind.Vest,
                reasonHash: keccak256("canonical-recovery-reward-vest"),
                uri: "ipfs://canonical-recovery-reward-vest"
            })
        );
        originSettlementId = protocolActor.recordValueSettlement(
            lifecycleExtension,
            AVAValueLifecycleExtension.ValueSettlementInput({
                sourceKind: AVAValueLifecycleExtension.ValueSourceKind.Reward,
                sourceId: rewardId,
                roleKey: PeerReviewTypes.ROLE_PROTOCOL_EXECUTOR,
                authorityId: PROTOCOL_SUBJECT,
                settlementKindKey: keccak256("canonical.recovery.record-only-settlement.v1"),
                units: 7,
                referenceHash: keccak256("canonical-recovery-settlement"),
                uri: "ipfs://canonical-recovery-settlement"
            })
        );

        ChallengePath memory challenge =
            _createChallengePath(review.recognisedStateId, "canonical-invariant-recovery-challenge");
        uint256 challengeTransitionId = _screenAndResolve(
            challenge,
            AVAChallengeExtension.ChallengeOutcome.Upheld,
            AVACoreTypes.RecognisedStateStatus.Downgraded,
            "canonical-invariant-recovery-challenge"
        );
        penaltyId = panelActor.recordPenalty(
            penaltyExtension,
            AVAPenaltyRestorationExtension.PenaltyInput({
                challengeTransitionId: challengeTransitionId,
                roleKey: PeerReviewTypes.ROLE_PANEL,
                authorityId: PANEL_SUBJECT,
                findingKey: PeerReviewTypes.FINDING_IRRESPONSIBLE_REVIEW,
                reasonHash: keccak256("canonical-recovery-finding"),
                uri: "ipfs://canonical-recovery-finding"
            })
        );
        obligationId = protocolActor.recordRepaymentObligation(
            lifecycleExtension,
            AVAValueLifecycleExtension.RepaymentObligationInput({
                originSettlementId: originSettlementId,
                penaltyId: penaltyId,
                roleKey: PeerReviewTypes.ROLE_PROTOCOL_EXECUTOR,
                authorityId: PROTOCOL_SUBJECT,
                units: 7,
                reasonHash: keccak256("canonical-recovery-obligation"),
                uri: "ipfs://canonical-recovery-obligation"
            })
        );
    }
}
