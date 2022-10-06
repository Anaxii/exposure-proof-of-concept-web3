declare interface Config {
    private_key: string
    main_networks: MainNetwork[]
    subnet: SubNetwork
}

declare interface MainNetwork {
    name: string
    api_url: string
    bridge_address: string
}

declare interface SubNetwork {
    name: string
    api_url: string
    bridge_manager_address: string
}
