The goal of this project is to enable a user to configure an organization structure of any depth and complexity using Ethereum addresses as nodes. The code currently supports:

 Referential integrity
 Hierarchical integrity
 CRUD operations
 Dynamic linking
 Matrix organizations
The use case provides for a Purchase Order approval scenario whereby a PO is submitted for approval and migrates up the organization hierarchy until the appropriate approval level is reached. The node determined by this process becomes the approver of the PO.


https://docs.google.com/document/d/1jQOW8ZO2-IxkCLyEBoNOcMOGYlQAnNhQ0TgIiQnncik/edit#heading=h.9nvcibv3gama

    

Build an Organization on Ethereum blockchain
05.27.2020
─

Overview
The objective of this project is to provide a framework for building organizational structures on Ethereum blockchain. These org structures could be used to represent any kind of social hierarchy, for example a company, hierarchy of companies or a hierarchical voting model like the court system.
Goals
Provide a utility to construct an org structure of any depth and complexity.
Provide a secure, robust, scalable and easy to use solution.
Facilitate financial/logistical transactions across and within organizations.
Link any kind of process or transaction to an org structure. A Purchase Order approval mechanism is the scenario explored here.
Specifications - Functional
Roles

There are four roles in this model:
	Owner
	User
	Partner
	External Partner

Owner: The Owner role sits at the top of the hierarchy. The concept is for an ecosystem of Users that can freely interact. The Owner registers Users and has no other function.

User: A User is analogous to an administrator for an organization. It could also be a legal entity such as a company. A User can maintain and link Partners within a User account. User is unique within Owner.
Partner: A Partner is a node within a User account, e.g. an individual or department within a company. A Partner can create External Partners in order to interact with other Users or entities external to the Owner ecosystem. Partner is unique within User.
A Partner may have assigned rights, for example the ability to approve a Purchase Order or to vote in a poll. 
Partners may be linked in an organizational structure by the User. 

External Partner: An External Partner is used to interact with entities external to the user account. External Partners can be registered by Partners with the required permission. External Partner is unique within Partner. External Partners can be other Users.

Linking

Partners are created and linked in two steps (Create and Link). Only the User role can perform these functions. 
There are two types of linking, Primary Linking and Dotted Linking. 
Primary Linking occurs when a Partner is linked to a node in the hierarchy, i.e. the linked to node becomes the Partner’s owner node. A Partner can have only one primary link.
Dotted Linking is a secondary link that occurs when an already linked Partner is linked to any higher level node in the hierarchy. It is not possible to link to a lower level partner. There may be 1:N Dotted relationships per Partner. 
Dynamic linking is supported whereby a Partner may be de-linked from a Partner node  and subsequently linked to any other node in the User account. All lower level Partners of the de-linked Partner will be re-assigned dynamically.* In addition, all Dotted links are removed.




* Supported with referential integrity and dynamic level calculation. Not yet implemented.
Figure 1:
https://docs.google.com/presentation/d/191So-79mYQ3KWtugFQhw3SMxwzN-Bz7yeMEsVb46pIY/edit#slide=id.p
This slide shows the relationships supported by this model. 

All nodes in this model are represented by Ethereum addresses. 
Figure 2:
https://docs.google.com/presentation/d/191So-79mYQ3KWtugFQhw3SMxwzN-Bz7yeMEsVb46pIY/edit#slide=id.g808a13faed_5_0

It is possible that a Partner address could also be a User address. In this way a hierarchy of Users could be built similar to a company with subsidiaries. 
A subcontractor/ distributor scenario would also be possible.

 


Specifications - Technical

This model (org.sol, po.sol)  are Smart Contracts implemented using the Solidity language. 
Referential Integrity

This model provides full for referential integrity for CRUD operations. Solidity does not provide a database so referential integrity must be enforced using a combination of arrays and key/value objects called mappings. The foundation for this approach is an article by Rob Hitchens in Medium:
https://medium.com/robhitchens/enforcing-referential-integrity-in-ethereum-smart-contracts-a9ab1427ff42
Dynamic Linking and Hierarchical Integrity

The model calculates the level of each node during the linking process. For example, in slide 1 above it would not be possible to link User: U1/Partner 1 to any lower level Partner.
Partners can be de-linked and re-linked  to any other node in the User hierarchy. This will cause all lower level Partners to automatically re-assigned and Dotted links to be removed.

Access Controls

All functions in org.sol are controlled by either Modifiers or Requirements.  They are specified in the order of the most general to the most specific. For example, first check that the User is valid, then Partner etc. The front end should call requirements up front to avoid unnecessary gas charges.



Interface

The Smart Contract org.sol provides an interface to facilitate interaction with other Smart Contracts, in this case a Purchase Order that is subject to approval based on value.
org.sol


org.sol supports the creation of User, Partner, Extended Partner relationships to any depth. It currently supports PO approval based on approval limits but in theory any kind of business contract could be implemented, e.g. a rebate agreement or a chargeback. The goal is to build a plug-in type of interface where different business processes can be added.
po.sol


There are two Smart Contracts in this model: org.sol and po.sol. The po.sol contract is intended as a demonstration use case for org.sol. It implements full CRUD capability with referential integrity. po.sol is a minimal implementation of a purchase order, the reason for keeping it on-chain is so that both parties have visibility to a ‘single source of truth’. A future development option is to charge a deposit held by the owner node that is returned to the User account that created the PO once the PO is deleted. This is an incentive to reduce the storage footprint of the po.sol contract.
po.sol implements the hierarchy structure of org.sol through an interface that calls requirement functions in the org.sol contract.
po.sol calls org,sol to get the required level of approval based on PO value.
EIP #170 Issues
	
There is currently a limitation on the size of Smart Contracts (24KB) https://github.com/ethereum/EIPs/issues/170. This is due to security concerns around how the contract is loaded into the Ethereum Virtual Machine. 
This is currently a subject of debate in the Ethereum community but the immediate impact for this project is that org.sol and po.sol will need to be refactored into smaller contracts in order for development to move forward.  

Use Case - Create a Purchase Order and get Approval based on Org
Once a Purchase Orders has been entered by a Partner with reference to an External Partner the Partner must submit the PO for approval. po.sol calls a function in org.sol that migrates up the hierarchy until it finds a higher level Partner with an approval limit equal to or greater than the PO total amount. 
The approved address is stamped on the PO header and added to a list of pending approvals for the approving partner. In this way a simple workflow is enabled. If the PO amount is greater than the approval limit of any higher level partner then the PO is sent to the User node.
Once the PO is approved it becomes visible to the counterparty. 


Future Development
Complete all Truffle test scenarios for po.sol and org.sol.
Complete Approve process for PO.
Add balance sheet and P/L capability to User node and potentially Partner nodes.
Enable cost allocation across Partner nodes.
Allow User node to post to another User node e.g. A/P, A/R.
Build generalized interface to org.sol so that any transaction can be easily implemented, e.g. broadcast tender to multiple External Partners with a time limit and select best price. Use Plug-in approach. 
Charge deposit to Users whose Partners post transactions. The deposit is returned once the transaction is deleted. This is an incentive to keep the transaction contracts from growing indefinitely.
Add de-linking functionality.
Add delete functions to unwind all org.sol relationships with checks on referential integrity and business logic.
Allow User node to ‘see’ all transactions with other User nodes.
Add Events to interact with Web3 server.
Add reporting capability based on Events.
Incorporate React and Drizzle.
Build a user friendly front end. Current front end is basic Bootstrap.
Add recursive depth search to return all nodes below a given level.
Add permissions profile to Partners, e.g. what transactions can be executed.
Encrypt transactions or use aliases to prevent adversaries from deducing patterns on Etherscan.
Allow User node to delegate to Partners with time limit.
Implement either ERC1538: Transparent Contract Standard · Issue #1538 · ethereum/EIPs or Diamond patterns to circumvent ERC 170 issues.
Implement Approval Strategy so that approvals can be lateral as well as hierarchical.
Frontend should call all requirements first before calling a function to avoid unnecessary gas charges. Need to put all of Link function checks in separate function.
Add ability to Web3 server to upload POs from spreadsheets.
Build a reputation system, e.g. based on payment history.
What would ownerless model look like?


