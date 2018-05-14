# Prerequisites

## Create Mongo backup user:

```
db.createUser({
  user: "backup-user",
  pwd: "{password}",
  roles: [ "backup" ]
});
```

## Create S3 user

In IAM:

1. Create Policy
 * Name: same as bucket name
 * JSON: as below, replacing resource name with you bucket name
 
```
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:ListAllMyBuckets"
            ],
            "Resource": "arn:aws:s3:::*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "s3:ListBucket",
                "s3:GetBucketLocation"
            ],
            "Resource": "arn:aws:s3:::instance-mongodb-backups"
        },
        {
            "Effect": "Allow",
            "Action": [
                "s3:PutObject",
                "s3:GetObject",
                "s3:DeleteObject"
            ],
            "Resource": "arn:aws:s3:::instance-mongodb-backups/*"
        }
    ]
}
```
2. Create Group with matching name and attach the new policy
3. Create User with matching name, programmatic access, the new group, and note down access key ID and secret access key

## Create S3 bucket

In S3 management UI:

1. 'Create Bucket'
2. Name and region:
 * Bucket name: {cluster}-mongodb-backups, e.g. instance-mongodb-backups
 * Region: EU (London)
3. Set properties:
 * Versioning: enabled
 * Tags: tennant
4. Set permissions
 * Set this up later
5. Review and Create Bucket

Also create a retension lifecycle to delete old files, in pre-prod.

## Create encryption key

In IAM create and encryption key in the same region as the bucket granting usage to the user created above.

# Configuration

```
MONGODB_HOST={comma-separated-list-of-hosts}
MONGODB_REPLICASET={optional-replica-set}
MONGODB_PORT=27017
MONGODB_DB={optional-db-to-backup/restore}
MONGODB_USER=backup-user
MONGODB_PASS={from-mongo-user-created-above}
BUCKET={s3-backet-created-above
GPG_PHRASE={phrase}
SERVER_SIDE_ENCRYPTION_KMS_ID={kms-key-id}
ACCESS_KEY={from-s3-user-created-above}
SECRET_KEY={from-s3-user-created-above}
```

# Restore a database

Set MONGODB_DB to the name of the database and S3_BACKUP_NAME to the name of the backup as stored in the S3 bucket (e.g. 2017.06.29.140428) to restore and use /restore.sh as the CMD.


Test restore locally to a Docker mongo instance:

Create a local mongo database and create a user for the restore process:

```
docker run -d -p 27017:27017 mongo:3.4
mongo 'mongodb://localhost/admin' --quiet --eval 'db.createUser({user: "restore-user",pwd: "password",roles: [ "dbAdmin" ]});'
```

Make sure you have an appropriate .env file, e.g.:

```
MONGODB_HOST=10.10.10.1
MONGODB_PORT=27017
MONGODB_USER=restore-user
MONGODB_PASS=password
BUCKET={bucket/cluster-to-retore}
SERVER_SIDE_ENCRYPTION_KMS_ID={kms-key-id}
GPG_PHRASE={phrase}
ACCESS_KEY={aws-access-key}
SECRET_KEY={aws-secret-key}
MONGODB_DB=DB_name
S3_BACKUP_NAME=2017.08.10.020001
```

Where:
* MONGODB_HOST is your laptop's IP (localhost won't work because the restore is running inside Docker)
* MONGODB_DB is the database to restore
* S3_BACKUP_NAME is the folder in S3 to restore, this should be the date/time that the backup was taken

Build the image locally if you haven't, then run the image with the /restore.sh command

```
docker run -it --rm -v /tmp:/tmp --env-file=.env mongodb-backup /restore.sh
```

# TODO
