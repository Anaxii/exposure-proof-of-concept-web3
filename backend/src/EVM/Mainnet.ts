import {Network} from "./Network";

const {ethers} = require("ethers");

export default class Mainnet extends Network {

    constructor(config: MainNetwork, eventHandler: any, privateKey: string) {
        super(config, eventHandler, privateKey)
        this.monitor()
    }

    async bridgeToSubnet(amount: string, address: string) {
        const signer = new ethers.Wallet(this.privateKey, this.provider)
        try {
            let contract = new ethers.Contract(address, this.abi, this.provider);
            const tokenContract = contract.connect(signer)
            let tx = tokenContract.approve(this.config.bridge_address, amount)
            await tx.wait(2)

            contract = new ethers.Contract(this.config.bridge_address, this.abi, this.provider);
            const bridgeContract = contract.connect(signer)
            tx = await bridgeContract.bridgeToSubnet(amount, address)
            await tx.wait(2)

            console.log(`Send bridge request on mainnet for token ${address}`)
            return true
        } catch (err: any) {
            return false
        }
    }

    async bridgeToMainnet(asset: string, user: string, amount: string, symbol: string, network: string) {
        try {
            const contract = new ethers.Contract(this.config.bridge_address, this.abi, this.provider);
            const signer = new ethers.Wallet(this.privateKey, this.provider)
            const contractWithSigner = contract.connect(signer)
            let tx = await contractWithSigner.bridgeToMainnet(amount, asset, user)
            await tx.wait(2)
            console.log(`Bridged ${amount} (1e18) ${symbol} to ${network} (mainnet) for ${user}`)
            return true
        } catch {
            return false
        }
    }

    async updatePrices(pair: string[], asset: string[], quote: string[]) {
        try {
            const contract = new ethers.Contract(this.config.oracle, this.abi, this.provider);
            const signer = new ethers.Wallet(this.privateKey, this.provider)
            const contractWithSigner = contract.connect(signer)
            let tx = await contractWithSigner.updateMultiple(pair, asset, quote)
            await tx.wait(2)
            console.log(`Updated some mainnet prices (batched)`)
            return true
        } catch (err: any) {
            console.log(err)
            return false
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

    async getPairAddress(router: string, token: string, quote: string) {
        try {
            const routerContract = new ethers.Contract(router, this.abi, this.provider);
            let factory = await routerContract.factory()

            const factoryContract = new ethers.Contract(factory, this.abi, this.provider);
            return await factoryContract.getPair(token, quote)
        } catch {
            {
                return ""
            }
        }
    }

    private async monitor() {
        try {
            const contract = new ethers.Contract(this.config.bridge_address, this.abi, this.provider);
            contract.on("BridgeToSubnet", (user: any, asset: any, amount: any, assetName: any, assetSymbol: any, event: any) => {
                this.eventHandler.emit('BridgeToSubnet', {
                    network: this.config,
                    user,
                    asset,
                    amount: amount.toString(),
                    assetName,
                    assetSymbol
                });
            });
        } catch {
            process.exit()
        }

    }
}
