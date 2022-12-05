import boto3
import os
import time
import json


def lambda_handler(event, context):
    dynamodb = boto3.client('dynamodb')
    body = json.loads(event['body'])

    dynamodb.put_item(
        TableName=os.environ['TABLE_NAME'],
        Item={
            'song_id': {'S': time.strftime("%Y%m%d-%H%M%S")},
            'title': {'S': body['title']},
            'artist': {'S': body['artist']},
            'album': {'S': body['album']},
            'year_of_publication': {'S': body['year_of_publication']},
            'expiryPeriod': {'S': time.strftime("%Y%m%d-%H%M%S")},
        }
    )

    return {
        'statusCode': 200,
        'body': 'Song added successfully'
    }
