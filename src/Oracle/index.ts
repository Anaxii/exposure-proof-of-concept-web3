import {getJSON, writeJSON} from "../util/Util";

const {ethers} = require("ethers");

export default async function Oracle(eventHandler: any, config: any) {
    let api_urls: {[key: string]: string} = {}
    for (const i in config["main_networks"]) {
        api_urls[config["main_networks"][i].name] = config["main_networks"][i].api_url
    }
    api_urls[config["subnet"].name] = config["subnet"].api_url

    eventHandler.on('checkForPairs', function (data: any) {
        console.log('checkForPairs', data);
        checkForDEXPairs(data.symbol, data.network, api_urls[data.symbol])
    })

    checkForDEXPairs("Token C", "fuji", api_urls["fuji"])

}

async function checkForDEXPairs(symbol: any, network: any, api_url: any) {
    let provider = new ethers.providers.JsonRpcProvider(api_url);

    const abi = [
        "function factory() external pure returns (address)",
        "function getPair(address tokenA, address tokenB) external view returns (address pair)"
    ];

    let routers = getJSON("routers.json")[network]
    let router_pairs: {[key: string]: any} = {}
    for (const router in routers) {
        let r = routers[router]
        console.log(r, api_url)

        let router_contract = new ethers.Contract(r, abi, provider);
        let factory_address = await router_contract.factory()
        console.log(factory_address)

        let liquidity_tokens = getJSON("liquidity_tokens.json")
        let pair_tokens: {[key: string]: any} = {}
        for (const i in liquidity_tokens) {
            pair_tokens[i] = liquidity_tokens[i][network]
        }
        console.log(pair_tokens)

        let token_address = getJSON("tokens.json")[symbol][network]
        let pairs: {[key: string]: any} = {}
        for (const i in pair_tokens) {
            let factory_contract = new ethers.Contract(factory_address, abi, provider);
            let pair = await factory_contract.getPair(token_address, pair_tokens[i])
            if (pair != "0x0000000000000000000000000000000000000000")
                pairs[symbol+"/"+i] = pair
        }
        router_pairs[router] = pairs

    }
    console.log(router_pairs)

    let stored_pairs = getJSON("pairs.json")
    if (!stored_pairs[network])
        stored_pairs[network] = {}
    if (!stored_pairs[network][symbol])
        stored_pairs[network][symbol] = {}
    stored_pairs[network][symbol] = router_pairs
    console.log(`Updated ${symbol} in pairs.json`)

    writeJSON("pairs.json", stored_pairs)

}
