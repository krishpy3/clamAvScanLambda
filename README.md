### Infra requirements
1. Create a lambda function for avScanning. Attach S3 PutObject trigger to this lambda.
2. Create another lambda for avUpdateDefinition. Attach a Cloudwatch cron scheduler. 

### Create the lambda layers through docker.

```
docker build -t clanav:latest .
mkdir -p ./build/
docker run -v $(full_path)/build:/opt/mount --rm --entrypoint cp clanav:latest /opt/app/build/lambda.zip /opt/mount/lambda.zip
docker run -v $(pwd)/build:/opt/mount --rm --entrypoint cp clanav:latest /opt/app/build/lambda.zip /opt/mount/lambda.zip
```

### Upload Lambda Layers
1. Goto Lambda console, and upload this `lambda.zip` file as a lambda layer. 
2. Link this layer to both the previously created lambda file.

### Initially setup.
1. Our `avUpdateDefinition` lambda function will run for every cron interval. But for the first time, we have to run this manually. Or we can wait until the first cron execution.
2. Then upload a file in the source bucket to see if it is doing the AV Scan.