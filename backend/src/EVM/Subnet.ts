import {Network} from "./Network";
import {dbQueryAll} from "../Database";

const {ethers} = require("ethers");

export default class Subnet extends Network {

    constructor(config: NetworkInterface, eventHandler: any, privateKey: string) {
        super(config, eventHandler, privateKey)
        this.monitor()
    }

    async sync(startBlock: any) {
        try {
            const contract = new ethers.Contract(this.config.bridge_address, this.abi, this.provider);
            let endBlock = await this.getBlock();
            endBlock = endBlock.number
            let allEvents: any[] = [];

            for (let i = startBlock; i < endBlock; i += 5000) {
                const _startBlock = i;
                const _endBlock = Math.min(endBlock, i + 4999);
                const events = await contract.queryFilter("BridgeToMainnet", _startBlock, _endBlock);
                allEvents = [...allEvents, ...events]
            }
            return allEvents
        } catch (err: any) {
            console.log("Critical error", this.config, err)
            process.exit()
        }
    }

    async monitorBaskets() {
        let baskets: any = await dbQueryAll("SELECT * FROM baskets", null)
        for (const i in baskets) {
            const contract = new ethers.Contract(baskets[i].contract_address, this.abi, this.provider);
            contract.on("TargetPortionsReady", async (_epoch: any, _maxSlippage: any, event: any) => {
                console.log("Test")
                let check: any = await this.getPendingBasketTrades(baskets[i].contract_address, _epoch)
                let amounts = check.amounts
                let tokens = check.tokens
                this.eventHandler.emit('NewPendingBasketTrades', {
                    network: this.config,
                    basketAddress: baskets[i].contract_address,
                    _epoch: _maxSlippage.toString(),
                    _maxSlippage: _maxSlippage.toString(),
                    tokens,
                    amounts
                });
            });
        }
    }

    async getBasketTokens(basketAddress: any) {
        const contract = new ethers.Contract(basketAddress, this.abi, this.provider);
        let _epoch = await contract.epoch.call()
        let tokens = []
        let t = false
        let i = 0
        while (t) {
            try {
                let token = await contract.getTokens.call(_epoch, i)
                tokens.push(token)
                i++
            } catch {
                t = false
            }
        }
        return tokens
    }

    async getPendingBasketTrades(basketAddress: any, _epoch: any) {
        const contract = new ethers.Contract(basketAddress, this.abi, this.provider);
        let amounts = []
        let tokens = await this.getBasketTokens(basketAddress)

        for (const i in tokens) {
            let buyAmount = await contract.getTokenBuyAmount.call(_epoch, tokens[i])
            let sellAmount = await contract.getTokenSellAmount.call(_epoch, tokens[i])
            amounts.push(BigInt(buyAmount.toString()) - BigInt(sellAmount.toString()))
        }
        return {tokens, amounts}
    }

    async updateBasketBalances(basketAddress: any, amounts: any, tokens: any) {
        const contract = new ethers.Contract(basketAddress, this.abi, this.provider);
        try {
            for (const i in tokens) {
                let token = await this.getSubnetAddress(tokens[i])
                const tokenContract = new ethers.Contract(token, this.abi, this.provider);
                let bal = await tokenContract.balanceOf.call(basketAddress)
                let newBal = BigInt(amounts[i]) - BigInt(bal)
                if (newBal > BigInt(0)) {
                    let tx = await contract.mintUnderlying(token, newBal)
                    await tx.wait(2)
                } else {
                    let tx = await contract.burnUnderlying(token, newBal * BigInt(-1))
                    await tx.wait(2)
                }
            }
            let tx = await contract.finalizePortions()
            await tx.wait(2)

            tx = await contract.confirmFinalPortions()
            await tx.wait(2)
        } catch (err: any) {
            console.log(err)
        }
    }

    async bridgeToMainnet(asset: string, user: string, amount: string) {
        const signer = new ethers.Wallet(this.privateKey, this.provider)
        try {
            let contract = new ethers.Contract(this.config.bridge_address, this.abi, this.provider);
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

    async bridgeToSubnet(asset: string, user: string, amount: string, _bridgeRequestID: string, assetName: string, assetSymbol: string) {
        const contract = new ethers.Contract(this.config.bridge_address, this.abi, this.provider);
        try {
            const signer = new ethers.Wallet(this.privateKey, this.provider)
            const contractWithSigner = contract.connect(signer)

            let tx = await contractWithSigner.bridgeToSubnet(asset, user, amount, _bridgeRequestID, assetName, assetSymbol)
            await tx.wait(2)
            console.log(`Bridged ${amount} (1e18) ${assetSymbol} to the subnet for ${user} (requestID: ${_bridgeRequestID})`)
            return true
        } catch (err: any) {
            console.log(err)
            return false
        }
    }

    async updatePrices(asset: string[], price: string[], marketCap: string[]) {
        try {
            const contract = new ethers.Contract(this.config.oracle, this.abi, this.provider);
            const signer = new ethers.Wallet(this.privateKey, this.provider)
            const contractWithSigner = contract.connect(signer)
            let tx = await contractWithSigner.updateMultiple(asset, price)
            await tx.wait(2)

            tx = await contractWithSigner.updateMultipleMarketCap(asset, marketCap)
            await tx.wait(2)
            console.log(`Updated some subnet prices & mcaps (batched)`)
            return true
        } catch (err: any) {
            console.log(err)
            return false
        }
    }

    async getSubnetAddress(token: string) {
        try {
            const contract = new ethers.Contract(this.config.bridge_address, this.abi, this.provider);
            let subnetToken = await contract.subnetAddresses(token)
            return subnetToken.toString()
        } catch {
            return ""
        }
    }

    async getMainnetAddress(token: string) {
        try {
            const contract = new ethers.Contract(this.config.bridge_address, this.abi, this.provider);
            let subnetToken = await contract.mainnetAddresses(token)
            return subnetToken.toString()
        } catch {
            return ""
        }
    }

    private async monitor() {
        try {
            const contract = new ethers.Contract(this.config.bridge_address, this.abi, this.provider);
            contract.on("BridgeToMainnet", (user: any, asset: any, amount: any, _bridgeRequestID: any, assetName: any, assetSymbol: any, event: any) => {
                this.eventHandler.emit('BridgeToMainnet', {
                    network: this.config,
                    asset,
                    user,
                    _bridgeRequestID: _bridgeRequestID.toString(),
                    amount: amount.toString(),
                    assetName,
                    assetSymbol
                });
            });
        } catch (err: any) {
            console.log("Critical error", this.config, err)
            process.exit()
        }
    }
}
