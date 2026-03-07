"""Basic Lambda handler for API Gateway integration."""

import json
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)


def handler(event, context):
    """Handle incoming API Gateway requests.

    Args:
        event: API Gateway proxy event.
        context: Lambda runtime context.

    Returns:
        dict: API Gateway proxy response.
    """
    logger.info("Received event: %s", json.dumps(event))

    http_method = event.get("httpMethod", "UNKNOWN")
    path = event.get("path", "/")

    return {
        "statusCode": 200,
        "headers": {
            "Content-Type": "application/json",
            "X-Request-Id": context.aws_request_id,
        },
        "body": json.dumps({
            "message": "Hello from Lambda!",
            "method": http_method,
            "path": path,
            "requestId": context.aws_request_id,
        }),
    }
