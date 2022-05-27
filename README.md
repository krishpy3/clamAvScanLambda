### Create the lambda layers through docker.

```
docker build -t clanav:latest .
mkdir -p ./build/
docker run -v $(pwd)/build:/opt/mount --rm --entrypoint cp clanav:latest /opt/app/build/lambda.zip /opt/mount/lambda.zip
```

### Infra Provision.
Run `terraform apply` to create the below infra setup
* Lambda Function
* Lambda Layer
* Lambda Role
* S3
* S3 Notification for lambda
* Cloudwatch Event and its trigger
