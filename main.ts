import Swap from "./src/Swap";
import Oracle from "./src/Oracle";
import {getJSON} from "./src/util/Util";

const events = require('events');

(async function (){
   let eventHandler = new events.EventEmitter();
   let config = getJSON("config.json")
   Swap(eventHandler, config)
   Oracle(eventHandler, config)
}())

