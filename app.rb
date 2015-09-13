require 'sinatra'
require 'dotenv'
require 'aws-sdk'
require 'json'
require 'active_support'
require 'active_support/core_ext'
require 'date'
require 'base64'
Dotenv.load

class AmazonValueProvider
  def initialize(use_temporary_credentials)
    @use_temporary_credentials = use_temporary_credentials
  end

  def date
    @date ||= DateTime.now.utc
  end

  def format_date(date)
    # Amazon requires using ISO8601 Long Format, which isn't compatible with
    # the #iso8601 method.

    date.strftime('%Y%m%dT%H%M%SZ')
  end

  def format_expiration_date(date)
    date.strftime('%Y-%m-%dT%H:%m:%s.%LZ')
  end

  def credentials
    @credentials ||=
      if @use_temporary_credentials
        temp = temporary_credentials

        {
          access_key_id: temp.access_key_id,
          secret_access_key: temp.secret_access_key,
          session_token: temp.session_token
        }
      else
        {
          access_key_id: ENV['AWS_ACCESS_KEY_ID'],
          secret_access_key: ENV['AWS_SECRET_ACCESS_KEY']
        }
      end
  end

  def s3_policy
    conditions = [
      { acl: 'public-read' },
      { bucket: s3_bucket },
      ['starts-with', '$key', 'uploads/'],
      { 'x-amz-algorithm' => amz_algorithm },
      { 'x-amz-credential' => amz_credential },
      { 'x-amz-date' => format_date(date) },
    ]

    if @use_temporary_credentials
      conditions << { 'x-amz-security-token' => credentials[:session_token] }
    end

    Base64.strict_encode64({
      expiration: format_expiration_date(date + 1.hour),
      conditions: conditions
    }.to_json)
  end

  def s3_bucket
    ENV['S3_BUCKET']
  end

  def amz_algorithm
    'AWS4-HMAC-SHA256'
  end

  def aws_region
    ENV['AWS_REGION']
  end

  def amz_credential
    [credentials[:access_key_id], date.strftime('%Y%m%d'), aws_region, 's3', 'aws4_request'].join('/')
  end

  def signature
    digest = OpenSSL::Digest.new('sha256')

    date_key = OpenSSL::HMAC.digest(digest, "AWS4#{credentials[:secret_access_key]}", date.strftime('%Y%m%d'))
    date_region_key = OpenSSL::HMAC.digest(digest, date_key, aws_region)
    date_region_service_key = OpenSSL::HMAC.digest(digest, date_region_key, 's3')
    signing_key = OpenSSL::HMAC.digest(digest, date_region_service_key, 'aws4_request')

    OpenSSL::HMAC.hexdigest(digest, signing_key, s3_policy)
  end

  def to_json
    output = {
      policy: s3_policy,
      aws_region: aws_region,
      bucket: s3_bucket,
      'x-amz-algorithm' => amz_algorithm,
      'x-amz-credential' => amz_credential,
      'x-amz-date' => format_date(date),
      'x-amz-signature' => signature
    }

    if @use_temporary_credentials
      output.merge!('x-amz-security-token' => credentials[:session_token])
    end

    output.to_json
  end

  private

  def temporary_credentials
    sts = Aws::STS::Client.new # We're authenticating using our ENV here

    # The policy allows to upload something to our bucket
    # policy = <<-JSON
    # {
    #   "Version": "2012-10-17",
    #   "Statement": [
    #     {
    #       "Sid": "Stmt1442167868189",
    #       "Action": [
    #         "s3:PutObject",
    #         "s3:PutObjectAcl"
    #       ],
    #       "Effect": "Allow",
    #       "Resource": "arn:aws:s3:::#{s3_bucket}/*"
    #     }
    #   ]
    # }
    # JSON
    policy = "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Sid\":\"Stmt1442167868189\",\"Action\":[\"s3:PutObject\",\"s3:PutObjectAcl\"],\"Effect\":\"Allow\",\"Resource\":\"arn:aws:s3:::#{s3_bucket}/*\"}]}"

    response = sts.get_federation_token(
      name: 'TemporaryUser',
      policy: policy,
      duration_seconds: 900 # The credentials are valid for 15 minutes
    )

    response.credentials
  end
end

post '/authdata' do
  temporary = !params[:temporary].nil?

  AmazonValueProvider.new(temporary).to_json
end

not_found do
  'POST /authdata[?temporary=1]'
end
