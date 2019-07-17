# Issue with secure connection to RDS from python:2-buster image

This repo is showing an issue that appeared
after upgrading official `python:2` Docker image
to use a newer Debian (codename `buster`) base image.
[See docker-library/python#405 PR][DOCKER CHANGE] for more info.

The issue is with connecting to an AWS RDS Postgres database within that image
using the `sslmode=verify-full` (or `verify-ca`, or `require`) method.
[See ankane.org post][ANKANE]  for more info on how sslmodes work.


## How can I see the problem?

Run the `check.sh` script from here like this:
```bash
bash ./check.sh postgres://user:pass@my-aws-rds-host:port/dbname
```

where that dsn connection string points to your AWS RDS database.

## How does the script work?

The script is fairly simple.
It creates two images based on `python:2-stretch` and `python:2-buster` images.
Both of them have `psycopg2` (Python driver for PG) and `psql` (CLI for PG) installed.
After setting the images, the script runs two commands from each image.
First one tries to connect to the given database from Python via the `psycopg2` library
and the second one tries to run a simple `select 1` statement via `psql` client.

The connection string provided to the script is adjusted with two options:
* `sslmode` (which is set to `verify-full`) and
* `sslrootcert` (set to `rds-combined-ca-bundle.pem` -
downloaded from https://s3.amazonaws.com/rds-downloads/rds-combined-ca-bundle.pem).

to provide a safe connection to the database.

## What's the problem?

On my machine the output of the script is:
```
building images:
ssl_issue_python_2_stretch based on python:2-stretch image...
Sending build context to Docker daemon    126kB
...
Successfully built 8033f6d26d45
Successfully tagged ssl_issue_python_2_stretch:latest
ssl_issue_python_2_buster based on python:2-buster image...
...
Successfully built 6bf2635c3dee
Successfully tagged ssl_issue_python_2_buster:latest
checking psycopg2 connection on stretch...
<connection object at 0x7fcf21dc6a50; dsn: 'sslrootcert=rds-combined-ca-bundle.pem host=**** user=postgres sslmode=verify-full password=xxx dbname=****', closed: 0>
checking psycopg2 connection on buster...
Traceback (most recent call last):
  File "<string>", line 1, in <module>
  File "/usr/local/lib/python2.7/site-packages/psycopg2/__init__.py", line 126, in connect
    conn = _connect(dsn, connection_factory=connection_factory, **kwasync)
psycopg2.OperationalError: SSL error: certificate verify failed

checking psql on stretch...
 ?column?
----------
        1
(1 row)

checking psql on buster...
psql: SSL error: certificate verify failed

FIN. Now you may want to clean up the images, with:

      docker image rm ssl_issue_python_2_stretch ssl_issue_python_2_buster
```

As you can see the "buster-based" commands fail to verify the certificate
while trying to connect to the database.

## Relevant changes in Debian buster

It seems like there was a change in default openssl options on Debian buster.
[See this Debian changelog entry][DEBIAN CHANGELOG] for more info.
The workaround of changing back the default values to the previous ones,
i.e. changing `/etc/ssl/openssl.cnf` file to have:
```
MinProtocol = None
CipherString = DEFAULT
```
does seem to mitigate the issue.
Although I'm not sure if this is the right way of fixing the problem.

[ANKANE]: https://ankane.org/postgres-sslmode-explained
[DOCKER CHANGE]: https://github.com/docker-library/python/pull/405
[DEBIAN CHANGELOG]: https://www.debian.org/releases/stable/i386/release-notes/ch-information.en.html#openssl-defaults
