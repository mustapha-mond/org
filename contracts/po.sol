pragma solidity ^0.5.16;

import '../contracts/org.sol';

contract po {
 
    struct Order{
        mapping(uint => uint) headerPointers;
        uint[] headerIdx;
    }
 //User, Partner, External Partner
    mapping (address => mapping(address => mapping(address => Order))) orders;  
   
    struct Header {
        uint date;
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
        string sku;
        uint quantity;
        uint deliveryDate;
        uint price;
        uint index;
        uint poNumber;
    }
//User, Partner, External Partner, Order, Item    
    mapping (address => mapping(address => mapping(address => mapping(uint => mapping(uint => Item))))) items;
   
    address addressOrg;
   
    function setOrgAddress(address _address) external returns (bool) {
        addressOrg = _address;
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
   
    function createOrder (address _user, address _extPartner, uint _poNumber, uint _date) external returns (bool) {
        intOrg org = intOrg(addressOrg);
        require (org._isUser(_user),'Error: User not registered');
        require (org._isPartExtReg(_user, msg.sender),'Error: Partner not registered for this user');
        require (org._isExtPartReg(_user, _extPartner, msg.sender),'Error: External partner not registered');
        require (_poNumber != 0,'Error: PO Number cannot be null');
        require (!isOrder(_user, _extPartner, _poNumber), 'Error: Order already exists');
        headers[_user][msg.sender][_extPartner][_poNumber].date = _date;
        headers[_user][msg.sender][_extPartner][_poNumber].extPartner = _extPartner;
        headers[_user][msg.sender][_extPartner][_poNumber].partner = msg.sender;
        uint idx = orders[_user][msg.sender][_extPartner].headerIdx.push(_poNumber) - 1;
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
   
    function createItem (address _user, address _extPartner, uint _poNumber, uint _itemNo, string calldata _sku, uint _quantity, uint _price) external returns (bool) {
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
        uint idx = headers[_user][msg.sender][_extPartner][_poNumber].itemIdx.push(_itemNo) - 1;
        items[_user][msg.sender][_extPartner][_poNumber][_itemNo].index = idx;
        headers[_user][msg.sender][_extPartner][_poNumber].itemPointers[_itemNo] = idx;
        uint total =  headers[_user][msg.sender][_extPartner][_poNumber].total;
        org.updateTxnList (_user, msg.sender, _extPartner, _poNumber, total, 1);
        return true;
    }
   
    function changeItem (address _user, address _extPartner, uint _poNumber, uint _itemNo, string calldata _sku, uint _quantity) external returns (bool){
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
   
    function getOrder (address _user, address _extPartner, uint _poNumber) external view returns (address, uint, uint[] memory, uint){
        intOrg org = intOrg(addressOrg);
        require (org._isUser(_user),'Error: User not registered');
        require (org._isPartExtReg(_user, msg.sender),'Error: Partner not registered for this user');
        require (org._isExtPartReg(_user, _extPartner, msg.sender),'Error: External partner not registered');
        require (isOrder(_user, _extPartner, _poNumber),'Error: Order does not exist');
        return (headers[_user][msg.sender][_extPartner][_poNumber].approver,
                headers[_user][msg.sender][_extPartner][_poNumber].total,
                headers[_user][msg.sender][_extPartner][_poNumber].itemIdx,
                headers[_user][msg.sender][_extPartner][_poNumber].date);
    }
   
    function getItem (address _user, address _extPartner, uint _poNumber, uint _itemNo) external view returns (string memory, uint, uint) {
        intOrg org = intOrg(addressOrg);
        require (org._isUser(_user),'Error: User not registered');
        require (org._isPartExtReg(_user, msg.sender),'Error: Partner not registered for this user');
        require (org._isExtPartReg(_user, _extPartner, msg.sender),'Error: External partner not registered');
        require (isOrder(_user, _extPartner, _poNumber),'Error: Order does not exist');
        require (isItem(_user, _extPartner, _poNumber, _itemNo), 'Error: Item does not exist');
        return (items[_user][msg.sender][_extPartner][_poNumber][_itemNo].sku,
                items[_user][msg.sender][_extPartner][_poNumber][_itemNo].quantity,
                items[_user][msg.sender][_extPartner][_poNumber][_itemNo].price);
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
}
