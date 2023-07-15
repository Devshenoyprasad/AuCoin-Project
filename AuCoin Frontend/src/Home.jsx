import React, { useState } from "react";
import { ethers } from "ethers";
import config from "./config.json";

const Home = (props) => {
  const provider = props.provider;
  const balance = Number(props.accinfo[0]) / 100000000;
  const collateralVal = Number(props.accinfo[1]) / 100000000;
  const healthFactor = Number(props.health) / 1000000000000000000;
  const balprice = (Number(props.balprice) / 1000000000000000000).toPrecision(
    6
  );
  const colprice = (Number(props.colprice) / 1000000000000000000).toPrecision(
    6
  );
  console.log(balprice);
  console.log(props.colPrice);
  // if (!props) {
  //   const [balance, collateralVal] = props;
  // }
  const mintHandler = async (val) => {
    const signer = await provider.getSigner();
    let transaction = await props.Auce.connect(signer).mintAuc(val);
    await transaction.wait();
  };
  const depositHandler = async (val) => {
    val = val * 1000000000000000000;
    const weth = new ethers.Contract(
      config["11155111"]["weth"]["address"],
      AUCENGINE,
      provider
    );
    let transaction = await weth
      .connect(signer)
      .approve(config[network.chainId].AuCEngine.address, val);
    await transaction.wait();
    const signer = await provider.getSigner();
    transaction = await props.Auce.connect(signer).depositCollateral(
      config["11155111"]["weth"]["address"],
      val
    );
    await transaction.wait();
  };
  const redeemHandler = async () => {
    val = val * 1000000000000000000;
    const signer = await provider.getSigner();
    let transaction = await props.Auce.connect(signer).redeemCollateral(
      config["11155111"]["weth"]["address"],
      val
    );
    await transaction.wait();
  };
  const burnHandler = async (val) => {
    val = val * 100000000;
    const signer = await provider.getSigner();
    let transaction = await props.Auce.connect(signer).burnAuc(val);
    await transaction.wait();
  };
  const liquidateHandler = () => {};
  const Operations = (props) => {
    const [val, setVal] = useState("");
    const { mint, deposit, redeem, burn, liquidate } = props.task;
    return (
      <form>
        <h2>
          {(mint && "Mint AuCoins") ||
            (deposit && "Deposit Collateral") ||
            (redeem && "Redeem Collateral") ||
            (burn && "Burn AuCoins")}
        </h2>
        <input
          onChange={(e) => {
            console.log(val);
            setVal(e.target.value);
          }}
          type="text"
          name="input"
          value={val}
        ></input>
        <div
          style={{
            display: "flex",
            flexDirection: "row",
            justifyContent: "space-between",
          }}
        >
          <div></div>
          <button
            onClick={(e) => {
              e.preventDefault();
              if (mint) mintHandler(val);
              if (deposit) depositHandler(val);
              if (redeem) redeemHandler(val);
              if (burn) burnHandler(val);
            }}
          >
            Transact
          </button>
        </div>
      </form>
    );
  };
  return (
    <div className="Home">
      <p className="intro">
        Mint, Secure, Prosper:<br></br>
        AuCoin - The Golden Standard in Digital Finance
      </p>
      <div
        style={{
          display: "flex",
          flexDirection: "row",
          justifyContent: "space-between",
        }}
      >
        <div style={{ width: "50%" }}>
          <span>About AuCoin ...</span>
          <p className="About" id="Form">
            AuCoin represents a groundbreaking{" "}
            <a>fusion of gold and the digital realm</a>, transforming the way we
            perceive and engage with finance.By harnessing the intrinsic value
            and stability of gold, AuCoin provides a gateway to a new era of{" "}
            <a>financial security</a>. With AuCoin, individuals can easily
            access the timeless allure of gold without the logistical
            complexities. Each <a>ERC20 token</a> is securely{" "}
            <a>pegged to the value of gold</a>, offering a tangible{" "}
            <a>asset in the digital space</a>. Say goodbye to volatility and
            embrace a reliable store of wealth.
          </p>
          <br></br>
          <span>How it works ...</span>
          <p className="HowtoUse">There are basically Five operations:</p>
          <ul>
            <li>Mint AuCoin</li>
            <li>Burn Aucoin</li>
            <li>Deposit Collateral</li>
            <li>Redeem Collateral</li>
            <li>Liquidate</li>
          </ul>
        </div>
        <div className="Interface">
          <div className="accountinfo">
            <div className="accountinfonum">
              <p style={{ marginBottom: "0px" }}>
                <strong>Balance</strong>
              </p>
              <p style={{ margin: "0  0 30px 0 " }}>{balance || "0"} AUC</p>
              <p style={{ margin: "0px" }}>
                <strong>Collateral </strong>
              </p>
              <p style={{ margin: "0  0 30px 0 " }}>
                {collateralVal || "0"} AUC
              </p>
              <p style={{ margin: "0px" }}>
                <strong>Health Factor</strong>{" "}
              </p>
              <p style={{ margin: "0  0 30px 0 " }}>{healthFactor}</p>
            </div>
            <div className="chart">
              {" "}
              <p style={{ marginBottom: "0px" }}>
                <strong>Balance Value</strong>
              </p>
              <p style={{ margin: "0  0 30px 0 " }}>{balprice} USD</p>
              <p style={{ margin: "0px" }}>
                <strong>Collateral Value</strong>
              </p>
              <p style={{ margin: "0  0 30px 0 " }}>{colprice} USD</p>
            </div>
          </div>
          <Operations task={props.task}></Operations>
        </div>
      </div>
      <div>
        <p className="HowtoUse">
          In order to <a>mint</a> the AuCoin, the user must <a>deposit</a> some
          collateral (Wrapped ETH). For the deposited collateral the maximum
          amount of Aucoin that can be minted is determined by the{" "}
          <a>Health Factor</a> of the User. The User is expected to maintain the{" "}
          <a>Health Factor greater than 1 (unity)</a>. The whole idea of having
          a collateral is to ensure that the AuCoin doesn't fail. The system is
          designed in a way which ensures that it is always over-collateralized,
          so be relaxed as your wealth is safe.The User can maintain the Health
          Factor by either burning the AuCoins or by depositing more collateral.
          The User can also <a>redeem</a> the collateral until the Health Factor
          is not less that 1 (unity).
        </p>
        <p className="HowtoUse">
          If due to market factors, the value of the collateral plumates to a
          point that the <a>Health Factor becomes less than 1 (unity)</a>, the
          User's collateral can be <a>liquidated</a> by other users. The
          collateral will be transferred to them at a <a>discounted price</a> in
          exchange of AuCoins which will be then burned by the system. This is
          to ensure that the system remains over-collateralized and for{" "}
          <a>rewarding the users</a> who are protecting the system.
        </p>
        <p className="HowtoUse">
          We are working towards including other on-Chain assets like NFTs as
          collateral. If you want to know more about the AuCoin ecosystem feel
          free to <a>Contact us</a>.
        </p>
      </div>
    </div>
  );
};

export default Home;
