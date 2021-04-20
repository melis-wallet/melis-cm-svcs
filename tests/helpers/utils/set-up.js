import CMCore from 'melis-api-js';
import Logger from 'melis-cm-svcs/utils/logger';
const {
  C
} = CMCore;

const setup = {

  setupEnroll(session, pin, accountName) {

    return session.waitForConnect().then( () => {
      Logger.warn("--- Enrolling");
      return session.enrollWallet(pin);
    }).then((wallet) => {
      Logger.warn("--- Creating account");
      return session.accountCreate({type: C.TYPE_PLAIN_HD, meta:  {name: accountName} });
    }).then( (account) => {
      session.selectAccount(account.pubId);
      return session.waitForReady();
    });
  }
};


export default setup;
