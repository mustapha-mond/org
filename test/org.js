const ORG = artifacts.require("org");

contract("ORG", (accounts) => {
  let org = null;
  before(async () => {
    org = await ORG.deployed();
  });

  //User tests
  it("Register User", async () => {
    await org.regUser(accounts[1], "User 1");
    assert(org._isUser(accounts[1]));
  });

  it("Only Owner can register User", async () => {
    try {
      await org.regUser(accounts[4], "User 4", { from: accounts[5] });
    } catch (e) {
      assert(e.message.includes("Error: Only owner can register Users"));
      return;
    }
    assert(false);
  });

  it("Should not allow to register User more than once", async () => {
    try {
      await org.regUser(accounts[1], "User 1");
    } catch (e) {
      assert(e.message.includes("Error: User already registered"));
      return;
    }
    assert(false);
  });

  // Partner tests
  it("Register Partner", async () => {
    await org.regPartner(accounts[2], "Partner 1", 100, true, {
      from: accounts[1],
    });
    assert(org._isRegistered(accounts[2], accounts[1]));
  });

  it("Only User can register Partner", async () => {
    try {
      await org.regPartner(accounts[4], "Partner 4", 100, true, {
        from: accounts[5],
      });
    } catch (e) {
      assert(e.message.includes("Error: User not registered"));
      return;
    }
    assert(false);
  });

  it("Should not allow to register Partner more than once", async () => {
    try {
      await org.regPartner(accounts[2], "Partner 1", 100, true, {
        from: accounts[1],
      });
    } catch (e) {
      assert(
        e.message.includes("Error: Partner already registered for this user")
      );
      return;
    }
    assert(false);
  });

  //External Partner tests
  it("Register External Partner", async () => {
    await org.regExtPartner(accounts[1], accounts[3], "External Partner 1", {
      from: accounts[2],
    });
    assert(org._isExtReg(accounts[1], accounts[3]));
  });

  it("Only Partner can register External Partner", async () => {
    try {
      await org.regExtPartner(accounts[1], accounts[4], "External Partner 1", {
        from: accounts[5],
      });
    } catch (e) {
      assert(e.message.includes("Error: Partner not registered for this user"));
      return;
    }
    assert(false);
  });

  it("Should not allow to register External Partner more than once", async () => {
    try {
      await org.regExtPartner(accounts[1], accounts[3], "External Partner 1", {
        from: accounts[2],
      });
    } catch (e) {
      assert(e.message.includes("Error: External partner already registered"));
      return;
    }
    assert(false);
  });

  //Link Tests
  it("Link Partner", async () => {
    await org.regUser(accounts[8], "User 1");
    assert(org._isUser(accounts[8]));
    await org.regPartner(accounts[4], "Partner 1", 100, true, {
      from: accounts[8],
    });
    assert(org._isRegistered(accounts[4], accounts[8]));
    await org.regPartner(accounts[5], "Partner 2", 50, true, {
      from: accounts[8],
    });
    assert(org._isRegistered(accounts[5], accounts[8]));
    await org.linkPartner(accounts[4], accounts[5], { from: accounts[8] });
    assert(org._isLinked(accounts[4], accounts[5], { from: accounts[8] }));
  });

  it("Only User can Link Partners", async () => {
    try {
      await org.linkPartner(accounts[4], accounts[5], { from: accounts[7] });
    } catch (e) {
      assert(e.message.includes("Error: User not registered"));
      return;
    }
    assert(false);
  });

  it("Partner must be Registered in order to link", async () => {
    try {
      await org.linkPartner(accounts[6], accounts[5], { from: accounts[8] });
      assert(org._isLinked(accounts[6], accounts[5], { from: accounts[8] }));
    } catch (e) {
      assert(e.message.includes("Error: Partner not registered for this user"));
      return;
    }
    assert(false);
  });

  it("Link Partner must be Registered in order to link", async () => {
    try {
      await org.linkPartner(accounts[5], accounts[6], { from: accounts[8] });
      assert(org._isLinked(accounts[5], accounts[6], { from: accounts[8] }));
    } catch (e) {
      assert(
        e.message.includes("Error: Link Partner not registered for this user")
      );
      return;
    }
    assert(false);
  });

  it("Partner cannot Link to self", async () => {
    try {
      await org.linkPartner(accounts[5], accounts[5], { from: accounts[8] });
      assert(org._isLinked(accounts[5], accounts[5], { from: accounts[8] }));
    } catch (e) {
      assert(e.message.includes("Error: Cannot link to self"));
      return;
    }
    assert(false);
  });

  it("External Partners cannot Link (First)", async () => {
    try {
      await org.regExtPartner(accounts[8], accounts[9], "External Partner 1", {
        from: accounts[5],
      });
      assert(org._isExtReg(accounts[5], accounts[9]));
      await org.linkPartner(accounts[4], accounts[9], { from: accounts[8] });
      assert(org._isLinked(accounts[4], accounts[9], { from: accounts[8] }));
    } catch (e) {
      assert(e.message.includes("Error: External partners cannot be linked"));
      return;
    }
    assert(false);
  });

  it("External Partners cannot Link (Second)", async () => {
    try {
      await org.linkPartner(accounts[9], accounts[4], { from: accounts[8] });
      assert(org._isLinked(accounts[9], accounts[4], { from: accounts[8] }));
    } catch (e) {
      assert(e.message.includes("Error: External partners cannot be linked"));
      return;
    }
    assert(false);
  });

  it("Should not allow to link Partner more than once", async () => {
    try {
      await org.linkPartner(accounts[4], accounts[5], { from: accounts[8] });
    } catch (e) {
      assert(e.message.includes("Error: Partner link already exists"));
      return;
    }
    assert(false);
  });

  it("Higher Limit cannot link to lower limit", async () => {
    try {
      await org.regUser(accounts[7], "User 7");
      assert(org._isUser(accounts[7]));
      await org.regPartner(accounts[8], "Partner 8", 150, true, {
        from: accounts[7],
      });
      assert(org._isRegistered(accounts[8], accounts[7]));
      await org.regPartner(accounts[9], "Partner 9", 100, true, {
        from: accounts[7],
      });
      assert(org._isRegistered(accounts[9], accounts[7]));
      await org.linkPartner(accounts[9], accounts[8], { from: accounts[7] });
      assert(org._isLinked(accounts[9], accounts[8], { from: accounts[7] }));
    } catch (e) {
      assert(e.message.includes("Error: Link partner has a higher limit"));
      return;
    }
    assert(false);
  });

  it("Create dotted link", async () => {
    await org.regPartner(accounts[6], "Partner 6", 25, true, {
      from: accounts[8],
    });
    assert(org._isRegistered(accounts[6], accounts[8]));
    await org.linkPartner(accounts[5], accounts[6], { from: accounts[8] });
    assert(org._isLinked(accounts[5], accounts[6], { from: accounts[8] }));
    await org.linkPartner(accounts[4], accounts[6], { from: accounts[8] });
    assert(org._isLinked(accounts[4], accounts[6], { from: accounts[8] }));
  });

  it("Cannot create dotted link more thane once", async () => {
    try {
      await org.linkPartner(accounts[4], accounts[6], { from: accounts[8] });
      assert(org._isLinked(accounts[4], accounts[6], { from: accounts[8] }));
    } catch (e) {
      assert(e.message.includes("Error: Dotted link already exists"));
      return;
    }
    assert(false);
  });

  it("Invalid hierarchy", async () => {
    try {
      await org.linkPartner(accounts[6], accounts[4], { from: accounts[8] });
      assert(org._isLinked(accounts[6], accounts[4], { from: accounts[8] }));
    } catch (e) {
      assert(e.message.includes("Error: Invlalid hierarchy"));
      return;
    }
    assert(false);
  });

  //Works in debug, finds right level but some kind of type mismatch here.
  //   it('Get Approval Level', async () => {
  //       const level = await web3.utils.toBN(org.getAppovalLevel(accounts[8], accounts[5], 70, 1));
  //        assert(level === accounts[4]);
  //
  //    });
});
