import React, { useState, useEffect } from "react";
import { ethers } from "ethers";
import logo from "./assets/logo.png";
import Home from "./Home";
import Footer from "./Footer";
import AUCENGINE from "./AUCEngine.json";
import config from "./config.json";

const App = () => {
  // const [accountinfo, setAccountinfo] = useState(null);
  const [account, setAccount] = useState("");
  const [accountinformation, setaccountinformation] = useState({
    balance: 0,
    CollateralVal: 0,
  });
  const [AUCEngine, setAUCEngine] = useState(null);
  const [provider, setProvider] = useState(null);
  const [balancePrice, setBalancePrice] = useState(null);
  const [collateralPrice, setCollateralPrice] = useState(null);
  const [healthFactor, setHealthFactor] = useState(null);
  const [operations, setOperations] = useState({
    mint: true,
    deposit: false,
    redeem: false,
    burn: false,
    liquidate: false,
  });
  const connectHandler = async () => {
    const accounts = await window.ethereum.request({
      method: "eth_requestAccounts",
    });
    const accountinformation = await AUCEngine.getAccountInformation(
      accounts[0]
    );
    const healthFactor = await AUCEngine.getHealthFactor(accounts[0]);
    const balancePrice = await AUCEngine._getUsdValueCoin(
      accountinformation[0]
    );
    const collateralPrice = await AUCEngine._getUsdValueCoin(
      accountinformation[1]
    );
    setBalancePrice(balancePrice);
    setCollateralPrice(collateralPrice);
    setHealthFactor(healthFactor);
    setaccountinformation(accountinformation);
    setAccount(accounts[0]);
  };
  const loadBlockchainData = async () => {
    const provider = new ethers.BrowserProvider(window.ethereum);
    const network = await provider.getNetwork();
    const AUCEngine = new ethers.Contract(
      config[network.chainId].AuCEngine.address,
      AUCENGINE,
      provider
    );
    setProvider(provider);
    setAUCEngine(AUCEngine);

    window.ethereum.on("accountsChanged", async () => {
      const accounts = await window.ethereum.request({
        method: "eth_requestAccounts",
      });
      const account = ethers.utils.getAddress(accounts[0]);
      setAccount(account);
    });
  };
  useEffect(() => {
    loadBlockchainData();
  }, []);
  return (
    <div className="App">
      <div className="Navigation">
        <img src={logo} alt="Logo"></img>
        <div className="Operations">
          <button
            onClick={() => {
              const obj = {
                mint: true,
                deposit: false,
                redeem: false,
                burn: false,
                liquidate: false,
              };
              setOperations(obj);
            }}
          >
            <a href="#Form">Mint</a>
          </button>
          <button
            onClick={() => {
              const obj = {
                mint: false,
                deposit: true,
                redeem: false,
                burn: false,
                liquidate: false,
              };
              setOperations(obj);
            }}
          >
            <a href="#Form">Deposit</a>
          </button>
          <button
            onClick={() => {
              const obj = {
                mint: false,
                deposit: false,
                redeem: true,
                burn: false,
                liquidate: false,
              };
              setOperations(obj);
            }}
          >
            <a href="#Form">Redeem</a>
          </button>
          <button
            onClick={() => {
              const obj = {
                mint: false,
                deposit: false,
                redeem: false,
                burn: true,
                liquidate: false,
              };
              setOperations(obj);
            }}
          >
            <a href="#Form">Burn</a>
          </button>
          <button
            onClick={() => {
              const obj = {
                mint: false,
                deposit: false,
                redeem: false,
                burn: false,
                liquidate: true,
              };
              setOperations(obj);
            }}
          >
            <a href="#Form">Liquidate</a>
          </button>
        </div>
        <button className="walletConnect" onClick={() => connectHandler()}>
          {account
            ? account.slice(0, 7) + " . . . . . " + account.slice(35)
            : "Connect Wallet"}
        </button>
      </div>
      <Home
        task={operations}
        accinfo={accountinformation}
        health={healthFactor}
        Auce={AUCEngine}
        provider={provider}
        colprice={collateralPrice}
        balprice={balancePrice}
      ></Home>
      <Footer></Footer>
    </div>
  );
};

export default App;
