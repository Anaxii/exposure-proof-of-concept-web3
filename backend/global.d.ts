declare interface Config {
    private_key: string
    public_key: string
    main_networks: NetworkInterface[]
    subnet: NetworkInterface
}

declare interface NetworkInterface {
    name: string
    api_url: string
    bridge_address: string
    oracle: string
    abi: string[]
}

declare interface Pairs {
    token: PairsToken
}

declare interface PairsToken {
    network: PairsNetwork
}

declare interface PairsNetwork {
    dex: PairsDEX
}

declare interface PairsDEX {
    tokenPair: PairsTokenPair
}

declare interface PairsTokenPair {
    pair: string
    token: string
    quote: string
}
