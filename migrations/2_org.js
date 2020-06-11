const ORG = artifacts.require("org");

module.exports = function(deployer, _network, accounts  ) {
  deployer.deploy(ORG);
};
