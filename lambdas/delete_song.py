import boto3
import os


def lambda_handler(event, context):
    dynamodb = boto3.client('dynamodb')
    dynamodb.delete_item(
        TableName=os.environ['TABLE_NAME'],
        Key={
            'song_id': {'S': event['pathParameters']['song_id']}
        }
    )

    return {
        'statusCode': 200,
        'body': 'Song deleted'
    }
