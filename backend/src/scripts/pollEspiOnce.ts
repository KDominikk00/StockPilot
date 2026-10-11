import { pollEspiFeed } from "../sources/espiPoller";

pollEspiFeed()
  .then((result) => {
    console.log(result);
  })
  .catch((error) => {
    console.error("Polling ESPI nie powiodło się:", error);
    process.exitCode = 1;
  });
