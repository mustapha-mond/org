pragma solidity ^0.5.16;

interface intOrg{
    function _isUser (address _user) external view returns (bool);
    function _isPartExtReg (address _user, address _msgSender) external view returns (bool);
    function _isExtPartReg (address _user, address _extPartner, address _msgSender) external view returns (bool);
    function getAppovalLevel (address _user, address _partner, uint _amount, uint txn) external returns (address);
    function _isAppTxn (address _user, address _partner, uint _txn) external view returns (bool);
    function updateAppList (address _user, address _partner, uint _txn) external returns (bool);
}

contract org {
   
    address owner; 
   
    enum PTYPE {I,E,U} //Internal, External, User Partner

    struct User {
        string name;
        uint index;
        address[] aliases;
        mapping (address => uint) unlinked;
        address[] unlinkedIdx;
        mapping (address => uint) partnerPointers; //Partners
        address[] partnerIdx;
    }
   
    mapping (address => User) users;
    address[] userIdx;
 
    struct Partner {
        string name;
        uint limit;
        uint balance;
        address payee; //If partner is another user e.g. External then specify the account of that user is payee. Can validate.
        bool linked;
        uint index;
        bool canReg;
        PTYPE ptype;
        mapping (uint => uint) toApprovePointers;
        uint[] toApproveIdx;
        address[] aliases; // Example: Partner can use a different alias for each transaction  
        mapping (address => uint) dottedPointersUp; //Dotted Partners Up
        address[] dottedIdxUp;
        mapping (address => uint) dottedPointersDown; //Dotted Partners Down
        address[] dottedIdxDown;
        mapping (address => uint) partnerPointers; //Lower level Partners
        address[] partnerIdx;
        mapping (address => uint) extPartnerPointers; //External Partners
        address[] extPartnerIdx;
        mapping (address => uint) intPartnerPointers; //Internal/External Partners
        address[] intPartnerIdx;
    }
   
    mapping (address => mapping(address => Partner)) partners; //Users to Partners
   
    struct extPartner {
        string name;
        uint index;
    }
   
    mapping (address => mapping(address => mapping(address => extPartner))) extPartners;
   
    struct Link {
        address ownerNode;
    }

    mapping (address => mapping (address => Link)) links; //Migrate upwards
   
//Modifiers
    modifier onlyOwner () {
      require(msg.sender == owner,'Error: Only owner can register Users');
      _;
    }
   
    modifier isNotUser(address _user){
        require(!_isUser(_user),'Error: User already registered');
        _;
    }
   
//Declare Events here    

    constructor () public {
        owner = msg.sender;
    }
   
    function _isUser (address _user) public view returns (bool) {
        if (userIdx.length == 0 ) return false;
        return (userIdx[users[_user].index] == _user);
    }
   
    function regUser (address _user, string calldata _name) external onlyOwner isNotUser(_user) returns (bool) {
        users[_user].name = _name;
        users[_user].index = userIdx.push(_user) - 1;
        return true;
    }
   
    function changeUser (address _user, string calldata  _name) external onlyOwner returns (bool) {
        require(_isUser(_user),'Error: User not registered');
        users[_user].name = _name;
        return true;
    }
   
    function getUser (address _user) external view onlyOwner returns (string memory){
        require(_isUser(_user),'Error: User not registered');
        return (users[_user].name);
    }
   
    function countUsers () external view onlyOwner returns (uint) {
        return userIdx.length;
    }    
   
    function _isRegistered (address _partner, address _msgSender) public view returns (bool) {
       if(users[_msgSender].partnerIdx.length == 0) return false;
       return (users[_msgSender].partnerIdx[partners[_msgSender][_partner].index] == _partner);
    }

    function regPartner (address _partner, string calldata _name , uint _limit, bool _canReg)
                        external returns (bool) {
        require (_isUser(msg.sender),'Error: User not registered');
        require (!_isRegistered(_partner, msg.sender),'Error: Partner already registered for this user');
        partners[msg.sender][_partner].name = _name;
        partners[msg.sender][_partner].limit = _limit;
        partners[msg.sender][_partner].canReg = _canReg;
        partners[msg.sender][_partner].ptype = PTYPE(0);
        uint idx = users[msg.sender].partnerIdx.push(_partner) - 1;
        users[msg.sender].partnerPointers[_partner] = idx;
        partners[msg.sender][_partner].index = idx;
        return true;
     }
     
    function changePartner (address _partner, string calldata _name)  external returns (bool) {
        require (_isUser(msg.sender),'Error: User not registered');
        require (_isRegistered(_partner, msg.sender),'Error: Partner not registered for this user');
        partners[msg.sender][_partner].name = _name;
        return true;
     }    
   
    function getPartner (address _partner) external view
            returns (string memory, bool, address[] memory, address[] memory, uint[] memory) {
        require (_isUser(msg.sender),'Error: User not registered');
        require (_isRegistered(_partner, msg.sender),'Error: Partner not registered for this user');
        return (partners[msg.sender][_partner].name,
                partners[msg.sender][_partner].linked,
                partners[msg.sender][_partner].partnerIdx,
                partners[msg.sender][_partner].dottedIdxUp,
                partners[msg.sender][_partner].toApproveIdx);
     }    
   
    function countPartners () external view returns (uint) {
        require(_isUser(msg.sender),'Error: User not registered');
        return users[msg.sender].partnerIdx.length;
    }

//Check that registering Partner is assigned to User
    function _isPartExtReg (address _user, address  _msgSender) public view returns (bool) {
       if (users[_user].partnerIdx.length == 0) return false;
       return (users[_user].partnerIdx[partners[_user][_msgSender].index] == _msgSender);
    }
   
//Check if External Partner already registered    
    function _isExtPartReg (address _user, address _extPartner, address _msgSender) public view returns (bool) {
        if (partners[_user][_msgSender].extPartnerIdx.length == 0) return false;
        return (partners[_user][_msgSender].extPartnerIdx[extPartners[_user][_msgSender][_extPartner].index] == _extPartner);
    }
   
//Check that External Partner not already an Internal Partner    
    function _isExtInt (address _user, address _extPartner) internal view returns (bool) {
        if (users[_user].partnerIdx.length == 0) return false;
        return (users[_user].partnerIdx[partners[_user][_extPartner].index] == _extPartner &&
                partners[_user][_extPartner].ptype == PTYPE(0));
    }
   
    function _isExtReg (address _user, address _extPartner) public view returns (bool) {
        if (users[_user].partnerIdx.length == 0) return false;
       return (users[_user].partnerIdx[partners[_user][_extPartner].index] == _extPartner);
    }
   
//Message sender is Partner    
    function regExtPartner (address _user, address _extPartner, string calldata _name)
                            external returns (bool) {
        require (_isUser(_user),'Error: User not registered');
        require (_isPartExtReg(_user, msg.sender),'Error: Partner not registered for this user');
        require (!_isExtPartReg(_user, _extPartner, msg.sender),'Error: External partner already registered');
        require (partners[_user][msg.sender].canReg,'Error: Parter cannot register external partners');
        require (!_isExtInt(_user, _extPartner), 'Error: External partner already registered as internal');
       
        extPartners[_user][msg.sender][_extPartner].name = _name;
        uint iEdx = partners[_user][msg.sender].extPartnerIdx.push(_extPartner) - 1;
        partners[_user][msg.sender].extPartnerPointers[_extPartner] = iEdx;
        extPartners[_user][msg.sender][_extPartner].index = iEdx;
       
        if (!_isExtReg (_user, _extPartner)){
            partners[_user][_extPartner].name = 'External';
            if (_isUser(_user)) {
               partners[_user][_extPartner].ptype = PTYPE(2);
            } else {
                partners[_user][_extPartner].ptype = PTYPE(1);
            }
            uint idx = users[_user].partnerIdx.push(_extPartner) - 1;
            users[_user].partnerPointers[_extPartner] = idx;
            partners[_user][_extPartner].index = idx;    
        }
       
        uint iIdx = partners[_user][_extPartner].intPartnerIdx.push(msg.sender) - 1;
        partners[_user][_extPartner].intPartnerPointers[msg.sender] = iIdx;

        return true;
     }
     
    function _isLinked (address _partner, address _linkPartner) public view returns (bool){
        require (_isUser(msg.sender),'Error: User not registered');
        if (partners[msg.sender][_partner].partnerIdx.length == 0) return false;
        return (partners[msg.sender][_partner].partnerIdx[partners[msg.sender][_partner].partnerPointers[_linkPartner]] == _linkPartner);
    }

    function _isDottedLinked (address _partner, address _linkPartner) public view returns (bool){
        require (_isUser(msg.sender),'Error: User not registered');
        if (partners[msg.sender][_linkPartner].dottedIdxUp.length == 0) return false;
        return (partners[msg.sender][_linkPartner].dottedIdxUp[partners[msg.sender][_linkPartner].dottedPointersUp[_partner]] == _partner);
    }
       
    function linkPartner (address _partner, address _linkPartner) external returns (bool) {
        require (_isUser(msg.sender),'Error: User not registered');
        require (_isRegistered(_partner, msg.sender),'Error: Partner not registered for this user');
        require (_isRegistered(_linkPartner, msg.sender),'Error: Link Partner not registered for this user');
        require (_partner != _linkPartner,'Error: Cannot link to self');
        require (!_isLinked(_partner, _linkPartner),'Error: Partner link already exists');
        require (partners[msg.sender][_partner].ptype == PTYPE(0),'Error: External partners cannot be linked');
        require (partners[msg.sender][_linkPartner].ptype == PTYPE(0),'Error: External partners cannot be linked');
       
        uint partnerLevel = getLevel(_partner);
        uint linkPartLevel = getLevel(_linkPartner);
       
        if (linkPartLevel == 0 && !partners[msg.sender][_linkPartner].linked) {
            require(partners[msg.sender][_partner].limit > partners[msg.sender][_linkPartner].limit,'Error: Link partner has a higher limit');
            partners[msg.sender][_partner].linked = true;
            partners[msg.sender][_partner].partnerPointers[_linkPartner] =
            partners[msg.sender][_partner].partnerIdx.push(_linkPartner) - 1;
            links[msg.sender][_linkPartner].ownerNode = _partner;
        } else {
            require (!_isDottedLinked(_partner, _linkPartner),'Error: Dotted link already exists');
            if (linkPartLevel > partnerLevel) {
                partners[msg.sender][_linkPartner].dottedPointersUp[_partner] =
                partners[msg.sender][_linkPartner].dottedIdxUp.push(_partner) - 1;
                partners[msg.sender][_partner].dottedPointersDown[_linkPartner] =
                partners[msg.sender][_partner].dottedIdxDown.push(_linkPartner) - 1;
            } else revert ('Error: Invlalid hierarchy');
        }
    }
   
    function getOwnerNode (address _partner) external view returns (address){
        return (links[msg.sender][_partner].ownerNode);
    }
       
    function getLevel(address _partner) internal view returns (uint) {
        uint level;
        address levelUp = links[msg.sender][_partner].ownerNode;
        while (true) {
            if (levelUp == address(0)) return level;
            levelUp = links[msg.sender][levelUp].ownerNode;
            level++;
        }
    }
    
//Migrate up to get approval node      
    function getAppovalLevel (address _user, address _partner, uint _amount, uint _txn) external returns (address) {
        require (_isUser(_user),'Error: User not registered');
        require (_isRegistered(_partner, _user),'Error: Partner not registered for this user');
        address levelUp = _partner;
        while (true) {
            if (partners[_user][levelUp].limit >= _amount) {
                uint idx = partners[_user][levelUp].toApproveIdx.push(_txn) - 1;
                partners[_user][levelUp].toApprovePointers[_txn] = idx;
                return levelUp;
            }
            levelUp = links[_user][levelUp].ownerNode;
            if (levelUp == address(0)) return _user;
        }
    }
       
    function _isAppTxn (address _user, address _partner, uint _txn) external view returns (bool) {
        require (_isUser(_user),'Error: User not registered');
        require (_isRegistered(_partner, _user),'Error: Partner not registered for this user');
        if (partners[_user][_partner].toApproveIdx.length == 0) return false;
        return (partners[_user][_partner].toApproveIdx[partners[_user][_partner].toApprovePointers[_txn]] == _txn);
    }
       
    function updateAppList (address _user, address _partner, uint _txn) external returns (bool){
        require (_isUser(_user),'Error: User not registered');
        require (_isRegistered(_partner, _user),'Error: Partner not registered for this user');
        uint rowToDelete = partners[_user][_partner].toApprovePointers[_txn];
        uint keyToMove = partners[_user][_partner].toApproveIdx[partners[_user][_partner].toApproveIdx.length -1];
        partners[_user][_partner].toApproveIdx[rowToDelete] = keyToMove;
        delete partners[_user][_partner].toApprovePointers[_txn];
        partners[_user][_partner].toApproveIdx.pop();
        return true;
    }
}

