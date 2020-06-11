import Web3 from 'web3';
import ORG from '../build/contracts/org.json';

let web3;
let org;

const initWeb3 = () => {
  return new Promise((resolve, reject) => {
    if (typeof window.ethereum !== 'undefined') {
      const web3 = new Web3(window.ethereum);
      window.ethereum.enable()
        .then(() => {
          resolve(
            new Web3(window.ethereum)
          );
        })
        .catch(e => {
          reject(e);
        });
      return;
    }
    if (typeof window.web3 !== 'undefined') {
      return resolve(
        new Web3(window.web3.currentProvider)
      );
    }
    resolve(new Web3('http://localhost:9545'));
  });
};

const initContract = () => {
  const deploymentKey = Object.keys(ORG.networks)[0];
  return new web3.eth.Contract(
    ORG.abi,
    ORG
      .networks[deploymentKey]
      .address
  );
};

const initApp = () => {

  const $regUser = document.getElementById('regUser');
  const $regUserResult = document.getElementById('regUser-result');
  const $regPartner = document.getElementById('regPartner');
  const $regPartnerResult = document.getElementById('regPartner-result');
  const $changePartner = document.getElementById('changePartner');
  const $changePartnerResult = document.getElementById('changePartner-result');
  const $getPartner = document.getElementById('getPartner');
  const $getPartnerResult = document.getElementById('getPartner-result');
  const $regExtPartner = document.getElementById('regExtPartner');
  const $regExtPartnerResult = document.getElementById('regExtPartner-result');
  const $linkPartner = document.getElementById('linkPartner');
  const $linkPartnerResult = document.getElementById('linkPartner-result');


  let accounts = [];

  web3.eth.getAccounts()
    .then(_accounts => {
      accounts = _accounts;
    });
  //Register User
  $regUser.addEventListener('submit', (e) => {
    e.preventDefault();
    const address = e.target.elements[0].value;
    const name = e.target.elements[1].value;
    org.methods.regUser(address, name).send({ from: accounts[0] })
      .then(result => {
        $regUserResult.innerHTML = `User ${address} ${name} successfully registered`;
      })
      .catch(_e => {
        $regUserResult.innerHTML = `Error: User not registered`;
      });
  });

  //Register Partner
  $regPartner.addEventListener('submit', (e) => {
    e.preventDefault();
    const address = e.target.elements[0].value;
    const name = e.target.elements[1].value;
    const limit = e.target.elements[2].value;
    const canReg = e.target.elements[3].value;
    org.methods.regPartner(address, name, limit, true).send({ from: accounts[0] })
      .then(result => {
        $regPartnerResult.innerHTML = `Partner ${address} ${name} successfully registered`;
      })
      .catch(_e => {
        $regPartnerResult.innerHTML = `Error: Partner not registered`;
      });
  });

  //Change Partner
  $changePartner.addEventListener('submit', (e) => {
    e.preventDefault();
    const address = e.target.elements[0].value;
    const name = e.target.elements[1].value;
    org.methods.changePartner(address, name).send({ from: accounts[0] })
      .then(result => {
        $changePartnerResult.innerHTML = `Partner ${name} successfully changed`;
      })
      .catch(_e => {
        $changePartnerResult.innerHTML = `Error: Partner not changed`;
      });
  });

  //Get Partner
  $getPartner.addEventListener('submit', (e) => {
    e.preventDefault();
    const address = e.target.elements[0].value;
    org.methods.getPartner(address).call()
      .then(result => {
        $getPartnerResult.innerHTML = `Partner:  Name: ${result[0]} Linked: ${result[1]} Partner Index: ${result[2]} ${result[3]} ${result[4]} `;
      })
      .catch(_e => {
        $getPartnerResult.innerHTML = `Error: Call error`;
      });
  });

  //Register External Partner
  $regExtPartner.addEventListener('submit', (e) => {
    e.preventDefault();
    const address = e.target.elements[0].value;
    const extAddress = e.target.elements[1].value;
    const name = e.target.elements[2].value;
    org.methods.regExtPartner(address, extAddress, name).send({ from: accounts[0] })
      .then(result => {
        $regExtPartnerResult.innerHTML = ` External Partner ${extAddress} ${name} successfully registered`;
      })
      .catch(_e => {
        $regExtPartnerResult.innerHTML = `Error: External Partner not registered`;
      });
  });

  $linkPartner.addEventListener('submit', (e) => {
    e.preventDefault();
    const address = e.target.elements[0].value;
    const linkAddress = e.target.elements[1].value;
    org.methods.linkPartner(address, linkAddress).send({ from: accounts[0] })
      .then(result => {
        $linkPartnerResult.innerHTML = `Partner ${linkAddress} linked to ${address} `;
      })
      .catch(_e => {
        $linkExtPartnerResult.innerHTML = `Error: Partner not linked`;
      });
  });


};

document.addEventListener('DOMContentLoaded', () => {
  initWeb3()
    .then(_web3 => {
      web3 = _web3;
      org = initContract();
      initApp();
    })
    .catch(e => console.log(e.message));
});
