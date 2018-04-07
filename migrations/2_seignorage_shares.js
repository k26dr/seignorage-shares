var SeignorageController = artifacts.require("./SeignorageController.sol");
var VariableSupplyToken = artifacts.require("./VariableSupplyToken.sol");

module.exports = function(deployer) {
    var sharesAddress, coinsAddress;

    deployer.deploy(VariableSupplyToken, "Seignorage Shares", "SGS", 1e25)
    .then(() => sharesAddress = VariableSupplyToken.address)
    .then(() => deployer.deploy(VariableSupplyToken, "Seignorage Coins", "SGC", 1e25))
    .then(() => coinsAddress = VariableSupplyToken.address)
    .then(() => deployer.deploy(SeignorageController, sharesAddress, coinsAddress));
};
