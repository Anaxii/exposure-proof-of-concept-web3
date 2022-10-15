import Subnet from "../EVM/Subnet";
import Mainnet from "../EVM/Mainnet";

export default async function Baskets(eventHandler: any, config: Config, subnet: Subnet, networks: { [key: string]: Mainnet }) {

    subnet.monitorBaskets()

    eventHandler.on('NewPendingBasketTrades', function (data: any) {
        console.log('NewPendingBasketTrades', data);
    })

    eventHandler.on('NewPendingBasketTradesComplete', async function (data: any) {
        console.log('NewPendingBasketTradesComplete', data);
        let tokens: any = await subnet.getBasketTokens(data.basket)
        let mainnetTokens: string[] = []
        for (const i in tokens) {
            let t: string = await subnet.getMainnetAddress(tokens[i])
            mainnetTokens.push(tokens)
        }
        let productAddress = await networks[data.network.name].getSubnetProductAddress(data.basket)
        let amounts: string[] = []
        for (const i in mainnetTokens) {
            let bal = await networks[data.network.name].getBalance(mainnetTokens[i], productAddress)
            if (bal) {
                amounts.push(bal)
            } else {
                delete mainnetTokens[i]
            }
        }
        await subnet.updateBasketBalances(data.basket, data.amounts, data.tokens)
    })
}
