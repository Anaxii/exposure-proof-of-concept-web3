import {Network} from "./Network";
import {getJSON} from "../util";

const {ethers} = require("ethers");

export default class Mainnet extends Network {

    constructor(config: MainNetwork, eventHandler: any, privateKey: string) {
        super(config, eventHandler, privateKey)
        this.monitor()
    }

    private async monitor() {
        const contract = new ethers.Contract(this.config.bridge_address, this.abi, this.provider);
        try {
            contract.on("BridgeToSubnet", (user: any, asset: any, amount: any, _bridgeRequestID: any, assetName: any, assetSymbol: any, event: any) => {
                this.eventHandler.emit('BridgeToSubnet', {
                    network: this.config,
                    user,
                    asset,
                    amount: amount.toString(),
                    _bridgeRequestID: _bridgeRequestID.toString(),
                    assetName,
                    assetSymbol
                });
            });
            let baskets = getJSON("baskets.json")
            for (const i in baskets) {
                contract.on("UpdateSubnet", (event: any) => {
                    this.eventHandler.emit('NewPendingBasketTradesComplete', {
                        network: this.config,
                        basket: baskets[i],
                    });
                });
            }
        } catch (err: any) {
            console.log("Critical error", this.config, err)
            process.exit()
        }
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

    async bridgeToMainnet(asset: string, user: string, amount: string, _bridgeRequestID: string, symbol: string, network: string) {
        try {
            const contract = new ethers.Contract(this.config.bridge_address, this.abi, this.provider);
            const signer = new ethers.Wallet(this.privateKey, this.provider)
            const contractWithSigner = contract.connect(signer)
            let tx = await contractWithSigner.bridgeToMainnet(asset, user, amount, _bridgeRequestID)
            await tx.wait(2)
            console.log(`Bridged ${amount} (1e18) ${symbol} to ${network} (mainnet) for ${user} (requestID: ${_bridgeRequestID})`)
            return true
        } catch (err: any) {
            console.log(err)
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

    async getMCAP(pair: string) {
        try {
            const contract = new ethers.Contract(this.config.oracle, this.abi, this.provider);
            let price = await contract.marketCap(pair)
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
                return ""
        }
    }

    async getSubnetProductAddress(product: string) {
        try {
            const bridge = new ethers.Contract(this.config.bridge_address, this.abi, this.provider);
            return await bridge.subnetProductAssetsAddress.call(product)
        } catch {
                return ""
        }
    }

    async getBalance(token: string, account: string) {
        try {
            const contract = new ethers.Contract(token, this.abi, this.provider);
            return await contract.balanceOf.call(account)
        } catch {
            return ""
        }
    }
}
