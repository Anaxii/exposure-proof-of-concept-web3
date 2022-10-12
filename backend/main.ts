import Swap from "./src/Bridge";
import Oracle from "./src/Oracle";
import {getJSON} from "./src/util";
import Mainnet from "./src/EVM/Mainnet";
import Subnet from "./src/EVM/Subnet";

const events = require('events');

(async function (){
   let eventHandler = new events.EventEmitter();
   let config = getJSON("config.json")

   if (process.env.pkey) {
      config.private_key = process.env.pkey
   }

   let networks: { [key: string]: Mainnet } = {}
   let subnet: Subnet = new Subnet(config.subnet, eventHandler, config.private_key)
   for (const i in config.main_networks) {
      networks[config.main_networks[i].name] = new Mainnet(config.main_networks[i], eventHandler, config.private_key)
   }

   Swap(eventHandler, config, subnet, networks)
   // Oracle(eventHandler, config, subnet, networks)
}())

