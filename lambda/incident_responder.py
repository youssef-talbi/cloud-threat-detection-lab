import boto3
import json
import os
import logging
from datetime import datetime

logger = logging.getLogger()
logger.setLevel(logging.INFO)

ec2 = boto3.client('ec2', region_name='us-east-1')
sns = boto3.client('sns', region_name='us-east-1')

ISOLATED_SG_ID = os.environ['ISOLATED_SG_ID']
SNS_TOPIC_ARN  = os.environ['SNS_TOPIC_ARN']


def lambda_handler(event, context):
    logger.info("Event received: %s", json.dumps(event))

    detail       = event.get('detail', {})
    finding_type = detail.get('type', 'Unknown')
    severity     = detail.get('severity', 0)
    region       = detail.get('region', 'us-east-1')
    account_id   = detail.get('accountId', 'Unknown')
    finding_id   = detail.get('id', 'Unknown')
    description  = detail.get('description', 'No description available')
    timestamp    = datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S UTC')

    instance_id = None
    try:
        resource = detail.get('resource', {})
        instance_details = resource.get('instanceDetails', {})
        instance_id = instance_details.get('instanceId')
    except Exception as e:
        logger.warning("Could not extract instance ID: %s", str(e))

    isolation_status = "Not triggered"
    if instance_id and severity >= 4:
        try:
            ec2.modify_instance_attribute(
                InstanceId=instance_id,
                Groups=[ISOLATED_SG_ID]
            )
            isolation_status = f"SUCCESS - {instance_id} isolated with {ISOLATED_SG_ID}"
            logger.info("Instance isolated: %s", instance_id)
        except Exception as e:
            isolation_status = f"FAILED - {str(e)}"
            logger.error("Isolation failed: %s", str(e))

    alert_message = f"""
THREAT DETECTED - Cloud Threat Detection Lab

Timestamp     : {timestamp}
Finding Type  : {finding_type}
Severity      : {severity}/10
Region        : {region}
Account ID    : {account_id}
Finding ID    : {finding_id}

Description:
{description}

Affected Instance : {instance_id if instance_id else 'N/A'}
Isolation Status  : {isolation_status}
"""

    try:
        sns.publish(
            TopicArn=SNS_TOPIC_ARN,
            Subject=f"[{severity_label(severity)}] GuardDuty: {finding_type}",
            Message=alert_message
        )
        logger.info("SNS alert sent")
    except Exception as e:
        logger.error("SNS publish failed: %s", str(e))

    return {
        'statusCode': 200,
        'finding_type': finding_type,
        'severity': severity,
        'instance_id': instance_id,
        'isolation_status': isolation_status
    }


def severity_label(severity):
    if severity >= 7:
        return "HIGH"
    elif severity >= 4:
        return "MEDIUM"
    else:
        return "LOW"
