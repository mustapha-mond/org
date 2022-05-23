pragma solidity ^0.6.12;

import '../contracts/org.sol';
import '../client/airnode-master/packages/protocol/contracts/AirnodeClient.sol';

contract po is AirnodeClient{

    struct Order{
        mapping(uint => uint) headerPointers;
        uint[] headerIdx;
    }
 //User, Partner, External Partner
    mapping (address => mapping(address => mapping(address => Order))) orders;  
   
    struct Header {
        uint date;
        uint cdate;
        uint total;
        address approver;
        address partner;
        address extPartner;
        uint index;
        bool paid;
        mapping (uint => uint) itemPointers;
        uint[] itemIdx;
    }
//User, Partner, External Partner, PO Number  
    mapping (address => mapping(address => mapping(address => mapping(uint => Header)))) headers;  
   
    struct Item {
        bytes32 sku;
        uint quantity;
        uint deliveryDate;
        uint price;
        uint index;
        uint poNumber;
        address manufacturer;
        uint wac;
        bytes32 requestId;
    }

//User, Partner, External Partner, Order, Item    
    mapping (address => mapping(address => mapping(address => mapping(uint => mapping(uint => Item))))) items;

    address addressOrg;

//Airnode
    bytes32 AirnodeEP;
    bytes32 AirnodePr;
    address AirnodeWal;
    uint256 AirnodeRqInd;

    mapping(bytes32 => bool) public incomingFulfillments;
    mapping(bytes32 => int256) public fulfilledData;

    event Airnode (
        bytes32,
        bytes32,
        uint256,
        address,
        bytes
    );

    event call_test(address user, address sender, address extPartner, uint total);

    constructor (address airnodeAddress)
        public
        AirnodeClient(airnodeAddress)
    {}
   
//Set Addresses

    function setOrgAddress(address _address) external returns (bool) {
        addressOrg = _address;
        return true;
    }
   
   function setEPAddress(bytes32 _address) external returns (bool) {
        AirnodeEP = _address;
        return true;
    }


    function setPrAddress(bytes32 _address) external returns (bool) {
       AirnodePr = _address;
        return true;
    }

    function setWalAddress(address _address) external returns (bool) {
        AirnodeWal = _address;
        return true;
    }

    function setRqInd(uint256 _RqInd) external returns (bool) {
        AirnodeRqInd = _RqInd;
        return true;
    }

    function isOrder(address _user, address _extPartner, uint _poNumber) public view returns (bool) {
        if (orders[_user][msg.sender][_extPartner].headerIdx.length == 0) return false;
        return (orders[_user][msg.sender][_extPartner].headerIdx[headers[_user][msg.sender][_extPartner][_poNumber].index] == _poNumber);
    }

   
    function isItem(address _user, address _extPartner, uint _poNumber, uint _itemNo) public view returns (bool) {
        if (headers[_user][msg.sender][_extPartner][_poNumber].itemIdx.length == 0) return false;
        return (headers[_user][msg.sender][_extPartner][_poNumber].itemIdx[items[_user][msg.sender][_extPartner][_poNumber][_itemNo].index] == _itemNo);
    }
   
    function createOrder (address _user, address _extPartner, uint _poNumber, uint _ddate, uint _cdate) external returns (bool) {
        intOrg org = intOrg(addressOrg);
        require (org._isUser(_user),'Error: User not registered');
        require (org._isPartExtReg(_user, msg.sender),'Error: Partner not registered for this user');
        require (org._isExtPartReg(_user, _extPartner, msg.sender),'Error: External partner not registered');
        require (_poNumber != 0,'Error: PO Number cannot be null');
        require (!isOrder(_user, _extPartner, _poNumber), 'Error: Order already exists');
        headers[_user][msg.sender][_extPartner][_poNumber].date = _ddate;
        headers[_user][msg.sender][_extPartner][_poNumber].cdate = _cdate;
        headers[_user][msg.sender][_extPartner][_poNumber].extPartner = _extPartner;
        headers[_user][msg.sender][_extPartner][_poNumber].partner = msg.sender;
        orders[_user][msg.sender][_extPartner].headerIdx.push(_poNumber);
        uint idx = orders[_user][msg.sender][_extPartner].headerIdx.length - 1;
        orders[_user][msg.sender][_extPartner].headerPointers[_poNumber] = idx;
        headers[_user][msg.sender][_extPartner][_poNumber].index = idx;
        org.updateTxnList (_user, msg.sender, _extPartner, _poNumber, 0, 0);
        return true;
    }
   
    function changeOrder (address _user, address _extPartner, uint _poNumber, uint _date) external returns (bool) {
        intOrg org = intOrg(addressOrg);
        require (org._isUser(_user),'Error: User not registered');
        require (org._isPartExtReg(_user, msg.sender),'Error: Partner not registered for this user');
        require (org._isExtPartReg(_user, _extPartner, msg.sender),'Error: External partner not registered');
        require (_poNumber != 0,'Error: PO Number cannot be null');
        require (isOrder(_user, _extPartner, _poNumber), 'Error: Order does not exist');
        headers[_user][msg.sender][_extPartner][_poNumber].date = _date;
        return true;
    }
   
    function createItem (address _user, address _extPartner, uint _poNumber, uint _itemNo, bytes32 _sku, uint _quantity, uint _price, bytes calldata _params) external returns (bool) {
        intOrg org = intOrg(addressOrg);
        require (org._isUser(_user),'Error: User not registered');
        require (org._isPartExtReg(_user, msg.sender),'Error: Partner not registered for this user');
        require (org._isExtPartReg(_user, _extPartner, msg.sender),'Error: External partner not registered');
        require (isOrder(_user, _extPartner, _poNumber),'Error: Order does not exist');
        require (!isItem(_user, _extPartner, _poNumber, _itemNo), 'Error: Item already exists');
        items[_user][msg.sender][_extPartner][_poNumber][_itemNo].poNumber = _poNumber;
        items[_user][msg.sender][_extPartner][_poNumber][_itemNo].sku = _sku;
        items[_user][msg.sender][_extPartner][_poNumber][_itemNo].quantity = _quantity;
        items[_user][msg.sender][_extPartner][_poNumber][_itemNo].price = _price;
        headers[_user][msg.sender][_extPartner][_poNumber].total += _quantity * _price;
        headers[_user][msg.sender][_extPartner][_poNumber].itemIdx.push(_itemNo);
        uint idx = headers[_user][msg.sender][_extPartner][_poNumber].itemIdx.length - 1;
        items[_user][msg.sender][_extPartner][_poNumber][_itemNo].index = idx;
        headers[_user][msg.sender][_extPartner][_poNumber].itemPointers[_itemNo] = idx;
        uint total =  headers[_user][msg.sender][_extPartner][_poNumber].total;
        org.updateTxnList (_user, msg.sender, _extPartner, _poNumber, total, 1);
        if (_price == 0){
            items[_user][msg.sender][_extPartner][_poNumber][_itemNo].requestId = makeRequest(AirnodePr, AirnodeEP, AirnodeRqInd, AirnodeWal, _params);
            emit Airnode (AirnodePr, AirnodeEP, AirnodeRqInd, AirnodeWal, _params);
        }
        return (true);
    }

    // function list (address _user, address _extPartner, uint _poNumber, uint _total) internal {
    //     intOrg org = intOrg(addressOrg);
    //     org.updateTxnList (_user, msg.sender, _extPartner, _poNumber, _total, 1);
    // }

   
    function changeItem (address _user, address _extPartner, uint _poNumber, uint _itemNo, bytes32 _sku, uint _quantity) external returns (bool){
        intOrg org = intOrg(addressOrg);
        require (org._isUser(_user),'Error: User not registered');
        require (org._isPartExtReg(_user, msg.sender),'Error: Partner not registered for this user');
        require (org._isExtPartReg(_user, _extPartner, msg.sender),'Error: External partner not registered');
        require (isOrder(_user, _extPartner, _poNumber),'Error: Order does not exist');
        require (isItem(_user, _extPartner, _poNumber, _itemNo), 'Error: Item already exists');
        items[_user][msg.sender][_extPartner][_poNumber][_itemNo].sku = _sku;
        items[_user][msg.sender][_extPartner][_poNumber][_itemNo].quantity = _quantity;
        uint total =  headers[_user][msg.sender][_extPartner][_poNumber].total;
        org.updateTxnList (_user, msg.sender, _extPartner, _poNumber, total, 1);
        return true;
    }
   
    function getOrder (address _user, address _extPartner, uint _poNumber) external view returns (address, uint, uint[] memory, uint, uint){
        intOrg org = intOrg(addressOrg);
        require (org._isUser(_user),'Error: User not registered');
        require (org._isPartExtReg(_user, msg.sender),'Error: Partner not registered for this user');
        require (org._isExtPartReg(_user, _extPartner, msg.sender),'Error: External partner not registered');
        require (isOrder(_user, _extPartner, _poNumber),'Error: Order does not exist');
        return (headers[_user][msg.sender][_extPartner][_poNumber].approver,
                headers[_user][msg.sender][_extPartner][_poNumber].total,
                headers[_user][msg.sender][_extPartner][_poNumber].itemIdx,
                headers[_user][msg.sender][_extPartner][_poNumber].date,
                headers[_user][msg.sender][_extPartner][_poNumber].cdate);
    }
   
    function getItem (address _user, address _extPartner, uint _poNumber, uint _itemNo) external view returns (bytes32, uint, uint, bool, bool) {
        intOrg org = intOrg(addressOrg);
        require (org._isUser(_user),'Error: User not registered');
        require (org._isPartExtReg(_user, msg.sender),'Error: Partner not registered for this user');
        require (org._isExtPartReg(_user, _extPartner, msg.sender),'Error: External partner not registered');
        require (isOrder(_user, _extPartner, _poNumber),'Error: Order does not exist');
        require (isItem(_user, _extPartner, _poNumber, _itemNo), 'Error: Item does not exist');
        bool pending;
        bool reprice;
        if (items[_user][msg.sender][_extPartner][_poNumber][_itemNo].price == 0) {
            if (incomingFulfillments[items[_user][msg.sender][_extPartner][_poNumber][_itemNo].requestId]) {
                pending = true; 
            } else {
                reprice = true;
            }
        }
        return (items[_user][msg.sender][_extPartner][_poNumber][_itemNo].sku,
                items[_user][msg.sender][_extPartner][_poNumber][_itemNo].quantity,
                items[_user][msg.sender][_extPartner][_poNumber][_itemNo].price, pending, reprice);
    }

   function reprice (address _user, address _extPartner, uint _poNumber, uint _itemNo) external returns (bytes32, uint, uint, bool) {
        intOrg org = intOrg(addressOrg);
        require (org._isUser(_user),'Error: User not registered');
        require (org._isPartExtReg(_user, msg.sender),'Error: Partner not registered for this user');
        require (org._isExtPartReg(_user, _extPartner, msg.sender),'Error: External partner not registered');
        require (isOrder(_user, _extPartner, _poNumber),'Error: Order does not exist');
        require (isItem(_user, _extPartner, _poNumber, _itemNo), 'Error: Item does not exist');
        require (items[_user][msg.sender][_extPartner][_poNumber][_itemNo].price == 0);
        uint256 price = uint256(fulfilledData[items[_user][msg.sender][_extPartner][_poNumber][_itemNo].requestId] * (( 1 ether) / 1000000) );
        items[_user][msg.sender][_extPartner][_poNumber][_itemNo].price = price;
        uint total = price * items[_user][msg.sender][_extPartner][_poNumber][_itemNo].quantity;
        headers[_user][msg.sender][_extPartner][_poNumber].total += total;
        uint total_header = headers[_user][msg.sender][_extPartner][_poNumber].total;
        emit call_test(_user, msg.sender, _extPartner, total_header);
        org.updateTxnList (_user, msg.sender, _extPartner, _poNumber, total_header, 1);
        return (items[_user][msg.sender][_extPartner][_poNumber][_itemNo].sku,
                items[_user][msg.sender][_extPartner][_poNumber][_itemNo].quantity,
                items[_user][msg.sender][_extPartner][_poNumber][_itemNo].price, true);
   }

    // function getApproval (address _user, address _extPartner, uint _poNumber) external  {
    //     intOrg org = intOrg(addressOrg);
    //     require (org._isUser(_user),'Error: User not registered');
    //     require (org._isPartExtReg(_user, msg.sender),'Error: Partner not registered for this user');
    //     require (org._isExtPartReg(_user, _extPartner, msg.sender),'Error: External partner not registered');
    //     require (isOrder(_user, _extPartner, _poNumber),'Error: Order does not exist');
    //     headers[_user][msg.sender][_extPartner][_poNumber].approver = org.getAppovalLevel(_user, msg.sender, _extPartner, headers[_user][msg.sender][_extPartner][_poNumber].total, _poNumber);
    //     headers[_user][msg.sender][_extPartner][_poNumber].status = STATUS(1);
    // }
       
    function deleteItem(address _user, address _extPartner, uint _poNumber, uint _itemNo) external {
        intOrg org = intOrg(addressOrg);
        require (org._isUser(_user),'Error: User not registered');
        require (org._isPartExtReg(_user, msg.sender),'Error: Partner not registered for this user');
        require (org._isExtPartReg(_user, _extPartner, msg.sender),'Error: External partner not registered');
        require (isOrder(_user, _extPartner, _poNumber),'Error: Order does not exist');
        require (isItem(_user, _extPartner, _poNumber, _itemNo), 'Error: Item does not exist');
        uint rowToDelete = headers[_user][msg.sender][_extPartner][_poNumber].itemPointers[_itemNo];
        uint keyToMove = headers[_user][msg.sender][_extPartner][_poNumber].itemIdx[headers[_user][msg.sender][_extPartner][_poNumber].itemIdx.length-1];
        headers[_user][msg.sender][_extPartner][_poNumber].itemIdx[rowToDelete] = keyToMove;
        headers[_user][msg.sender][_extPartner][_poNumber].itemPointers[keyToMove] = rowToDelete;
        items[_user][msg.sender][_extPartner][_poNumber][keyToMove].index = rowToDelete;
        delete items[_user][msg.sender][_extPartner][_poNumber][_itemNo];
        delete headers[_user][msg.sender][_extPartner][_poNumber].itemPointers[_itemNo];
        headers[_user][msg.sender][_extPartner][_poNumber].itemIdx.pop();
        org.updateTxnList (_user, msg.sender, _extPartner, _poNumber, 0, 1);
    }
   
    function deleteOrder(address _user, address _extPartner, uint _poNumber) external {
        intOrg org = intOrg(addressOrg);
        require (org._isUser(_user),'Error: User not registered');
        require (org._isPartExtReg(_user, msg.sender),'Error: Partner not registered for this user');
        require (org._isExtPartReg(_user, _extPartner, msg.sender),'Error: External partner not registered');
        require (isOrder(_user, _extPartner, _poNumber),'Error: Order does not exist');
        require (headers[_user][msg.sender][_extPartner][_poNumber].itemIdx.length == 0, 'Error: Items exist');
        uint rowToDelete = headers[_user][msg.sender][_extPartner][_poNumber].index;
        uint keyToMove = orders[_user][msg.sender][_extPartner].headerIdx[orders[_user][msg.sender][_extPartner].headerIdx.length -1];
        orders[_user][msg.sender][_extPartner].headerIdx[rowToDelete] = keyToMove;
        headers[_user][msg.sender][_extPartner][keyToMove].index = rowToDelete;
        delete headers[_user][msg.sender][_extPartner][_poNumber];
        orders[_user][msg.sender][_extPartner].headerIdx.pop();
        org.updateTxnList (_user, msg.sender, _extPartner, _poNumber, 0, 3);
    }
    
    function payVendor (address _user, address _extPartner, uint _poNumber) external  {
      intOrg org = intOrg(addressOrg);
        require (org._isUser(_user),'Error: User not registered');
        require (org._isPartExtReg(_user, msg.sender),'Error: Partner not registered for this user');
        require (org._isExtPartReg(_user, _extPartner, msg.sender),'Error: External partner not registered');
        require (isOrder(_user, _extPartner, _poNumber),'Error: Order does not exist');
        require (!(headers[_user][msg.sender][_extPartner][_poNumber].paid),'Error: PO already paid');
        address payable payee = org.getPayee(_user, msg.sender, _extPartner);
        headers[_user][msg.sender][_extPartner][_poNumber].paid = true;
        org.pay (_user, payee , headers[_user][msg.sender][_extPartner][_poNumber].total);
    }

    function makeRequest(
        bytes32 providerId,
        bytes32 endpointId,
        uint256 requesterInd,
        address designatedWallet,
        bytes memory parameters
        )
        public returns (bytes32)
    {
        bytes32 requestId = airnode.makeFullRequest(
            providerId,
            endpointId,
            requesterInd,
            designatedWallet,
            address(this),
            this.fulfill.selector,
            parameters
            );
        incomingFulfillments[requestId] = true;
        return (requestId);
    }

    function fulfill(
        bytes32 requestId,
        uint256 statusCode,
        int256 data
        )
        external
        onlyAirnode()
    {
        require(incomingFulfillments[requestId], "No such request made");
        delete incomingFulfillments[requestId];
        if (statusCode == 0)
        {
            fulfilledData[requestId] = data;
        }
    }

}
