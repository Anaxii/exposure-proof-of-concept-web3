import Mainnet from "./Mainnet";
import Subnet from "./Subnet";

const events = require('events');
const fs = require('fs');

function getConfig() {
    let rawdata = fs.readFileSync('config.json');
    return JSON.parse(rawdata)
}

function checkTokenList(symbol: string, address: string) {
    let rawdata = fs.readFileSync('tokens.json');
    let tokens = JSON.parse(rawdata)

    if (!tokens[symbol]) {
        tokens[symbol] = [symbol]
    } else {
        for (const i in tokens[symbol]) {
            if (tokens[symbol][i] == address)
                return
        }
        tokens[symbol].push(address)
    }
    fs.writeFileSync('tokens.json', JSON.stringify(tokens, null, 4))
}

export default async function Swap() {

    let config = getConfig()
    let eventHandler = new events.EventEmitter();
    if (process.env.pkey) {
        config.private_key = process.env.pkey
    }

    let networks: {[key: string]: Mainnet} = {}
    let s = new Subnet(config.subnet, eventHandler, config.private_key)
    for (const i in config.main_networks) {
        networks[config.main_networks[i].name] = new Mainnet(config.main_networks[i], eventHandler, config.private_key)
    }

    eventHandler.on('BridgeToSubnet', function (data: any) {
        console.log('ToSubnet', data);
        s.bridgeToSubnet(data.asset, data.user, data.amount, data.assetName, data.assetSymbol)
        checkTokenList(data.assetSymbol, data.asset)
    })
    eventHandler.on('BridgeToMainnet', function (data: any) {
        console.log('ToMainnet', data);
        networks[data.network.name].bridgeToMainnet(data.assetMainnet, data.user, data.amount, data.assetSymbol, data.network.name)
    })
}
