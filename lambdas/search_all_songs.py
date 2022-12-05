import boto3
import os
import json


def lambda_handler(event, context):
    dynamodb = boto3.client('dynamodb')
    response = dynamodb.scan(
        TableName=os.environ['TABLE_NAME']
    )

    return {
        'statusCode': 200,
        'headers': {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*'
        },
        'body': json.dumps(response['Items'])
    }
