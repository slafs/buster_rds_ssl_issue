ARG python_tag
FROM python:$python_tag

RUN pip install psycopg2
RUN apt-get update && apt-get install -y postgresql-client

COPY ./rds-combined-ca-bundle.pem /test/

WORKDIR /test
