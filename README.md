# restricted-registry

This repository demonstrate a restricted docker registry designs to prevent users to: 
* push a tag more than one time 
* push tag latests
* push a into a repository not matching a given path

## Architecture

System consist of 2 containers:
* registry docker image 
* customized httpd docker image which acts as a reverse proxy to registry container, and rely on RewriteRule to prevent some push to targeted registry  

## Build customized httpd docker image 

    docker build --tag apache2 .

## Start system

    # Start registry
    docker run --restart always -d -p 5000:5000 -v /var/lib/registry --name registry --network proxy registry
    # Start apache frontend
    docker run --restart always -d -v $(pwd)/conf:/usr/local/apache2/conf -p 80:80 -p 443:443 --name apache2 --network proxy apache2

## Stop system

    # Stop registry
    docker rm -f registry
    # Stop apache2
    docker rm -f apache2

## The magic

### Prevent push of existing tags

Main idea was to check if manifest push request already exists before beeing submitted to registry, thanks to REST endpoint `/v2/<repository>/manifests/<tag>`

To achieve this goal, a RewriteRule is used to raise a 403 error if a PUT for a manifests is trying to be performed and already exists.

    RewriteRule ^/v2/(.+)/manifests/(.+) "-" [F]

Notice first group select image repository (akka its name), and the second one selects the tag 

In order to check if tag to be pushed is a latest one, following RewriteCond is used:

    RewriteCond "$2" "latest" 

In order to check if a tag exists, a prg RewriteMap is registered as `tagExists` to call shell script `conf/checkUrlExists.sh` which is in charge to check if a given URL can be served.

    RewriteMap tagExist "prg:/usr/local/apache2/conf/checkUrlExists.sh"

Shell script returns string `403` if url can be served, and `200` otherwise

Then `tagExists` rewrite map is called by folloging RewriteCond, which checks if it return 403 if given URL can be served

    RewriteCond "${tagExist:%{REQUEST_SCHEME}://%{HTTP_HOST}%{REQUEST_URI}}" "403"

In order to check a PUT is performed, following RewriteCond is required:

    RewriteCond "%{REQUEST_METHOD}" "PUT"

### Force push to specific leading repository name suffix

Main idea was to check if manifest push request match a leading suffix

To achieve this goal, a RewriteRule is used to raise a 403 error if a PUT for a manifest is trying to be performed and does not match expecting leading.

    RewriteRule ^/v2/(.+)/manifests/(.+) "-" [F]

Notice first group select image repository (akka its name), and the second one selects the tag 

In order to check if repository match leading suffix, following RewriteCond is used:

    RewriteCond "$1" "!^alpine$"

In order to check a PUT is performed, following RewriteCond is required:

    RewriteCond "%{REQUEST_METHOD}" "PUT"

