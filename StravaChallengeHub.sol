pragma solidity 0.4.24;

contract StravaChallengeHub {
    // Libraries

    // Enums
    // https://solidity.readthedocs.io/en/v0.5.4/types.html?highlight=enum%20argument#enums
    enum ActivityType { Ride, Run, Swim }     // Strava activity type
    enum ChallengeType { Segment, Distance }  // Type of challenge
    
    // Structs
    struct SegmentChallenge {
        uint entryFee;              // amount ether to enter the challenge
        uint expireTime;            // datetime that challenge expires at (seconds)
        uint timeToBeat;            // time to complete segment in (seconds)
        uint segmentId;           // strava segment id
        ActivityType activityType;  // ride / run / swim (as uint)
    }
    struct DistanceChallenge {
        uint entryFee;              // amount ether to enter the challenge
        uint expireTime;            // datetime that challenge expires at (seconds)
        uint distance;              // distance to complete the challenge (feet)
        ActivityType activityType;  // ride / run / swim (as uint)
    }
    struct ChallengeMetaData {
        uint numChallenges;
        mapping (uint => bool) settled;
        mapping (uint => uint[]) athleteIds;
        mapping (uint => mapping(uint => bool)) athleteSucceeded;
        mapping (uint => mapping(uint => address)) athleteAddress;
    }

    // Storage vars
    mapping (uint => ChallengeMetaData) public challengeManager;
    mapping (uint => SegmentChallenge) public segmentChallengesById;
    mapping (uint => DistanceChallenge) public distanceChallengesById;

    // Events
    event ChallengeIssued (ChallengeType _challengeType, uint _challengeId);
    event ChallengeJoined (ChallengeType _challengeType, uint _challengeId, uint _athleteId, address _athleteAddress);
    event ChallengeSettled (ChallengeType _challengeType, uint _challengeId);
    event AthleteSucceeded (ChallengeType _challengeType, uint _challengeId, uint _athleteId);

    // Pure / View functions
    // ------------------------------------------------------
    function _getChallengeMetaData(ChallengeType _challengeType) internal view returns (ChallengeMetaData storage) {
        return challengeManager[uint(_challengeType)];
    }
    
    function isChallengeSettled(ChallengeType _challengeType, uint _challengeId) public view returns (bool) {
        return _getChallengeMetaData(_challengeType).settled[_challengeId];
    }
    
    function isAthleteRegistered(ChallengeType _challengeType, uint _challengeId, uint _athleteId) public view returns (bool) {
        return _getChallengeMetaData(_challengeType).athleteAddress[_challengeId][_athleteId] != address(0x0);
    }

    function isAthleteSuccessful(ChallengeType _challengeType, uint _challengeId, uint _athleteId) public view returns (bool) {
        return _getChallengeMetaData(_challengeType).athleteSucceeded[_challengeId][_athleteId];
    }
    
    function getNumAthletes(ChallengeType _challengeType, uint _challengeId) public view returns (uint) {
        return _getChallengeMetaData(_challengeType).athleteIds[_challengeId].length;
    }
    
    function getAthleteIdAtIndex(ChallengeType _challengeType, uint _challengeId, uint index) public view returns (uint) {
        return _getChallengeMetaData(_challengeType).athleteIds[_challengeId][index];
    }
    
    function getAthleteAddress(ChallengeType _challengeType, uint _challengeId, uint _athleteId) public view returns (address paybale) {
        return _getChallengeMetaData(_challengeType).athleteAddress[_challengeId][_athleteId];
    }

    function isSegmentChallenge(ChallengeType _challengeType) public pure returns (bool) {
        return _challengeType == ChallengeType.Segment;
    }
    
    function isDistanceChallenge(ChallengeType _challengeType) public pure returns (bool) {
        return _challengeType == ChallengeType.Distance;
    }

    function getChallengeExpireTime(ChallengeType _challengeType, uint _challengeId) public view returns (uint) {
        if (isSegmentChallenge(_challengeType))
            return segmentChallengesById[_challengeId].expireTime;
        if (isDistanceChallenge(_challengeType))
            return distanceChallengesById[_challengeId].expireTime;
    }
    
    function getChallengeEntryFee(ChallengeType _challengeType, uint _challengeId) public view returns (uint) {
        if (isSegmentChallenge(_challengeType))
            return segmentChallengesById[_challengeId].entryFee;
        if (isDistanceChallenge(_challengeType))
            return distanceChallengesById[_challengeId].entryFee;
    }
    
    function isChallengeExpired(ChallengeType _challengeType, uint _challengeId) public view returns (bool) {
        uint expireTime = getChallengeExpireTime(_challengeType, _challengeId);
        return now > expireTime;
    }

    function getAthleteIds(ChallengeType _challengeType, uint _challengeId) public view returns (uint[] memory) {
        return _getChallengeMetaData(_challengeType).athleteIds[_challengeId];
    }
    
    function getSuccessfulAthleteIds(ChallengeType _challengeType, uint _challengeId) public view returns (uint[] memory) {
        uint[] memory successfulAthleteIds;
        uint numAthletes = getNumAthletes(_challengeType, _challengeId);
        uint resultIndex = 0;
        
        // iterate over athlete ids, push successful ones to array
        for (uint index; index < numAthletes; index++) {
            uint _athleteId = getAthleteIdAtIndex(_challengeType, _challengeId, index);
            if (isAthleteSuccessful(_challengeType, _challengeId, _athleteId)) {
                successfulAthleteIds[resultIndex] = _athleteId;
                resultIndex++;
            }
        }
        
        return successfulAthleteIds;
    }
    
    function getTotalChallengeFunds(ChallengeType _challengeType, uint _challengeId) public view returns (uint) {
        uint entryFee = getChallengeEntryFee(_challengeType, _challengeId);
        uint numAthletes = getNumAthletes(_challengeType, _challengeId);
        return entryFee * numAthletes;
    }
    
    // Destructive functions
    // ------------------------------------------------------
    function issueSegmentChallenge(
        uint _entryFee,
        uint _expireTime,
        uint _timeToBeat,
        uint _segmentId,
        ActivityType _activityType
    ) public returns (uint) {
        // initialize SegmentChallenge struct
        SegmentChallenge memory issuedSegmentChallenge = SegmentChallenge({
            entryFee: _entryFee,
            expireTime: _expireTime,
            timeToBeat: _timeToBeat,
            segmentId: _segmentId,
            activityType: _activityType
        });
        
        // Get the challenge id from the number of challenges
        uint _challengeId = _getChallengeMetaData(ChallengeType.Segment).numChallenges;
        
        // Add struct to challenges mapping
        segmentChallengesById[_challengeId] = issuedSegmentChallenge;
        
        // Increment the counter
        challengeManager[uint(ChallengeType.Segment)].numChallenges++;
        
        // Log ChallengeIssued event
        emit ChallengeIssued(ChallengeType.Segment, _challengeId);
        
        // return challengeId
        return _challengeId;
    }
    
    function issueDistanceChallenge(
        uint _entryFee,
        uint _expireTime,
        uint _distance,
        ActivityType _activityType
    ) public returns (uint) {
        // initialize DistanceChallenge struct
        DistanceChallenge memory issuedDistanceChallenge = DistanceChallenge({
            entryFee: _entryFee,
            expireTime: _expireTime,
            distance: _distance,
            activityType: _activityType
        });
        
        // Get the challenge id from the number of challenges
        uint _challengeId = _getChallengeMetaData(ChallengeType.Distance).numChallenges;
        
        // Add struct to challenges mapping
        distanceChallengesById[_challengeId] = issuedDistanceChallenge;
        
        // Increment the counter
        challengeManager[uint(ChallengeType.Distance)].numChallenges++;
        
        // Log ChallengeIssued event
        emit ChallengeIssued(ChallengeType.Distance, _challengeId);
        
        // return challengeId
        return _challengeId;
    }
    

    function joinChallenge (
        ChallengeType _challengeType,
        uint _challengeId,
        uint _athleteId
    ) public payable returns (bool) {
        // make sure challenge is not expired
        require(!isChallengeExpired(_challengeType, _challengeId));
        
        // make sure athlete hasn't joined the challenge already
        require(!isAthleteRegistered(_challengeType, _challengeId, _athleteId), "Athlete is already registered");

        // make sure sender is paying their full entry fee
        uint entryFee = getChallengeEntryFee(_challengeType, _challengeId);
        require(msg.value >= entryFee, "Entry fee (ether value) is insufficient");
    
        // flag athelete as registered for challenge
        challengeManager[uint(_challengeType)].athleteAddress[_challengeId][_athleteId] = msg.sender;

        // Log ChallengeJoined event
        emit ChallengeJoined(_challengeType, _challengeId, _athleteId, msg.sender);
        
        return true;
    }
    
    // TODO: Permissions
    function setAthleteSucceeded(
        ChallengeType _challengeType,
        uint _challengeId,
        uint _athleteId
    ) external returns (bool) {
        // check that challenge is not settled and the athlete is registered
        require(!isChallengeSettled(_challengeType, _challengeId));
        require(isAthleteRegistered(_challengeType, _challengeId, _athleteId));
        
        // flag athlete as successful
        challengeManager[uint(_challengeType)].athleteSucceeded[_challengeId][_athleteId] = true;
        
        // log AthleteSuceeded event
        emit AthleteSucceeded(_challengeType, _challengeId, _athleteId);
        
        return true;
    }
    
    // TODO: Permissions
    function settleChallenge (
        ChallengeType _challengeType,
        uint _challengeId
    ) external returns (bool) {
        // make sure challenge is expired and not settled
        require(isChallengeExpired(_challengeType, _challengeId));
        require(!isChallengeSettled(_challengeType, _challengeId));
        
        uint[] memory successfulAthleteIds = getSuccessfulAthleteIds(_challengeType, _challengeId);
        uint numAthletesSucceeded = successfulAthleteIds.length;
        uint totalChallengeFunds = getTotalChallengeFunds(_challengeType, _challengeId);
        uint rewardValue = totalChallengeFunds / numAthletesSucceeded;
        
        for (uint index = 0; index < numAthletesSucceeded; index++) {
            uint _athleteId = successfulAthleteIds[index];
            address _athleteAddress = getAthleteAddress(_challengeType, _challengeId, _athleteId);
            address recipient = address(uint160(_athleteAddress));
            recipient.transfer(rewardValue);
        }
        
        // flag challenge as settled
        challengeManager[uint(_challengeType)].settled[_challengeId] = true;
        
        // emit ChallengeSettled event
        emit ChallengeSettled(_challengeType, _challengeId);

        return true;
    }
}
