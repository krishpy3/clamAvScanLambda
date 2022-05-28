import json
import scan
import update


def lambda_handler(event, context):
    print(event)
    if 'source' in event and event['source'] == 'aws.events':
        print('Event triggered by AWS Events')
        update.lambda_handler(event, context)
    else:
        print('Event triggered by S3')
        scan.lambda_handler(event, context)

    return {
        'statusCode': 200,
        'body': json.dumps('Hello from Lambda!')
    }
