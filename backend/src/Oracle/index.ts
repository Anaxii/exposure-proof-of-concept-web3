import {getJSON, sleep, writeJSON} from "../util";
import Subnet from "../EVM/Subnet";
import Mainnet from "../EVM/Mainnet";

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
    rule.minute = [0, new schedule.Range(0, 59)];

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
    let tokenPrices: { [key: string]: any } = await loopPairs(networks, "computePrices")

    let finalPrices: { [key: string]: any } = {}
    for (const token in tokenPrices) {
        let sum = BigInt(0)
        for (const index in tokenPrices[token]) {
            sum += BigInt(tokenPrices[token][index])
        }
        finalPrices[token] = (sum / BigInt(tokenPrices[token].length)).toString()
    }

    writeJSON("prices.json", finalPrices)

    console.log("Updated prices")
}

async function updateSubnetPrices(subnet: Subnet) {
    let prices = getJSON("prices.json")
    let tokens = getJSON("tokens.json")

    let tokenList: any[][] = [[]]
    let priceList: any[][] = [[]]
    for (const i in prices) {
        if (tokenList.length > 20) {
            tokenList.push([])
            priceList.push([])
        }
        priceList[priceList.length - 1].push(prices[i])
        tokenList[tokenList.length - 1].push(tokens[i]['fuji'])
    }

    for (const i in tokenList) {
        let success = await subnet.updatePrices(tokenList[i], priceList[i])
        if (!success)
            console.log(`Failed to update subnet prices`)
    }

    console.log("Finished updating subnet prices")
}

async function loopPairs(networks: { [key: string]: Mainnet }, type: string) {
    let tokens: any = getJSON("pairs.json")
    let dollarCoins: any = getJSON("dollar_coins.json")
    let routers: any = getJSON("routers.json")

    let tokenPrices: { [key: string]: any } = {}
    let quotePrices: { [key: string]: any } = {}
    let toUpdate: { [key: string]: any[] } = {}

    for (const token in tokens) {
        tokenPrices[token] = []
        for (const network in tokens[token]) {
            if (type == "updateMainnet") {
                if (!toUpdate[network])
                    toUpdate[network] = [[]]
            }
            for (const dex in tokens[token][network]) {
                for (const trading_pair in tokens[token][network][dex]) {
                    if (type == "updateMainnet") {
                        if (toUpdate[network][toUpdate[network].length - 1].length >= 20)
                            toUpdate[network].push([])
                        toUpdate[network][toUpdate[network].length - 1].push({
                            pair: tokens[token][network][dex][trading_pair].pair,
                            token: tokens[token][network][dex][trading_pair].token,
                            quote: tokens[token][network][dex][trading_pair].quote
                        })
                    } else {
                        let price = await await networks[network].getPrice(tokens[token][network][dex][trading_pair].pair)
                        if (!dollarCoins[network][tokens[token][network][dex][trading_pair].quoteName]) {
                            let qp = quotePrices[tokens[token][network][dex][trading_pair].quote]
                            if (!qp) {
                                let router = routers[network][dex]
                                let pairAddress = await networks[network].getPairAddress(router, tokens[token][network][dex][trading_pair].quote, dollarCoins[network]["USDC"])
                                if (pairAddress == "")
                                    continue
                                let success = await networks[network].updatePrices([pairAddress], [tokens[token][network][dex][trading_pair].quote], [dollarCoins[network]["USDC"]])
                                if (!success)
                                    continue
                                qp = await networks[network].getPrice(pairAddress)
                            }
                            quotePrices[tokens[token][network][dex][trading_pair].quote] = qp
                            tokenPrices[token].push((BigInt(price) * BigInt(10 ** 18) / BigInt(qp)).toString())
                            continue
                        }
                        tokenPrices[token].push(price)
                    }
                }
            }
        }
    }

    if (type == "updateMainnet") {
        return toUpdate
    } else {
        return tokenPrices
    }
}

async function updateMainnetPrices(api_urls: any, networks: { [key: string]: Mainnet }) {

    let toUpdate: { [key: string]: any[] } = await loopPairs(networks, "updateMainnet")
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
    let routers = getJSON("routers.json")[network]
    let router_pairs: { [key: string]: any } = {}
    for (const router in routers) {
        let r = routers[router]

        let liquidity_tokens = getJSON("liquidity_tokens.json")
        let pair_tokens: { [key: string]: any } = {}
        for (const i in liquidity_tokens) {
            pair_tokens[i] = liquidity_tokens[i][network]
        }

        let token_address = getJSON("tokens.json")[symbol][network]
        let pairs: { [key: string]: any } = {}
        for (const i in pair_tokens) {
            let pair = await networks[network].getPairAddress(r, token_address, pair_tokens[i])
            if (pair != "0x0000000000000000000000000000000000000000" && pair != "")
                pairs[symbol + "/" + i] = {
                    pair: pair,
                    token: token_address,
                    quote: pair_tokens[i],
                    tokenName: symbol,
                    quoteName: i
                }
        }
        router_pairs[router] = pairs

    }

    let stored_pairs = getJSON("pairs.json")
    if (!stored_pairs[symbol])
        stored_pairs[symbol] = {}
    if (!stored_pairs[symbol][network])
        stored_pairs[symbol][network] = {}
    stored_pairs[symbol][network] = router_pairs

    console.log(`Updated ${symbol} in pairs.json`)

    writeJSON("pairs.json", stored_pairs)
}
