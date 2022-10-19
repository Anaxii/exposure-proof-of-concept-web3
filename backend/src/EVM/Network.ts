const {ethers} = require("ethers");

export class Network {
    readonly config: any;
    eventHandler: any;
    provider: any;
    readonly privateKey: string;
    readonly abi: any;
    constructor(config: NetworkInterface, eventHandler: any, privateKey: string) {
        this.config = config
        this.abi = config.abi
        this.eventHandler = eventHandler
        this.privateKey = privateKey
        this.provider = new ethers.providers.JsonRpcProvider(this.config.api_url);
    }

    async getBlock() {
        return await this.provider.getBlock()
    }

    async getBalance(token: string, account: string) {
        try {
            const contract = new ethers.Contract(token, this.abi, this.provider);
            return await contract.balanceOf.call(account)
        } catch {
            return ""
        }
    }

    async getPrice(pair: string) {
        try {
            const contract = new ethers.Contract(this.config.oracle, this.abi, this.provider);
            let price = await contract.price(pair)
            return price.toString()
        } catch {
            return ""
        }
    }

    async getMCAP(pair: string) {
        try {
            const contract = new ethers.Contract(this.config.oracle, this.abi, this.provider);
            let price = await contract.marketCap(pair)
            return price.toString()
        } catch {
            return ""
        }
    }

    async bridgeRequestIsComplete(id: any) {
        try {
            const contract = new ethers.Contract(this.config.bridge_address, this.abi, this.provider);
            let isComplete = await contract.bridgeRequestIsComplete(id)
            return isComplete
        } catch {
            return false
        }
    }
}
