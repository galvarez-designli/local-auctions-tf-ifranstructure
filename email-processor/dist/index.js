"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.handler = void 0;
const handler = async (event) => {
    console.log("Received SQS event:", JSON.stringify(event, null, 2));
};
exports.handler = handler;
