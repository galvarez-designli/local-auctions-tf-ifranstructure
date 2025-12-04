import { SQSEvent, SQSHandler } from "aws-lambda";

export const handler: SQSHandler = async (event: SQSEvent) => {
  console.log("Received SQS event:", JSON.stringify(event, null, 2));
};
