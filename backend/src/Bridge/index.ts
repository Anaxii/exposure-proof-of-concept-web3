import Mainnet from "../EVM/Mainnet";
import Subnet from "../EVM/Subnet";
import {dbInsert, dbQueryAll} from "../Database";

export async function checkTokenList(symbol: string, address: string, network: string, eventHandler: any) {
    let tokenCheck: any = await dbQueryAll(
        `SELECT *
         FROM tokens
         WHERE network_name = ?
           AND contract_address = ?`,
        [network, address])
    if (tokenCheck.length == 0) {
        await dbInsert(
            `INSERT INTO tokens(network_name, token_name, contract_address)
             VALUES (?, ?, ?)`,
            [network, symbol, address])
        console.log(`Added ${symbol} on ${network} for oracle tracking`)
        eventHandler.emit('checkForPairs', {symbol, network})
    }
}

export default async function Bridge(eventHandler: any, config: Config, subnet: Subnet, networks: { [key: string]: Mainnet }) {

    eventHandler.on('BridgeToSubnet', function (data: any) {
        console.log('ToSubnet', data);
        subnet.bridgeToSubnet(data.asset, data.user, data.amount, data._bridgeRequestID, data.assetName, data.assetSymbol)
        checkTokenList(data.assetSymbol, data.asset, data.network.name, eventHandler)
    })
    eventHandler.on('BridgeToMainnet', function (data: any) {
        console.log('ToMainnet', data);
        networks[data.network.name].bridgeToMainnet(data.asset, data.user, data.amount, data._bridgeRequestID, data.assetSymbol)
    })
}
