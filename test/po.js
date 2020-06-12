const ORG = artifacts.require("org");
const PO = artifacts.require("po");

contract("ORG", (accounts) => {
  let org = null;
  before(async () => {
    org = await ORG.deployed();
  });

  contract("PO", () => {
    let po = null;
    before(async () => {
      po = await PO.deployed();
    });

    //User tests
    it("Register User", async () => {
      await org.regUser(accounts[5], "User 1");
      assert(org._isUser(accounts[5]));
    });

    // Partner tests
    it("Register Partner", async () => {
      await org.regPartner(accounts[6], "Partner 1", 100, true, {
        from: accounts[5],
      });
      assert(org._isRegistered(accounts[2], accounts[1]));
    });

    //External Partner tests
    it("Register External Partner", async () => {
      await org.regExtPartner(accounts[5], accounts[7], "External Partner 1", {
        from: accounts[6],
      });
      assert(org._isExtReg(accounts[5], accounts[7]));
    });

    it("Create PO", async () => {
      await po.setOrgAddress(org.address);
      await po.createOrder(accounts[5], accounts[7], 1, 1000, {
        from: accounts[6],
      });
      assert(po.isOrder(accounts[5], accounts[7], 1));
    });

    it("Do not allow duplicate PO numbers", async () => {
      try {
        await po.createOrder(accounts[5], accounts[7], 1, 1000, {
          from: accounts[6],
        });
      } catch (e) {
        assert(e.message.includes("Error: Order already exists"));
        return;
      }
      assert(false);
    });

    it("Create PO item", async () => {
      await po.createItem(accounts[5], accounts[7], 1, 1, "Item 1", 10, 85, {
        from: accounts[6],
      });
      assert(po.isItem(accounts[5], accounts[7], 1, 1));
    });

    it("Do not allow duplicate PO item numbers", async () => {
      try {
        await po.createItem(accounts[5], accounts[7], 1, 1, "Item 1", 10, 85, {
          from: accounts[6],
        });
      } catch (e) {
        assert(e.message.includes("Error: Item already exists"));
        return;
      }
      assert(false);
    });

    it("Can't delete Order if items exist", async () => {
      try {
        await po.deleteOrder(accounts[5], accounts[7], 1, {
          from: accounts[6],
        });
      } catch (e) {
        assert(e.message.includes("Error: Items exist"));
        return;
      }
      assert(false);
    });

    it("Delete PO item", async () => {
      await po.deleteItem(accounts[5], accounts[7], 1, 1, {
        from: accounts[6],
      });
      const r = await !po.isItem(accounts[5], accounts[7], 1, 1, { from: accounts[6] });
      assert (!r);
    });

    it("Can't delete non existant item", async () => {
      try {
        await po.deleteItem(accounts[5], accounts[7], 1, 1, {
          from: accounts[6],
        });
      } catch (e) {
        assert(e.message.includes("Error: Item does not exist"));
        return;
      }
      assert(false);
    });

    it("Delete Order", async () => {
      await po.deleteOrder(accounts[5], accounts[7], 1, {
        from: accounts[6],
      });
      const r = await !po.isOrder(accounts[5], accounts[7], 1, { from: accounts[6] });
      assert (!r);
    });

    it("Can't delete non existant order", async () => {
      try {
        await po.deleteOrder(accounts[5], accounts[7], 1, {
          from: accounts[6],
        });
      } catch (e) {
        assert(e.message.includes("Error: Order does not exist"));
        return;
      }
      assert(false);
    });

  });
});
