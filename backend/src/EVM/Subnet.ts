import {Network} from "./Network";

const {ethers} = require("ethers");

export default class Subnet extends Network {

    constructor(config: SubNetwork, eventHandler: any, privateKey: string) {
        super(config, eventHandler, privateKey)
        this.monitor()
    }

    private async monitor() {
        try {
            const contract = new ethers.Contract(this.config.bridge_manager_address, this.abi, this.provider);
            contract.on("BridgeToMainnet", (user: any, assetMainnet: any, assetSubnet: any, amount: any, assetName: any, assetSymbol: any, event: any) => {
                this.eventHandler.emit('BridgeToMainnet', {
                    network: this.config,
                    user,
                    assetMainnet,
                    assetSubnet,
                    amount: amount.toString(),
                    assetName,
                    assetSymbol
                });
            });
        } catch {
            process.exit()
        }
    }

    async bridgeToMainnet(asset: string, user: string, amount: string) {
        const signer = new ethers.Wallet(this.privateKey, this.provider)
        try {
            let contract = new ethers.Contract(this.config.bridge_manager_address, this.abi, this.provider);
            const bridgeContract = contract.connect(signer)
            let tx = await bridgeContract.bridgeToMainnet(asset, user, amount)
            await tx.wait(2)
            console.log(`Send bridge request on mainnet for token ${asset}`)
            return true
        } catch (err: any) {
            console.log(err)
            return false
        }
    }

    async bridgeToSubnet(asset: string, user: string, amount: string, assetName: string, assetSymbol: string) {
        const contract = new ethers.Contract(this.config.bridge_manager_address, this.abi, this.provider);
        try {
            const signer = new ethers.Wallet(this.privateKey, this.provider)
            const contractWithSigner = contract.connect(signer)

            let tx = await contractWithSigner.bridgeToSubnet(asset, user, amount, assetName, assetSymbol)
            await tx.wait(2)
            console.log(`Bridged ${amount} (1e18) ${assetSymbol} to the subnet for ${user}`)
            return true
        } catch (err: any) {
            console.log(err)
            return false
        }
    }

    async updatePrices(asset: string[], price: string[]) {
        try {
            const contract = new ethers.Contract(this.config.oracle, this.abi, this.provider);
            const signer = new ethers.Wallet(this.privateKey, this.provider)
            const contractWithSigner = contract.connect(signer)
            let tx = await contractWithSigner.updateMultiple(asset, price)
            await tx.wait(2)
            console.log(`Updated some subnet prices (batched)`)
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

    async getSubnetAddress(token: string) {
        try {
            const contract = new ethers.Contract(this.config.bridge_manager_address, this.abi, this.provider);
            let subnetToken = await contract.subnetAddresses(token)
            return subnetToken.toString()
        } catch {
            return ""
        }

    }
}
