# -*- coding: utf-8 -*-
# Upside Travel, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

import os
import copy
import json
import errno
import hashlib
import datetime
import subprocess

from pytz import utc
from urllib.parse import unquote_plus

import boto3
import botocore

# antivirus definition bucket or quarantine bucket
AV_DEFINITION_S3_BUCKET = os.getenv("AV_DEFINITION_S3_BUCKET")
AV_DEFINITION_S3_PREFIX = "clamav_defs"
AV_DEFINITION_PATH = "/tmp/" + AV_DEFINITION_S3_PREFIX
AV_DEFINITION_FILE_PREFIXES = ["main", "daily", "bytecode"]
AV_DEFINITION_FILE_SUFFIXES = ["cld", "cvd"]

# quarantine bucket
AV_QUARANTINE_S3_BUCKET = os.getenv("AV_QUARANTINE_S3_BUCKET")
AV_QUARANTINE_S3_PREFIX = "infected_files"

# prod bucket
AV_PROD_S3_BUCKET = os.getenv("AV_PROD_S3_BUCKET")


# Files signatures are stored in S3 as a JSON object
AV_SIGNATURE_METADATA = "av-signature"
AV_SIGNATURE_OK = "OK"
AV_SIGNATURE_UNKNOWN = "UNKNOWN"

# Return string of clamav scan output
AV_STATUS_CLEAN = "CLEAN"
AV_STATUS_INFECTED = "INFECTED"
AV_STATUS_METADATA = "av-status"
AV_STATUS_SNS_ARN = os.getenv("AV_STATUS_SNS_ARN")

AV_TIMESTAMP_METADATA = os.getenv("AV_TIMESTAMP_METADATA", "av-timestamp")

# common paths
CLAMAVLIB_PATH = "/opt/python/bin"
CLAMSCAN_PATH = "/opt/python/bin/clamscan"
FRESHCLAM_PATH = "/opt/python/bin/freshclam"


# Step 1: Download the antivirus definition files from S3


def update_defs_from_s3(s3_client, bucket, prefix):
    create_dir(AV_DEFINITION_PATH)
    to_download = {}
    for file_prefix in AV_DEFINITION_FILE_PREFIXES:
        s3_best_time = None
        for file_suffix in AV_DEFINITION_FILE_SUFFIXES:
            filename = file_prefix + "." + file_suffix
            s3_path = os.path.join(AV_DEFINITION_S3_PREFIX, filename)
            local_path = os.path.join(AV_DEFINITION_PATH, filename)
            s3_md5 = md5_from_s3_tags(s3_client, bucket, s3_path)
            s3_time = time_from_s3(s3_client, bucket, s3_path)

            if s3_best_time is not None and s3_time < s3_best_time:
                print("Not downloading older file in series: %s" % filename)
                continue
            else:
                s3_best_time = s3_time

            # md5 from s3
            hash_md5 = hashlib.md5()
            with open(local_path, "rb") as f:
                for chunk in iter(lambda: f.read(4096), b""):
                    hash_md5.update(chunk)

            if os.path.exists(local_path) and hash_md5.hexdigest() == s3_md5:
                print("Not downloading %s because local md5 matches s3." % filename)
                continue
            if s3_md5:
                to_download[file_prefix] = {
                    "s3_path": s3_path,
                    "local_path": local_path,
                }
    return to_download


def md5_from_s3_tags(s3_client, bucket, key):
    try:
        tags = s3_client.get_object_tagging(Bucket=bucket, Key=key)["TagSet"]
    except botocore.exceptions.ClientError as e:
        expected_errors = {
            "404",  # Object does not exist
            "AccessDenied",  # Object cannot be accessed
            "NoSuchKey",  # Object does not exist
            "MethodNotAllowed",  # Object deleted in bucket with versioning
        }
        if e.response["Error"]["Code"] in expected_errors:
            return ""
        else:
            raise
    for tag in tags:
        if tag["Key"] == "md5":
            return tag["Value"]
    return ""


def time_from_s3(s3_client, bucket, key):
    try:
        time = s3_client.head_object(Bucket=bucket, Key=key)["LastModified"]
    except botocore.exceptions.ClientError as e:
        expected_errors = {"404", "AccessDenied", "NoSuchKey"}
        if e.response["Error"]["Code"] in expected_errors:
            return datetime.datetime.fromtimestamp(0, utc)
        else:
            raise
    return time


# Step 2: Scan the file and determine if it is infected


def scan_file(path):
    av_env = os.environ.copy()
    av_env["LD_LIBRARY_PATH"] = CLAMAVLIB_PATH
    print("Starting clamscan of %s." % path)
    av_proc = subprocess.Popen(
        [CLAMSCAN_PATH, "-v", "-a", "--stdout", "-d", AV_DEFINITION_PATH, path],
        stderr=subprocess.STDOUT,
        stdout=subprocess.PIPE,
        env=av_env,
    )
    output = av_proc.communicate()[0].decode()
    print("clamscan output:\n%s" % output)

    # Turn the output into a data source we can read
    summary = scan_output_to_json(output)
    if av_proc.returncode == 0:
        return AV_STATUS_CLEAN, AV_SIGNATURE_OK
    elif av_proc.returncode == 1:
        signature = summary.get(path, AV_SIGNATURE_UNKNOWN)
        return AV_STATUS_INFECTED, signature
    else:
        msg = "Unexpected exit code from clamscan: %s.\n" % av_proc.returncode
        print(msg)
        raise Exception(msg)


"""Turn ClamAV Scan output into a JSON formatted data object"""


def scan_output_to_json(output):
    summary = {}
    for line in output.split("\n"):
        if ":" in line:
            key, value = line.split(":", 1)
            summary[key] = value.strip()
    return summary


# Step 3: Update the tags on the file in S3


def set_av_tags(s3_client, s3_object, scan_result, scan_signature):
    curr_tags = s3_client.get_object_tagging(
        Bucket=s3_object.bucket_name, Key=s3_object.key
    )["TagSet"]
    new_tags = copy.copy(curr_tags)
    for tag in curr_tags:
        if tag["Key"] in [
            AV_SIGNATURE_METADATA,
            AV_STATUS_METADATA,
            AV_TIMESTAMP_METADATA,
        ]:
            new_tags.remove(tag)
    new_tags.append({"Key": AV_SIGNATURE_METADATA, "Value": scan_signature})
    new_tags.append({"Key": AV_STATUS_METADATA, "Value": scan_result})
    new_tags.append({"Key": AV_TIMESTAMP_METADATA, "Value": get_timestamp()})
    s3_client.put_object_tagging(
        Bucket=s3_object.bucket_name, Key=s3_object.key, Tagging={
            "TagSet": new_tags}
    )


# Step 4: Send sns notification


def sns_scan_results(sns_client, s3_object, sns_arn, scan_result, scan_signature):
    message = {
        "bucket": s3_object.bucket_name,
        "key": s3_object.key,
        "version": s3_object.version_id,
        AV_SIGNATURE_METADATA: scan_signature,
        AV_STATUS_METADATA: scan_result,
        AV_TIMESTAMP_METADATA: get_timestamp(),
    }
    sns_client.publish(
        TargetArn=sns_arn,
        Message=json.dumps({"default": json.dumps(message)}),
        MessageStructure="json",
        MessageAttributes={
            AV_STATUS_METADATA: {"DataType": "String", "StringValue": scan_result},
            AV_SIGNATURE_METADATA: {
                "DataType": "String",
                "StringValue": scan_signature,
            },
        },
    )


def create_dir(path):
    if not os.path.exists(path):
        try:
            print("Attempting to create directory %s.\n" % path)
            os.makedirs(path)
        except OSError as exc:
            if exc.errno != errno.EEXIST:
                raise


def get_timestamp():
    return datetime.datetime.utcnow().strftime("%Y/%m/%d %H:%M:%S UTC")


def delete_s3_object(s3_object):
    try:
        s3_object.delete()
    except Exception:
        raise Exception(
            "Failed to delete infected file: %s.%s"
            % (s3_object.bucket_name, s3_object.key)
        )
    else:
        print("Infected file deleted: %s.%s" %
              (s3_object.bucket_name, s3_object.key))


def lambda_handler(event, context):
    s3 = boto3.resource("s3")
    s3_client = boto3.client("s3")
    sns_client = boto3.client("sns")

    print("Script starting at %s\n" % (get_timestamp()))

    # Download the s3 file to a local lambda directory
    bucket_name = event["Records"][0]["s3"]["bucket"]["name"]
    key_name = unquote_plus(event["Records"][0]["s3"]["object"]["key"])
    s3_object = s3.Object(bucket_name, key_name)
    file_path = os.path.join("/tmp", s3_object.bucket_name, s3_object.key)
    create_dir(os.path.dirname(file_path))
    s3_object.download_file(file_path)

    # Download the AV config file to a local lambda directory
    to_download = update_defs_from_s3(
        s3_client, AV_DEFINITION_S3_BUCKET, AV_DEFINITION_S3_PREFIX
    )

    for download in to_download.values():
        s3_path = download["s3_path"]
        local_path = download["local_path"]
        print("Downloading definition file %s from s3://%s" %
              (local_path, s3_path))
        s3.Bucket(AV_DEFINITION_S3_BUCKET).download_file(s3_path, local_path)
        print("Downloading definition file %s complete!" % (local_path))

    # Scan the file
    scan_result, scan_signature = scan_file(file_path)
    print("Scan of s3://%s resulted in %s\n"
          % (os.path.join(s3_object.bucket_name, s3_object.key), scan_result)
          )

    # Update the tags on the file
    set_av_tags(s3_client, s3_object, scan_result, scan_signature)

    # Publish the scan results
    sns_scan_results(sns_client, s3_object, AV_STATUS_SNS_ARN,
                     scan_result, scan_signature)

    # Delete downloaded file to free up room on re-usable lambda function container
    try:
        os.remove(file_path)
    except OSError:
        pass
    copy_source = {
        "Bucket": s3_object.bucket_name,
        "Key": s3_object.key,
    }

    if scan_result == AV_STATUS_INFECTED:
        target_bucket = AV_QUARANTINE_S3_BUCKET
        target_key = os.path.join(AV_QUARANTINE_S3_PREFIX, s3_object.key)
    else:
        target_bucket = AV_PROD_S3_BUCKET
        target_key = s3_object.key
    s3_client.copy_object(
        CopySource=copy_source,
        Bucket=target_bucket,
        Key=target_key,
    )
    s3_object.delete()
    stop_scan_time = get_timestamp()
    print("Script finished at %s\n" % stop_scan_time)
