import Mainnet from "./src/mainnet";
import Subnet from "./src/subnet";

const events = require('events');
const fs = require('fs');

function getConfig() {
    let rawdata = fs.readFileSync('config.json');
    return JSON.parse(rawdata)
}

(async function () {
    let config = getConfig()
    let eventHandler = new events.EventEmitter();

    let networks: {[key: string]: Mainnet} = {}
    let s = new Subnet(config.subnet, eventHandler, config.private_key)
    for (const i in config.main_networks) {
        networks[config.main_networks[i].name] = new Mainnet(config.main_networks[i], eventHandler, config.private_key)
    }

    eventHandler.on('BridgeToSubnet', function (data: any) {
        console.log('ToSubnet', data);
        s.bridgeToSubnet(data.asset, data.user, data.amount, data.assetName, data.assetSymbol)
    })
    eventHandler.on('BridgeToMainnet', function (data: any) {
        console.log('ToMainnet', data);
        networks[data.network.name].bridgeToMainnet(data.assetMainnet, data.user, data.amount, data.assetSymbol, data.network.name)
    })
}())
