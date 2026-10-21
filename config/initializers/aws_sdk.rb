# ApplicationController's rescue_from references Aws::Errors::ServiceError and
# Seahorse::Client::NetworkingError so it can handle MinIO failures uniformly across
# environments. Active Storage only loads the AWS SDK itself when the S3 service is actually
# configured (dev/test use the local/test Disk service instead), so require it explicitly here
# to guarantee those constants exist at boot regardless of which Active Storage service is active.
require "aws-sdk-s3"
