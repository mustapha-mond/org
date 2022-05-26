pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;
 
import '../client/node_modules/@openzeppelin/contracts/token/ERC20/IERC20.sol';  

interface intOrg {

    function _isUser(address _user) external view returns (bool);

    function _isPartExtReg(address _user, address _msgSender) external view returns (bool);

    function _isExtPartReg(address _user,address _extPartner,address _msgSender) external view returns (bool);

    function getAppovalLevel(address _user,address _partner, address _extPartner, uint256 _amount,uint256 txn) external returns (address);

    function updateTxnList(address _user,address _partner, address _extPartner, uint256 _txn, uint _amount, uint _action) external returns (bool);

    function getPayee(address _user,address _msgSender,address _extPartner) external view returns (address payable);

    function pay(address _user,address payable _extPartner,uint256 _poAmount) external returns (bool);
}

contract org {

    IERC20 dai;

    address owner; //Owner = me

    enum PTYPE {U, I, E, P} //Internal, External, User Partner
    enum STAGE {IN, TA, TS, TR, TP, PD} // Initial, To Approve, To Ship, To Receive, To Pay
    enum STATUS {IN, AP, RJ} // Approved, Rejected

    event status(address indexed _user, address indexed _partner, address indexed _ext_partner, uint txn, uint _value, STAGE _stage);
  
    struct Transaction{
        address approver;
        address shipper;
        address payer;
        bool direction;
        uint amount;
        STATUS status;
        STAGE stage;
        uint256 index;
        address user;
        address extPartner;
    }
    
    struct TxnPointer {
        address user;
        address partner;
        address extPartner;
        uint256 txn;
    }

    struct TxnInt {
        address user;
        address partner;
        address extPartner;
        uint256 txn;
        address approver;
        bool approved;
        bool direction;
        uint amount;
        STATUS status;
        STAGE stage;
        address shipper;
        address payer;
    }
    
    //User, Partner, External Partner, Transaction
    mapping (address => mapping(address => mapping(address => mapping(uint256 => Transaction)))) txns; 
    TxnPointer[] txnIdx;

    struct User {
        string name;
        uint256 index;
        uint256 regCount;
        uint256 bal;
        address defShip;
        address[] aliases;
        uint256[] txns;
        mapping(address => uint256) unlinked;
        address[] unlinkedIdx;
        mapping(address => uint256) partnerPointers; //Partners
        address[] partnerIdx;
    }

    mapping(address => User) users;
    address[] userIdx;
    
    struct Partner {
        string name;
        uint256 limit;
        uint256 balance;
        address payable payee; //If partner is another user e.g. External then specify the account of that user is payee. Can validate.
        bool linked;
        uint256 index;
        uint256 regCount;
        bool canReg;
        PTYPE ptype;
        uint [] txns;
        address[] aliases; // Example: Partner can use a different alias for each transaction
        mapping(address => uint256) dottedPointersUp; //Dotted Partners Up
        address[] dottedIdxUp;
        mapping(address => uint256) dottedPointersDown; //Dotted Partners Down
        address[] dottedIdxDown;
        mapping(address => uint256) partnerPointers; //Lower level Partners
        address[] partnerIdx;
        mapping(address => uint256) extPartnerPointers; //External Partners
        address[] extPartnerIdx;
        mapping(address => uint256) intPartnerPointers; //Internal/External Partners
        address[] intPartnerIdx;
    }

    mapping(address => mapping(address => Partner)) public partners; //Users to Partners

    struct extPartner {
        string name;
        address payable payee; //If partner is another user e.g. External then specify the account of that user is payee. Can validate.
        uint256 index;
    }

    mapping(address => mapping(address => mapping(address => extPartner))) extPartners;

    struct Link {
        address ownerNode;
    }

    mapping(address => mapping(address => Link)) links; //Migrate upwards

    //Keep track of Users per Partner
    struct contractPartner {
        address[] users;
    }

    mapping(address => contractPartner) contractPartners;
    
    //Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Error: Only owner can register Users");
        _;
    }

    modifier isNotUser(address _user) {
        require(!_isUser(_user), "Error: User already registered");
        _;
    }

    //Declare Events here

    constructor(address daiAddress) public {
        dai = IERC20(daiAddress);
        owner = msg.sender;
    }

    // function getChainID() external view returns (uint256) {
    // uint256 id;
    // assembly {
    //     id := chainid()
    // }
    // return id;
    // }       

    function _isUser(address _user) public view returns (bool) {
        if (userIdx.length == 0) return false;
        return (userIdx[users[_user].index] == _user);
    }

    function regUser(address _user, string calldata _name) external onlyOwner isNotUser(_user)returns (bool) {
        users[_user].name = _name;
        users[_user].regCount += 1;
        userIdx.push(_user);
        users[_user].index = userIdx.length - 1;
        return true;
    }

    function changeUser(address _user, string calldata _name) external onlyOwner returns (bool){
        require(_isUser(_user), "Error: User not registered");
        users[_user].name = _name;
        return true;
    }

    function getUser(address _user) external view returns (string memory, uint256, uint[] memory, address[] memory, address) {
        require(_isUser(_user), "Error: User not registered");
        return (users[_user].name, 
        users[_user].bal, 
        users[_user].txns, 
        users[_user].partnerIdx,
        users[_user].defShip);
    }

    function getUserBal(address _user) external view returns (uint256) {
        require(_isUser(_user), "Error: User not registered");
        return (users[_user].bal);
    }

    function getUserName(address _user) external view returns (string memory) {
        require(_isUser(_user), "Error: User not registered");
        return (users[_user].name);
    }

    function countUsers() external view onlyOwner returns (uint256) {
        return userIdx.length;
    }

    function _isRegistered(address _partner, address _msgSender) public view returns (bool){
        if (users[_msgSender].partnerIdx.length == 0) return false;
        return (users[_msgSender].partnerIdx[partners[_msgSender][_partner]
            .index] == _partner);
    }

    function _isContractPartner(address _partner) public view returns (bool) {
        if (contractPartners[_partner].users.length > 0) return true;
        else {
            return false;
        }
    }

    function getPartnerUser (address _partner) public view returns (address) {
        return contractPartners[_partner].users[0];
        
    }

    function regPartner(address _partner,string calldata _name,uint256 _limit, bool _canReg, bool _defShip) external returns (bool) {
        require(_isUser(msg.sender), "Error: User not registered");
        require(!_isRegistered(_partner, msg.sender),"Error: Partner already registered for this user");
        partners[msg.sender][_partner].name = _name;
        partners[msg.sender][_partner].limit = _limit;
        partners[msg.sender][_partner].canReg = _canReg;
        partners[msg.sender][_partner].ptype = PTYPE(3);
        partners[msg.sender][_partner].regCount += 1;
        if (_defShip) {users[msg.sender].defShip = _partner;}
            users[msg.sender].partnerIdx.push(_partner);
            uint256 idx = users[msg.sender].partnerIdx.length - 1;
            users[msg.sender].partnerPointers[_partner] = idx;
            partners[msg.sender][_partner].index = idx;
            contractPartners[_partner].users.push(msg.sender);
        return true;
    }

    function changePartner(address _partner, string calldata _name) external returns (bool) {
        require(_isUser(msg.sender), "Error: User not registered");
        require(_isRegistered(_partner, msg.sender), "Error: Partner not registered for this user");
        partners[msg.sender][_partner].name = _name;
        return true;
    }

    function getPartner(address _partner) external view returns (string memory,bool,address[] memory,address[] memory, uint[] memory, uint, PTYPE ){
        require(_isUser(msg.sender), "Error: User not registered");
        require(_isRegistered(_partner, msg.sender),"Error: Partner not registered for this user");
        return (
            partners[msg.sender][_partner].name,
            partners[msg.sender][_partner].linked,
            partners[msg.sender][_partner].partnerIdx,
            partners[msg.sender][_partner].extPartnerIdx,
            partners[msg.sender][_partner].txns,
            partners[msg.sender][_partner].limit,
            partners[msg.sender][_partner].ptype
        );
    }

    function getAccountType(address _partner) public view returns (uint256) {
        uint256 atype = 0;
        if (_partner == owner) atype = 1;
        else {
            if (_isUser(_partner)) {
                atype = 2;}
                else {
                    if (_isContractPartner(_partner)) {atype = 3;}
                }
            }
            return (atype);
    }

    function countPartners() external view returns (uint256) {
        require(_isUser(msg.sender), "Error: User not registered");
        return users[msg.sender].partnerIdx.length;
    }

    //Check that registering Partner is assigned to User
    function _isPartExtReg(address _user, address _msgSender) public view returns (bool) {
        if (users[_user].partnerIdx.length == 0) return false;
        return (users[_user].partnerIdx[partners[_user][_msgSender].index] == _msgSender);
    }

    //Check if External Partner already registered
    function _isExtPartReg(address _user,address _extPartner,address _msgSender) public view returns (bool) {
        if (partners[_user][_msgSender].extPartnerIdx.length == 0) return false;
        return (partners[_user][_msgSender]
            .extPartnerIdx[extPartners[_user][_msgSender][_extPartner].index] ==
            _extPartner);
    }

    //Check that External Partner not already an Internal Partner
    function _isExtInt(address _user, address _extPartner) internal view returns (bool){
        if (users[_user].partnerIdx.length == 0) return false;
        return (users[_user].partnerIdx[partners[_user][_extPartner].index] == _extPartner && partners[_user][_extPartner].ptype == PTYPE(3));
    }

    function _isExtReg(address _user, address _extPartner) public view returns (bool){
        if (users[_user].partnerIdx.length == 0) return false;
        return (users[_user].partnerIdx[partners[_user][_extPartner].index] == _extPartner);
    }

    //Message sender is Partner
    function regExtPartner(address _user,address _extPartner,address payable _payee,string calldata _name) external returns (bool) {
        require(_isUser(_user), "Error: User not registered");
        require(_isPartExtReg(_user, msg.sender), "Error: Partner not registered for this user");
        require(!_isExtPartReg(_user, _extPartner, msg.sender),"Error: External partner already registered");
        require(partners[_user][msg.sender].canReg,"Error: Parter cannot register external partners");
        require(!_isExtInt(_user, _extPartner),"Error: External partner already registered as internal");

        extPartners[_user][msg.sender][_extPartner].name = _name;
        extPartners[_user][msg.sender][_extPartner].payee = _payee;
        partners[_user][msg.sender].extPartnerIdx.push(_extPartner);
        uint256 iEdx = partners[_user][msg.sender].extPartnerIdx.length - 1;
        partners[_user][msg.sender].extPartnerPointers[_extPartner] = iEdx;
        extPartners[_user][msg.sender][_extPartner].index = iEdx;

        if (!_isExtReg(_user, _extPartner))
            {partners[_user][_extPartner].name = _name;
            if (_isUser(_extPartner)) {
                partners[_user][_extPartner].ptype = PTYPE(2);
            } else {
                partners[_user][_extPartner].ptype = PTYPE(1);
            }
            users[_user].partnerIdx.push(_extPartner);
            uint256 idx = users[_user].partnerIdx.length - 1;
            users[_user].partnerPointers[_extPartner] = idx;
            partners[_user][_extPartner].index = idx;
        }
        partners[_user][_extPartner].intPartnerIdx.push(msg.sender);
        uint256 iIdx = partners[_user][_extPartner].intPartnerIdx.length - 1;
        partners[_user][_extPartner].intPartnerPointers[msg.sender] = iIdx;

        return true;
    }

    function getPayee(address _user,address _msgSender,address _extPartner) external view returns (address payable) {
        return (extPartners[_user][_msgSender][_extPartner].payee);
    }

    function _isLinked(address _partner, address _linkPartner) public view returns (bool)
    {
        require(_isUser(msg.sender), "Error: User not registered");
        if (partners[msg.sender][_partner].partnerIdx.length == 0) return false;
        return (partners[msg.sender][_partner].partnerIdx[partners[msg.sender][_partner].partnerPointers[_linkPartner]] == _linkPartner);
    }

    function _isDottedLinked(address _partner, address _linkPartner) public view returns (bool) {
        require(_isUser(msg.sender), "Error: User not registered");
        if (partners[msg.sender][_linkPartner].dottedIdxUp.length == 0) return false;
        return (partners[msg.sender][_linkPartner].dottedIdxUp[partners[msg.sender][_linkPartner].dottedPointersUp[_partner]] == _partner);
    }

    function linkPartner(address _partner, address _linkPartner) external returns (bool){
        require(_isUser(msg.sender), "Error: User not registered");
        require(_isRegistered(_partner, msg.sender),"Error: Partner not registered for this user");
        require(_isRegistered(_linkPartner, msg.sender),"Error: Link Partner not registered for this user");
        require(_partner != _linkPartner, "Error: Cannot link to self");
        require(!_isLinked(_partner, _linkPartner),"Error: Partner link already exists");
        require(partners[msg.sender][_partner].ptype == PTYPE(3),"Error: External partners cannot be linked");
        require(partners[msg.sender][_linkPartner].ptype == PTYPE(3),"Error: External partners cannot be linked");

        uint256 partnerLevel = getLevel(_partner);
        uint256 linkPartLevel = getLevel(_linkPartner);

        if (linkPartLevel == 0 && !partners[msg.sender][_linkPartner].linked) {
            require(partners[msg.sender][_partner].limit > partners[msg.sender][_linkPartner].limit,"Error: Link partner has a higher limit");
            partners[msg.sender][_partner].linked = true;
            partners[msg.sender][_partner].partnerIdx.push(_linkPartner);
            partners[msg.sender][_partner].partnerPointers[_linkPartner] = partners[msg.sender][_partner].partnerIdx.length - 1;
            links[msg.sender][_linkPartner].ownerNode = _partner;
        } else {
            require(!_isDottedLinked(_partner, _linkPartner), "Error: Dotted link already exists");
            if (linkPartLevel > partnerLevel) {
                partners[msg.sender][_linkPartner].dottedIdxUp.push(_partner);
                partners[msg.sender][_linkPartner].dottedPointersUp[_partner] = partners[msg.sender][_linkPartner].dottedIdxUp.length - 1;
                partners[msg.sender][_partner].dottedIdxDown.push(_linkPartner);
                partners[msg.sender][_partner].dottedPointersDown[_linkPartner] = partners[msg.sender][_partner].dottedIdxDown.length - 1;
            } else revert("Error: Invlalid hierarchy");
        }
    }

    function delinkPartner(address _partner, address _linkPartner) external returns (bool){
        require(_isUser(msg.sender), "Error: User not registered");
        require(_isRegistered(_partner, msg.sender),"Error: Partner not registered for this user");
        require(_isRegistered(_linkPartner, msg.sender),"Error: Link Partner not registered for this user");
        require(_isLinked(_partner, _linkPartner), "Error: Partner not linked");
        partners[msg.sender][_partner].linked = false;
        uint256 rowToDelete = partners[msg.sender][_partner].partnerPointers[_linkPartner];
        address keyToMove = partners[msg.sender][_partner].partnerIdx[partners[msg.sender][_partner].partnerIdx.length - 1];
        partners[msg.sender][_partner].partnerIdx[rowToDelete] = keyToMove;
        delete partners[msg.sender][_partner].partnerPointers[_linkPartner];
        partners[msg.sender][_partner].partnerIdx.pop();
        delete links[msg.sender][_linkPartner];
        return true;
    }

    function getOwnerNode(address _partner) public view returns (address) {
        return (links[msg.sender][_partner].ownerNode);
    }

    function getLevel(address _partner) internal view returns (uint256) {
        //Need some permissions here
        uint256 level;
        address levelUp = links[msg.sender][_partner].ownerNode;
        while (true) {
            if (levelUp == address(0)) return (level);
            levelUp = links[msg.sender][levelUp].ownerNode;
            level++;
        }
    }
    
    // function _isTxn(address _user,address _partner, address _extPartner, uint256 _txn) internal view returns (bool) {
    //     if (txnIdx.length == 0) return false;
    //       return (txnIdx[txns[_user][_partner][_extPartner][_txn].index] == _txn);
    //     }
//     enum STAGE {IN, TA, TS, TR, TP, PD} // Initial, To Approve, To Ship, To Receive, To Pay
//     enum STATUS {IN, AP, RJ} // Approved, Rejected
  
    function getApprovalLevel(address _user,address _partner, address _extPartner, uint256 _txn, uint256 _amount, bool _approve) external returns (address) {
        require(_isUser(_user), "Error: User not registered");
        require(_isRegistered(_partner, _user), "Error: Partner not registered for this user");
   //     require(_isTxn(_user, _partner, _extPartner, _txn), "Error: Transaction does not exist");
        require(txns[_user][_partner][_extPartner][_txn].stage == STAGE(0), "Error: Not ready to approve 0");
        if (!_approve) {
            txns[_user][_partner][_extPartner][_txn].status = STATUS(2);
            return _partner; 
        }
        address levelUp = _partner;
        while (true) {
            if (partners[_user][levelUp].limit >= _amount) {
                txns[_user][_partner][_extPartner][_txn].approver = levelUp;
                if (_partner != levelUp) {
                    txns[_user][_partner][_extPartner][_txn].stage = STAGE(1);
                    partners[_user][levelUp].txns.push(txns[_user][_partner][_extPartner][_txn].index);
                }  else {
                        if (_isUser(_extPartner) && users[_extPartner].defShip != address(0)) {
                            uint idx = txns[_user][_partner][_extPartner][_txn].index;
                            users[_extPartner].txns.push(idx);
                            partners[_extPartner][users[_extPartner].defShip].txns.push(idx);
                             txns[_user][_partner][_extPartner][_txn].shipper = users[_extPartner].defShip;
                        }
                        txns[_user][_partner][_extPartner][_txn].stage = STAGE(2);
                        txns[_user][_partner][_extPartner][_txn].status = STATUS(1);
                }  
                return levelUp;
            }
            levelUp = links[_user][levelUp].ownerNode;
            if (levelUp == address(0)) {
                txns[_user][_partner][_extPartner][_txn].status = STATUS(2);
                return _user;
            } 
        }
    }

    function setApproval(address _user, address _partner, address _extPartner, uint256 _txn, bool _approve) external returns (bool) {
        require(_isUser(_user), "Error: User not registered");
        require(_isRegistered(msg.sender, _user), "Error: Partner not registered for this user");
        // require(_isTxn(_user, _partner, _extPartner, _txn), "Error: Transaction does not exist");
        require(txns[_user][_partner][_extPartner][_txn].stage == STAGE(1), "Error: Not ready to approve 1");
        if (_approve) {
             if (_isUser(_extPartner) && users[_extPartner].defShip != address(0)) {
                 uint idx = txns[_user][_partner][_extPartner][_txn].index;
                 users[_extPartner].txns.push(idx);
                 partners[_extPartner][users[_extPartner].defShip].txns.push(idx);
                 txns[_user][_partner][_extPartner][_txn].shipper = users[_extPartner].defShip;
            }
            txns[_user][_partner][_extPartner][_txn].status = STATUS(1);
            txns[_user][_partner][_extPartner][_txn].stage = STAGE(2);
        }
        else {
            txns[_user][_partner][_extPartner][_txn].status = STATUS(0);
            txns[_user][_partner][_extPartner][_txn].stage = STAGE(0);
        }
        emit status(_user, _partner, _extPartner, _txn, txns[_user][_partner][_extPartner][_txn].amount, txns[_user][_partner][_extPartner][_txn].stage );
        return true;
    }
            
    function setShip(address _user, address _partner, address _extPartner, uint256 _txn, bool _ship) external returns (bool) {
        require(_isUser(_extPartner), "Error: User not registered");
        require(_isRegistered(msg.sender, _extPartner), "Error: Partner not registered for this user");
        // require(_isTxn(_user, _partner, _extPartner, _txn), "Error: Transaction does not exist");
        require(txns[_user][_partner][_extPartner][_txn].stage == STAGE(2),"Error: Not ready to ship");
        if (_ship) {
             // Delete from Shipper here
            txns[_user][_partner][_extPartner][_txn].status = STATUS(1);
            txns[_user][_partner][_extPartner][_txn].stage = STAGE(3);
        }
        else {
            txns[_user][_partner][_extPartner][_txn].status = STATUS(2);
        }
        emit status(_user, _partner, _extPartner, _txn, txns[_user][_partner][_extPartner][_txn].amount, txns[_user][_partner][_extPartner][_txn].stage );
        return true;
    }

    function setReceive(address _user, address _partner, address _extPartner, uint256 _txn, bool _receive) external returns (bool) {
        require(_isUser(_user), "Error: User not registered");
        require(_isRegistered(msg.sender, _user), "Error: Partner not registered for this user");
        // require(_isTxn(_user, _partner, _extPartner, _txn), "Error: Transaction does not exist");
        require(txns[_user][_partner][_extPartner][_txn].stage == STAGE(3),"Error: Not ready to receive");
        if (_receive) {
            txns[_user][_partner][_extPartner][_txn].status = STATUS(1);
            txns[_user][_partner][_extPartner][_txn].stage = STAGE(4);
        }
        else {
            txns[_user][_partner][_extPartner][_txn].status = STATUS(2);
        }
        emit status(_user, _partner, _extPartner, _txn, txns[_user][_partner][_extPartner][_txn].amount, txns[_user][_partner][_extPartner][_txn].stage );
        return true;
    }
    
    function pay(address _user, address _partner, address payable _extPartner, uint256 _txn, bool _pay) external returns (bool) {
        require(_isUser(_user), "Error: User not registered");
        require(_isRegistered(msg.sender, _user), "Error: Partner not registered for this user");
        require(txns[_user][_partner][_extPartner][_txn].stage == STAGE(4),"Error: Not ready to pay");
        require(users[_user].bal >= txns[_user][_partner][_extPartner][_txn].amount, "Error: Insufficient funds");
        if (_pay) {
            users[_user].bal -= txns[_user][_partner][_extPartner][_txn].amount;
            if (_isUser(_extPartner)) {
                users[_extPartner].bal += txns[_user][_partner][_extPartner][_txn].amount;
            } else _extPartner.transfer(txns[_user][_partner][_extPartner][_txn].amount);
            txns[_user][_partner][_extPartner][_txn].status = STATUS(1);
            txns[_user][_partner][_extPartner][_txn].stage = STAGE(5);
        }
        else {
            txns[_user][_partner][_extPartner][_txn].status = STATUS(2);
        }
        emit status(_user, _partner, _extPartner, _txn, txns[_user][_partner][_extPartner][_txn].amount, txns[_user][_partner][_extPartner][_txn].stage );
        return true;
    }

    function updateTxnList(address _user, address _partner, address _extPartner, uint256 _txn, uint _amount, uint _action) external returns (bool) {
    //Action 0 - Initial: Add txn to PO partner
    //Action 1 - Approved: Delete from Approval Partner, Add to External Partner
    //Action 2- Rejected: Delete from Approval Partner
        require(_isUser(_user), "Error: User not registered");
        require(_isRegistered(_partner, _user),"Error: Partner not registered for this user");
        // require(_isTxn(_user, _partner, _extPartner, _txn),"Error: Transaction does not exist for this user");
        uint256 idx;
        if (_action == 0 ) { //Register Transaction
            
            TxnPointer memory txn;
            
            txn.user = _user;
            txn.partner = _partner;
            txn.extPartner = _extPartner;
            txn.txn = _txn;
            
            txns[_user][_partner][_extPartner][_txn].amount = _amount;
            txns[_user][_partner][_extPartner][_txn].stage = STAGE(0);
            txns[_user][_partner][_extPartner][_txn].user = _user;
            txns[_user][_partner][_extPartner][_txn].extPartner = _extPartner;
            txnIdx.push(txn);
            idx = txnIdx.length - 1;
            
            txns[_user][_partner][_extPartner][_txn].index = idx;
            
            users[_user].txns.push(idx);
            partners[_user][_partner].txns.push(idx);
            
        }
            else {
                if (_action == 1) { //Change Transaction
                    //idx = txns[_user][_partner][_extPartner][_txn].index;
                     txns[_user][_partner][_extPartner][_txn].amount = _amount;
                }
                    else {
                        if (_action == 2) {
                            //Handle Delete
                        }
                    }
         }
        return (true);
    }
    
    function getTransaction (uint256 _index) external view returns (TxnInt memory) {
        require(txnIdx[_index].partner == msg.sender ||
                txns[txnIdx[_index].user][txnIdx[_index].partner][txnIdx[_index].extPartner][txnIdx[_index].txn].approver == msg.sender ||
                txns[txnIdx[_index].user][txnIdx[_index].partner][txnIdx[_index].extPartner][txnIdx[_index].txn].shipper == msg.sender ||
                txns[txnIdx[_index].user][txnIdx[_index].partner][txnIdx[_index].extPartner][txnIdx[_index].txn].user == msg.sender ||
                txns[txnIdx[_index].user][txnIdx[_index].partner][txnIdx[_index].extPartner][txnIdx[_index].txn].extPartner == msg.sender
                , "Error: Transaction does not exist");
                TxnInt memory txint;
                txint.user = txnIdx[_index].user;
                txint.partner = txnIdx[_index].partner;
                txint.extPartner = txnIdx[_index].extPartner;
                txint.txn = txnIdx[_index].txn;
                txint.direction = txns[txnIdx[_index].user][txnIdx[_index].partner][txnIdx[_index].extPartner][txnIdx[_index].txn].direction;
                txint.amount = txns[txnIdx[_index].user][txnIdx[_index].partner][txnIdx[_index].extPartner][txnIdx[_index].txn].amount;
                txint.stage = txns[txnIdx[_index].user][txnIdx[_index].partner][txnIdx[_index].extPartner][txnIdx[_index].txn].stage;
                txint.approver = txns[txnIdx[_index].user][txnIdx[_index].partner][txnIdx[_index].extPartner][txnIdx[_index].txn].approver;
                txint.shipper = txns[txnIdx[_index].user][txnIdx[_index].partner][txnIdx[_index].extPartner][txnIdx[_index].txn].shipper;
                txint.payer = txns[txnIdx[_index].user][txnIdx[_index].partner][txnIdx[_index].extPartner][txnIdx[_index].txn].payer;
                txint.status = txns[txnIdx[_index].user][txnIdx[_index].partner][txnIdx[_index].extPartner][txnIdx[_index].txn].status;
        return(txint);
    }

    function balanceOf() public view onlyOwner returns (uint256) {
    //Needs tightening up
       // return address(this).balance;
       return dai.balanceOf(address(this));
    }

    function _transfer(address recipient, uint amount) external {
       // require(_isUser(msg.sender), "Error: User not registered");
       // require(users[recipient].bal >= amount, "Error: Insufficient funds");
        users[recipient].bal -= amount;
        dai.transfer(recipient, amount);
    }    

    function _transferFrom(uint amount) external {
        require(_isUser(msg.sender), "Error: User not registered");
        users[msg.sender].bal += amount;
        dai.transferFrom(msg.sender, address(this), amount);
    }          

}


    
