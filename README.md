# A full lifecycle supply chain/accounting application built on Ethereum blockchain

05.27.2020

## _Overview_

- Eliminates Duplication from the Economy
- Enables Traceability throughout the Supply Chain
- Provides a mechanism for Single Sign-On 
- Provides a Global Logistics Platform 
- Provides a Global Payments Platform
- Is DAO of DAOs that provides for Operational and Technical Governance

## _Docs_

Overview:

https://docs.google.com/presentation/d/1nzTLvVUPsVcIxiqXMcJCXswuxxtxfN_-NpqvYMmYQk0/edit?usp=sharing

Litepaper:

https://docs.google.com/document/d/1tEY9Do_NjU-5O04cAeI3VIbLQar3l596G07GFfD26rI/edit?usp=sharing

B2C Demo:

https://drive.google.com/file/d/1YRYyWbSm6w6_ryocfS37XBS32M--9BDY/view?usp=sharing

Note: e-commerce website cloned from Scrimba React course with some mods. 

B2B Demo:

https://drive.google.com/file/d/1lIEju9dEEkXIv6iJL1ubFjNov2BE5oxN/view?usp=sharing


## _Goals_

1. Provide a utility to construct and maintain an org structure of any depth and complexity.
2. Provide a secure, robust, scalable and easy to use solution.
3. Facilitate financial/logistical transactions across and within organizations.
4. Provide plug-in capabaility so that any kind of process or transaction can reference an org structure. A Purchase Order approval mechanism is the scenario explored here.

The code currently supports:

 * Referential integrity
 
 * Hierarchical integrity

 * CRUD operations

 * Dynamic linking
 
 * Matrix organizations
 
 * Transaction integration
 
 The use case provides for a Purchase Order approval scenario whereby a PO is submitted for approval and migrates up the organization hierarchy until the appropriate approval level is reached. The node determined by this process becomes the approver of the PO.


## _Specifications - Functional_

### _Roles_

There are four roles in this model: 

* **Owner**  
* **User**  
* **Partner**  
* **External Partner**

**Owner:** The Owner role sits at the top of the hierarchy. The concept is for an ecosystem of Users that can freely interact. The Owner registers Users and is responsible for the maintenenace of the ecosystem. This entails vetting and managing the deployment of plug-ins and holding deposits for transactions to incent users to delete expired transactions and so manage the storage footprint to keep gas costs in check. 

In fact there cold be multiple Owner instances and because accounts are unique it would be possible for Users/Parners to interact across Owner instances. Owners could therefore compete on such factors as rates, usability or plug-in support.

Funds deposited by Users are held in the Smart Contract deployed by the Owner. The Owner does not have any access to these funds. In this sense the Smart Contract acts as a kind of bank. It would be possible to set liquidity ratios and offer loans to Users or even other Owner.

**User:** A User is analogous to an administrator for an organization. It could also be a legal entity such as a company. A User can maintain and link Partners within a User account. User is unique within Owner.

Users deposit funds to the Smart Contract which they then use to trade with other Users either withing or outside their own Owner ecosystem. 

**Partner:** A Partner is a node within a User account, e.g. an individual or department within a company. A Partner can create External Partners in order to interact with other Users or entities external to the Owner ecosystem. Partner is unique within User.
A Partner may have assigned rights, for example the ability to approve a Purchase Order or to vote in a poll. 
Partners may be linked in an organizational structure by the User

**External Partner:** An External Partner is used to interact with entities external to the user account. External Partners can be registered by Partners with the required permission. External Partner is unique within Partner. External Partners can be other Users.

### _Linking_

Partners are created and linked in two steps (Create and Link). Only the User role can perform these functions. 
There are two types of linking, Primary Linking and Dotted Linking. 
Primary Linking occurs when a Partner is linked to a node in the hierarchy, i.e. the linked to node becomes the Partner’s owner node. A Partner can have only one primary link.
Dotted Linking is a secondary link that occurs when an already linked Partner is linked to any higher level node in the hierarchy. It is not possible to link to a lower level partner. There may be 1:N Dotted relationships per Partner. 
Dynamic linking is supported whereby a Partner may be de-linked from a Partner node  and subsequently linked to any other node in the User account. All lower level Partners of the de-linked Partner will be re-assigned dynamically. In addition, all Dotted links are removed.


Partners can be de-linked and re-linked  to any other node in the User hierarchy. This will cause all lower level Partners to automatically re-assigned and Dotted links to be removed.

## _Access Controls_

All functions in org.sol are controlled by either Modifiers or Requirements.  They are specified in the order of the most general to the most specific. For example, first check that the User is valid, then Partner etc. The front end should call requirements up front to avoid unnecessary gas charges


## _Interface_

The Smart Contract org.sol provides an interface to facilitate interaction with other Smart Contracts, in this case a Purchase Order that is subject to approval based on value.

## _org.sol_

org.sol supports the creation of User, Partner, Extended Partner relationships to any depth. It currently supports PO approval based on approval limits but in theory any kind of business contract could be implemented, e.g. a rebate agreement or a chargeback. The goal is to build a plug-in type of interface where different business processes can be added.

## _po.sol_

The po.sol contract is intended as a demonstration use case for org.sol. It implements full CRUD capability with referential integrity. po.sol is a minimal implementation of a purchase order, the reason for keeping it on-chain is so that both parties have visibility to a ‘single source of truth’. A future development option is to charge a deposit held by the owner node that is returned to the User account that created the PO once the PO is deleted. This is an incentive to reduce the storage footprint of the po.sol contract.
po.sol implements the hierarchy structure of org.sol through an interface that calls requirement functions in the org.sol contract.
po.sol calls org,sol to get the required level of approval based on PO value.

## _EIP #170 Issues_

There is currently a limitation on the size of Smart Contracts (24KB) [Github](https://github.com/ethereum/EIPs/issues/170). This is due to security concerns around how the contract is loaded into the Ethereum Virtual Machine. 
This is currently a subject of debate in the Ethereum community but the immediate impact for this project is that org.sol and po.sol will need to be refactored into smaller contracts in order for development to move forward.  

## _Use Case - Create a Purchase Order and get Approval based on Org_

Once a Purchase Orders has been entered by a Partner with reference to an External Partner the Partner must submit the PO for approval. po.sol calls a function in org.sol that migrates up the hierarchy until it finds a higher level Partner with an approval limit equal to or greater than the PO total amount.   
The approved address is stamped on the PO header and added to a list of pending approvals for the approving partner. In this way a simple workflow is enabled. If the PO amount is greater than the approval limit of any higher level partner then the PO is sent to the User node.
Once the PO is approved it becomes visible to the counterparty. 





