const {ethers} = require("ethers");

export class Network {
    readonly config: any;
    eventHandler: any;
    provider: any;
    privateKey: string;
    constructor(config: any, eventHandler: any, privateKey: string) {
        this.config = config
        this.eventHandler = eventHandler
        this.privateKey = privateKey
        this.provider = new ethers.providers.JsonRpcProvider(this.config.api_url);
    }
}
