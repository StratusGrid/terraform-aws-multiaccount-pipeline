import boto3
import os

def lambda_handler(event, context):
    client = boto3.client('codepipeline')
    env = event['env'] + "-Plan-and-Apply"
    
    getToken = client.get_pipeline_state(
        name = os.environ['pipelineName']
    )
    
    for stages in getToken['stageStates']:
        if stages['stageName'] == env:
            myToken = (stages['actionStates'][1]['latestExecution']['token'])

    response = client.put_approval_result(
        pipelineName=os.environ['pipelineName'],
        stageName=env,
        actionName='Approval',
        result={
            'summary': event['summary'],
            'status': event['status']
        },
        token=myToken

    )