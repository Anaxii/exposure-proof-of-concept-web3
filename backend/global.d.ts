declare interface Config {
    private_key: string
    main_networks: MainNetwork[]
    subnet: SubNetwork
}

declare interface MainNetwork {
    name: string
    api_url: string
    bridge_address: string
    oracle: string
}

declare interface SubNetwork {
    name: string
    api_url: string
    bridge_manager_address: string
    oracle: string
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
