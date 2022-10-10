const {ethers} = require("ethers");

export class Network {
    readonly config: any;
    eventHandler: any;
    provider: any;
    readonly privateKey: string;
    readonly abi: any;
    constructor(config: MainNetwork | SubNetwork, eventHandler: any, privateKey: string) {
        this.config = config
        this.abi = config.abi
        this.eventHandler = eventHandler
        this.privateKey = privateKey
        this.provider = new ethers.providers.JsonRpcProvider(this.config.api_url);
    }
}
