import {getJSON, writeJSON} from "../util/Util";
import Subnet from "../Swap/Subnet";
import Mainnet from "../Swap/Mainnet";

const {ethers} = require("ethers");

export default async function Oracle(eventHandler: any, config: any, subnet: Subnet, networks: { [key: string]: Mainnet }) {
    let api_urls: { [key: string]: string } = {}
    for (const i in config["main_networks"]) {
        api_urls[config["main_networks"][i].name] = config["main_networks"][i].api_url
    }
    api_urls[config["subnet"].name] = config["subnet"].api_url

    eventHandler.on('checkForPairs', function (data: any) {
        console.log('checkForPairs', data);
        checkForDEXPairs(data.symbol, data.network, api_urls[data.symbol])
    })
    await computePrices(networks)
    // await updateMainnetPrices(api_urls, networks)


}

async function computePrices(networks: { [key: string]: Mainnet }) {
    let tokenPrices: {[key: string]: any} = await loopPairs(networks, "computePrices")

    let finalPrices: {[key: string]: any} = {}
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

async function updateSubnetPrices() {

}

async function loopPairs(networks: { [key: string]: Mainnet }, type: string) {
    let tokens: any = getJSON("pairs.json")
    let dollarCoins: any = getJSON("dollar_coins.json")
    let routers: any = getJSON("routers.json")

    let tokenPrices: {[key: string]: any} = {}
    let quotePrices: {[key: string]: any} = {}

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
                        if (!dollarCoins[network][token]) {
                            let qp = quotePrices[tokens[token][network][dex][trading_pair].quote]
                            if (!qp) {
                                let router = routers[network][dex]
                                let pairAddress = await networks[network].getPairAddress(router, tokens[token][network][dex][trading_pair].quote, dollarCoins[network]["USDC"])
                                await networks[network].updatePrice([pairAddress], [tokens[token][network][dex][trading_pair].quote], [dollarCoins[network]["USDC"]])
                                qp = await networks[network].getPrice(pairAddress)
                            }
                            quotePrices[tokens[token][network][dex][trading_pair].quote] = qp
                            tokenPrices[token].push((BigInt(price) * BigInt(10**18) / BigInt(qp)).toString())
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
            networks[network].updatePrice(_pairs, _tokens, _quotes)
        }
    }

    console.log("Updated pair prices")

}

async function checkForDEXPairs(symbol: any, network: any, api_url: any) {
    let provider = new ethers.providers.JsonRpcProvider(api_url);

    const abi = [
        "function factory() external pure returns (address)",
        "function getPair(address tokenA, address tokenB) external view returns (address pair)"
    ];

    let routers = getJSON("routers.json")[network]
    let router_pairs: { [key: string]: any } = {}
    for (const router in routers) {
        let r = routers[router]

        let router_contract = new ethers.Contract(r, abi, provider);
        let factory_address = await router_contract.factory()

        let liquidity_tokens = getJSON("liquidity_tokens.json")
        let pair_tokens: { [key: string]: any } = {}
        for (const i in liquidity_tokens) {
            pair_tokens[i] = liquidity_tokens[i][network]
        }

        let token_address = getJSON("tokens.json")[symbol][network]
        let pairs: { [key: string]: any } = {}
        for (const i in pair_tokens) {
            let factory_contract = new ethers.Contract(factory_address, abi, provider);
            let pair = await factory_contract.getPair(token_address, pair_tokens[i])
            if (pair != "0x0000000000000000000000000000000000000000")
                pairs[symbol + "/" + i] = {pair: pair, token: token_address, quote: pair_tokens[i]}
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
