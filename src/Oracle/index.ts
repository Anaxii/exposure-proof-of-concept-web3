import {getJSON, writeJSON} from "../util/Util";

const {ethers} = require("ethers");
const NodeCache = require("node-cache");
const priceCache = new NodeCache({stdTTL: 30});

export default async function Oracle(eventHandler: any, config: any) {
    let api_urls: { [key: string]: string } = {}
    for (const i in config["main_networks"]) {
        api_urls[config["main_networks"][i].name] = config["main_networks"][i].api_url
    }
    api_urls[config["subnet"].name] = config["subnet"].api_url

    eventHandler.on('checkForPairs', function (data: any) {
        console.log('checkForPairs', data);
        checkForDEXPairs(data.symbol, data.network, api_urls[data.symbol])
    })

    await getPrices(api_urls)


}

async function getPrices(api_urls: any) {
    const abi = [
        "function balanceOf(address account) external view returns (uint256)",
    ]

    let pairs = getJSON("pairs.json")
    for (const pair in pairs) {
        for (const network in pairs[pair]) {
            let provider = new ethers.providers.JsonRpcProvider(api_urls[network]);

            for (const dex in pairs[pair][network]) {
                for (const trading_pair in pairs[pair][network][dex]) {
                    if (priceCache.get((pair + network + dex + trading_pair).toString()))
                        continue

                    let token_contract = new ethers.Contract(pairs[pair][network][dex][trading_pair].token, abi, provider);
                    let token_balance = await token_contract.balanceOf(pairs[pair][network][dex][trading_pair].pair)

                    let quote_contract = new ethers.Contract(pairs[pair][network][dex][trading_pair].quote, abi, provider);
                    let quote_balance = await quote_contract.balanceOf(pairs[pair][network][dex][trading_pair].pair)

                    let price = (BigInt(token_balance.toString()) * BigInt(10 ** 18) / BigInt(quote_balance.toString())).toString()
                    pairs[pair][network][dex][trading_pair].price = price
                    priceCache.mset([{key: (pair + network + dex + trading_pair).toString(), val: price}])
                }
            }
        }
    }
    console.log("Updated pair prices")
    writeJSON("pairs.json", pairs)

}

async function getPrice() {
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
