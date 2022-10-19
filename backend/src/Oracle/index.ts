import {getJSON, sleep, writeJSON} from "../util";
import Subnet from "../EVM/Subnet";
import Mainnet from "../EVM/Mainnet";
import {dbInsert, dbQueryAll} from "../Database";

const schedule = require('node-schedule');

export default async function Oracle(eventHandler: any, config: any, subnet: Subnet, networks: { [key: string]: Mainnet }) {
    let api_urls: { [key: string]: string } = {}
    for (const i in config["main_networks"]) {
        api_urls[config["main_networks"][i].name] = config["main_networks"][i].api_url
    }
    api_urls[config["subnet"].name] = config["subnet"].api_url

    let checkingPairs = false
    let updatingPrices = false
    eventHandler.on('checkForPairs', async function (data: any) {
        while (checkingPairs) {
            await sleep(500)
        }
        console.log('checkForPairs', data);
        checkingPairs = true
        await checkForDEXPairs(networks, data.symbol, data.network)
        checkingPairs = false
    })

    const rule = new schedule.RecurrenceRule();
    rule.second = [0, new schedule.Range(0, 59)];
    schedule.scheduleJob(rule, async () => {
        while (checkingPairs) {
            await sleep(500)
        }
        updatingPrices = true
        console.log('Starting price update loop');
        await updateMainnetPrices(api_urls, networks)
        await computePrices(networks)
        await updateSubnetPrices(subnet)
        updatingPrices = false
        console.log("Finished price update loop")
    });
}

async function computePrices(networks: { [key: string]: Mainnet }) {
    let data = await loopPairs(networks, "computePrices")
    let tokenPrices: { [key: string]: any } = data.tokenPrices
    let tokenMCAPS: { [key: string]: any } = data.tokenMCAPS

    for (const token in tokenPrices) {
        let sum = BigInt(0)
        for (const index in tokenPrices[token]) {
            sum += BigInt(tokenPrices[token][index])
        }
        if (sum == BigInt(0))
            continue
        await dbInsert(
            "INSERT OR IGNORE INTO prices (token_name, price) VALUES (?, ?)",
            [token, (sum / BigInt(tokenPrices[token].length)).toString()])
        await dbInsert(
            " UPDATE prices SET price = ? WHERE token_name = ?",
            [(sum / BigInt(tokenPrices[token].length)).toString(), token])
    }

    for (const token in tokenMCAPS) {
        let sum = BigInt(0)
        for (const index in tokenMCAPS[token]) {
            sum += BigInt(tokenMCAPS[token][index])
        }
        if (sum == BigInt(0))
            continue
        await dbInsert(
            "INSERT OR IGNORE INTO mcaps (token_name, mcap) VALUES (?, ?)",
            [token, (sum / BigInt(tokenMCAPS[token].length)).toString()])
        await dbInsert(
            "UPDATE mcaps SET mcap = ? WHERE token_name = ?",
            [(sum / BigInt(tokenMCAPS[token].length)).toString(), token])
    }

    console.log("Updated prices")
}

async function updateSubnetPrices(subnet: Subnet) {
    let tokens: any = await dbQueryAll("SELECT * FROM tokens", null)

    let tokenList: any[][] = [[]]
    let priceList: any[][] = [[]]
    let mcapList: any[][] = [[]]
    for (const i in tokens) {
        if (tokenList.length > 20) {
            tokenList.push([])
            priceList.push([])
            mcapList.push([])
        }
        let price: any = await dbQueryAll("SELECT * FROM prices WHERE token_name = ?", [tokens[i].token_name])
        let mcap: any = await dbQueryAll("SELECT * FROM mcaps WHERE token_name = ?", [tokens[i].token_name])
        if (price.length > 0 && mcap.length > 0) {
            priceList[priceList.length - 1].push(price[0].price.toString())
            mcapList[priceList.length - 1].push(mcap[0].mcap.toString())
            tokenList[tokenList.length - 1].push(tokens[i].contract_address)
        }
    }

    for (const i in tokenList) {
        let success = await subnet.updatePrices(tokenList[i], priceList[i], mcapList[i])
        if (!success)
            console.log(`Failed to update subnet prices`)
    }

    console.log("Finished updating subnet prices")
}

async function loopPairs(networks: { [key: string]: Mainnet }, type: string) {
    let pairs: any = await dbQueryAll("SELECT * FROM pairs", null)

    let tokenPrices: { [key: string]: any } = {}
    let tokenMCAPS: { [key: string]: any } = {}
    let quotePrices: { [key: string]: any } = {}
    let toUpdate: { [key: string]: any[] } = {}

    for (const i in pairs) {
        let network = pairs[i].network_name
        tokenPrices[pairs[i].token_name] = []
        tokenMCAPS[pairs[i].token_name] = []

        if (type == "updateMainnet") {
            if (!toUpdate[network])
                toUpdate[network] = [[]]
            if (toUpdate[network][toUpdate[network].length - 1].length >= 20)
                toUpdate[network].push([])
            toUpdate[network][toUpdate[network].length - 1].push({
                pair: pairs[i].pair_address,
                token: pairs[i].token_address,
                quote: pairs[i].quote_address
            })
        } else {
            let price = await networks[network].getPrice(pairs[i].pair_address)
            let mcap = await networks[network].getMCAP(pairs[i].pair_address)
            if (price == 0 || mcap == 0 || price == "" || mcap == "")
                continue
            let dollar_coin: any = await dbQueryAll(
                "SELECT * FROM dollar_coins WHERE network_name = ? AND contract_address = ?",
                [network, pairs[i].quote_address]
            )
            if (dollar_coin.length == 0) {
                dollar_coin = await dbQueryAll(
                    "SELECT contract_address FROM dollar_coins WHERE network_name = ? AND token_name = ?",
                    [network, "USDC"]
                )
                let qp = quotePrices[pairs[i].quote_address]
                if (!qp) {
                    let router: any = await dbQueryAll(
                        "SELECT contract_address FROM routers WHERE network_name = ? AND dex_name = ?",
                        [network, pairs[i].dex_name]
                    )
                    let pairAddress = await networks[network].getPairAddress(router.contract_address,  pairs[i].quote_address, dollar_coin.contract_address)
                    if (pairAddress == "")
                        continue
                    let success = await networks[network].updatePrices([pairAddress], [pairs[i].quote_address], [dollar_coin.contract_address])
                    if (!success)
                        continue
                    qp = await networks[network].getPrice(pairAddress)
                }
                quotePrices[pairs[i].quote_address] = qp
                tokenPrices[pairs[i].token_name].push((BigInt(price) * BigInt(10 ** 18) / BigInt(qp)).toString())
                tokenMCAPS[pairs[i].token_name].push((BigInt(mcap) * BigInt(10 ** 18) / BigInt(qp)).toString())
                continue
            }
            tokenPrices[pairs[i].token_name].push(price)
            tokenMCAPS[pairs[i].token_name].push(mcap)
        }
    }

    if (type == "updateMainnet") {
        return toUpdate
    } else {
        return {tokenPrices, tokenMCAPS}
    }
}

async function updateMainnetPrices(api_urls: any, networks: { [key: string]: Mainnet }) {

    let toUpdate: any = await loopPairs(networks, "updateMainnet")
    for (const network in toUpdate) {
        for (const batch in toUpdate[network]) {
            let _pairs = []
            let _tokens = []
            let _quotes = []
            for (const item in toUpdate[network][batch]) {
                _pairs.push(toUpdate[network][batch][item].pair)
                _tokens.push(toUpdate[network][batch][item].token)
                _quotes.push(toUpdate[network][batch][item].quote)
            }
            let success = await networks[network].updatePrices(_pairs, _tokens, _quotes)
            if (!success)
                console.log(`Failed to update mainnet prices`)
        }
    }

    console.log("Updated pair prices")
}

async function checkForDEXPairs(networks: { [key: string]: Mainnet }, symbol: any, network: any) {
    let routers: any = await dbQueryAll("SELECT * FROM routers WHERE network_name = ?", [network])
    for (const i in routers) {
        let r = routers[i].contract_address

        let liquidity_tokens: any = await dbQueryAll("SELECT * FROM liquidity_tokens WHERE network_name = ?", [network])
        let pair_tokens: { [key: string]: any } = {}
        for (const i in liquidity_tokens) {
            pair_tokens[liquidity_tokens[i].token_name] = liquidity_tokens[i].contract_address
        }

        let _token_address: any = await dbQueryAll("SELECT * FROM tokens WHERE network_name = ? AND token_name = ?", [network, symbol])
        let token_address = _token_address.contract_address
        for (const j in pair_tokens) {
            let pair = await networks[network].getPairAddress(r, token_address, pair_tokens[j])
            await dbInsert(
                "INSERT OR IGNORE INTO pairs (network_name, token_name, quote_name, dex_name, pair_name, pair_address, token_address, quote_address) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
                [network, symbol, j, routers[i].dex_name, symbol + "/" + j, pair, token_address, pair_tokens[j]])
        }
    }

    console.log(`Updated ${symbol} in pairs`)
}
