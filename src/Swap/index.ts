import Mainnet from "./Mainnet";
import Subnet from "./Subnet";
import {writeJSON, getJSON} from "../util/Util";

function checkTokenList(symbol: string, address: string, network: string, eventHandler: any) {
    let tokens = getJSON("tokens.json")

    if (!tokens[symbol]) {
        tokens[symbol] = {[network]: address}
        console.log(`Added ${symbol} on ${network} for oracle tracking`)
        eventHandler.emit('checkForPairs', {symbol, network})
    } else {
        for (const i in tokens[symbol]) {
            if (tokens[symbol][i][network])
                return
        }
        tokens[symbol][network] = address
        eventHandler.emit('checkForPairs', {symbol, network})
    }
    writeJSON("tokens.json", tokens)
}

export default async function Swap(eventHandler: any, config: Config, subnet: Subnet, networks: { [key: string]: Mainnet }) {

    eventHandler.on('BridgeToSubnet', function (data: any) {
        console.log('ToSubnet', data);
        subnet.bridgeToSubnet(data.asset, data.user, data.amount, data.assetName, data.assetSymbol)
        checkTokenList(data.assetSymbol, data.asset, data.network.name, eventHandler)
    })
    eventHandler.on('BridgeToMainnet', function (data: any) {
        console.log('ToMainnet', data);
        networks[data.network.name].bridgeToMainnet(data.assetMainnet, data.user, data.amount, data.assetSymbol, data.network.name)
    })
}
