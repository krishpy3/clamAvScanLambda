import os
import pwd
import json
from datetime import datetime
from subprocess import Popen, PIPE, STDOUT, check_output
from urllib.parse import unquote_plus
import boto3

def lambda_handler(event, context):
    s3 = boto3.client("s3")
    # Step 1: Download the s3 file to a local lambda directory
    bucket = event["Records"][0]["s3"]["bucket"]["name"]
    key = unquote_plus(event["Records"][0]["s3"]["object"]["key"])
    s3.download_file(bucket, key, f"/tmp/{key}")
    # Step 2: Download the AV config file to a local lambda directory
    av_env = os.environ.copy()
    av_env["LD_LIBRARY_PATH"] = "/opt/python/bin"
    Popen(f"/opt/python/bin/freshclam --config-file=/opt/python/bin/freshclam.conf -u {pwd.getpwuid(os.getuid())[0]} --datadir=/tmp/clamav", shell=True, stdout=PIPE, stderr=STDOUT, env=av_env).communicate()[0]
    # Step 3: Scan the file
    av_proc = Popen(f"/opt/python/bin/clamscan -v -a --stdout -d /tmp/clamav /tmp/{key}", stderr=STDOUT, stdout=PIPE, shell=True, env=av_env)
    output = av_proc.communicate()[0]
    if av_proc.returncode == 0:
        status = "CLEAN"
        target_bucket = os.getenv("AV_ACTIVE_S3_BUCKET")
        target_key = key
    elif av_proc.returncode == 1:
        status = "INFECTED"
        target_bucket = os.getenv("AV_QUARANTINE_S3_BUCKET")
        target_key = os.path.join("infected_files", key)
    print("Scan of s3://%s resulted in\n %s\n" % (os.path.join(bucket, key), output.decode("utf-8")))
    # Step 4: Publish the scan results
    message = {"bucket": bucket, "key": key, "av-status": status, "av-timestamp": datetime.utcnow().strftime("%Y/%m/%d %H:%M:%S UTC")}
    boto3.client("sns").publish(TargetArn=os.getenv("AV_STATUS_SNS_ARN"), Message=json.dumps({"default": json.dumps(message)}), MessageStructure="json")
    s3.copy_object(CopySource={"Bucket": bucket,"Key": key}, Bucket=target_bucket, Key=target_key)
    s3.delete_object(Bucket=bucket, Key=key)