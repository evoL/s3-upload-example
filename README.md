# S3 Upload Example

This repo consists of:

- `app.rb` — a Sinatra app, providing signatures and credentials for the client
- `upload.sh` — an uploader written using Bash and curl
- `upload_with_temporary_credentials.sh` — another uploader written using Bash and curl, this one uses temporarily generated credentials using STS on the backend

## How to start

First, setup the `.env` file using the provided sample.
The, assuming you have Ruby, run the following commands.

```
bundle install
ruby app.rb
```

This will start the backend on localhost:4567. If this port doesn't work for you, please adjust it in the uploaders.

`bash upload.sh filename` will upload `filename` to the `uploads` directory inside your S3 bucket.

`bash upload_with_temporary_credentials.sh filename` will do the same, but your access key needs permissions to use `GetFederationToken` in STS.

## Footnote

Licensed under the MIT license.
Copyright 2015 Rafał Hirsz.
