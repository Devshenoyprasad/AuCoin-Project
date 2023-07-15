import React from "react";
import "./index.css";

const Footer = () => {
  return (
    <div className="Footer">
      <div className="socials">
        <a
          href="https://github.com/Devshenoyprasad"
          className="fa fa-github"
        ></a>
        <a
          href="https://www.linkedin.com/in/prasad-shenoy-315117219/"
          className="fa fa-linkedin"
        ></a>
        <a
          href="https://www.instagram.com/prasad_shenoy_ind/"
          className="fa fa-instagram"
        ></a>
        <a
          href="https://twitter.com/prasad_shenoy19"
          className="fa fa-twitter"
        ></a>
      </div>
      <div style={{ padding: "25px 50px 25px 50px" }}>
        <a href="mailto:shenoyprasad24@gmail@gmail.com" className="Mail">
          shenoyprasad24@gmail.com
        </a>
      </div>
    </div>
  );
};

export default Footer;
