// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;
import {SemaphoreGroups} from "@semaphore-protocol/contracts/base/SemaphoreGroups.sol";
import {ISemaphoreVerifier} from "@semaphore-protocol/contracts/interfaces/ISemaphoreVerifier.sol";

interface IFriendtechSharesV1 {
    // SharesSubject => (Holder => Balance)
    function sharesBallance(address, address) external returns (uint256);
}

/// @title Friend.Tech private polls
/// @notice Create Private polls for your Friend.Tech key owners
/// @dev Code largely adapted from @semaphore-protocol/contracts/extensions/SemaphoreVoting.sol
/// @author Odysseas.eth <me@odyslam.com>
contract PrivateFT is SemaphoreGroups {
    IFriendtechSharesV1 public $friendTech;
    ISemaphoreVerifier public $verifier;
    uint256 immutable TREE_DEPTH;

    enum PollState {
        Created,
        Ongoing,
        Ended
    }

    struct Verifier {
        address contractAddress;
        uint256 merkleTreeDepth;
    }

    struct Poll {
        address coordinator;
        PollState state;
        mapping(uint256 => bool) nullifierHashes;
    }

    /// @dev Emitted when a new poll is created.
    /// @param pollId: Id of the poll.
    /// @param coordinator: Coordinator of the poll.
    event PollCreated(uint256 pollId, address indexed coordinator);

    /// @dev Emitted when a poll is started.
    /// @param pollId: Id of the poll.
    /// @param coordinator: Coordinator of the poll.
    /// @param encryptionKey: Key to encrypt the poll votes.
    event PollStarted(
        uint256 pollId,
        address indexed coordinator,
        uint256 encryptionKey
    );

    /// @dev Emitted when a user votes on a poll.
    /// @param pollId: Id of the poll.
    /// @param vote: User encrypted vote.
    event VoteAdded(uint256 indexed pollId, uint256 vote);

    /// @dev Emitted when a poll is ended.
    /// @param pollId: Id of the poll.
    /// @param coordinator: Coordinator of the poll.
    /// @param decryptionKey: Key to decrypt the poll votes.
    event PollEnded(
        uint256 pollId,
        address indexed coordinator,
        uint256 decryptionKey
    );

    /// @dev Gets a poll id and returns the poll data.
    mapping(uint256 => Poll) internal $polls;

    /// @dev Checks if the poll coordinator is the transaction sender.
    /// @param pollId: Id of the poll.
    modifier onlyCoordinator(uint256 pollId) {
        require($polls[pollId].coordinator == msg.sender, "Only coordinator");
        _;
    }

    constructor(
        IFriendtechSharesV1 _ft,
        ISemaphoreVerifier _verifier,
        uint256 _depth
    ) {
        $friendTech = _ft;
        $verifier = _verifier;
        TREE_DEPTH = _depth;
    }

    /// @notice Create a poll for the Friend.Tech key holders of your account
    function createpoll(uint256 pollId, uint256 encryptionKey) external {
        // It will revert if pollId already exists
        _createGroup(pollId, TREE_DEPTH);
        $polls[pollId].coordinator = msg.sender;
        emit PollCreated(pollId, msg.sender);
    }

    /// @notice Start the poll
    function startPoll(
        uint256 pollId,
        uint256 encryptionKey
    ) public onlyCoordinator(pollId) {
        require($polls[pollId].state != PollState.Created, "Poll has started");
        $polls[pollId].state = PollState.Ongoing;
        emit PollStarted(pollId, msg.sender, encryptionKey);
    }

    /// @notice Join a poll of a person for whom you own keys in Friend.Tech
    function joinPoll(
        uint pollId,
        address subject,
        uint256 identityCommitment
    ) public {
        // Semaphore requires
        require($polls[pollId].state == PollState.Created, "Poll has started");
        // FT requires
        require(
            $polls[pollId].coordinator != subject,
            "pollId belongs to another subject"
        );
        require(
            $friendTech.sharesBallance(subject, msg.sender) > 0,
            "sender doesn't own any keys of subject"
        );
        _addMember(pollId, identityCommitment);
    }

    function castVote(
        uint256 vote,
        uint256 nullifierHash,
        uint256 pollId,
        uint256[8] calldata proof
    ) public {
        require(
            $polls[pollId].state == PollState.Ongoing,
            "Poll is not ongoing"
        );
        require(
            !$polls[pollId].nullifierHashes[nullifierHash],
            "nullifier already used"
        );

        uint256 merkleTreeDepth = getMerkleTreeDepth(pollId);
        uint256 merkleTreeRoot = getMerkleTreeRoot(pollId);

        $verifier.verifyProof(
            merkleTreeRoot,
            nullifierHash,
            vote,
            pollId,
            proof,
            merkleTreeDepth
        );

        $polls[pollId].nullifierHashes[nullifierHash] = true;

        emit VoteAdded(pollId, vote);
    }

    function endPoll(
        uint256 pollId,
        uint256 decryptionKey
    ) public onlyCoordinator(pollId) {
        require(
            $polls[pollId].state == PollState.Ongoing,
            "Poll is not ongoing"
        );

        $polls[pollId].state = PollState.Ended;

        emit PollEnded(pollId, _msgSender(), decryptionKey);
    }
}
