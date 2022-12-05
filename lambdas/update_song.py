import boto3
import os
import json


def lambda_handler(event, context):
    dynamodb = boto3.client('dynamodb')
    body = json.loads(event['body'])

    dynamodb.update_item(
        TableName=os.environ['TABLE_NAME'],
        Key={
            'song_id': {'S': event['pathParameters']['song_id']}
        },
        UpdateExpression='SET title = :title, artist = :artist, album = :album, year_of_publication = :year_of_publication',
        ExpressionAttributeValues={
            ':title': {'S': body['title']},
            ':artist': {'S': body['artist']},
            ':album': {'S': body['album']},
            ':year_of_publication': {'S': body['year_of_publication']},
        }
    )

    return {
        'statusCode': 200,
        'body': 'Song updated successfully'
    }
