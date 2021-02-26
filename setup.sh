#!/bin/bash
yum update -y
yum install java-1.8.0 python3 -y

mkdir -p /home/kafka && cd /home/kafka
wget https://archive.apache.org/dist/kafka/2.7.0/kafka_2.12-2.7.0.tgz
tar -xzf kafka_2.12-2.7.0.tgz --strip 1 && rm kafka_2.12-2.7.0.tgz

find /usr/lib/jvm/ -name "cacerts" | xargs -I '{}' cp '{}' /tmp/kafka.client.truststore.jks
touch bin/client.properties
echo "security.protocol=SSL" >> bin/client.properties
echo "ssl.truststore.location=/tmp/kafka.client.truststore.jks" >> bin/client.properties
