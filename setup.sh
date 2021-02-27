#!/bin/bash
yum update -y
yum install python3.7 -y
yum install java-1.8.0-openjdk-devel -y
yum install nmap-ncat -y
yum install git -y
yum erase awscli -y
yum install jq -y
yum install maven -y
mvn -version
amazon-linux-extras install docker -y
service docker start
usermod -a -G docker ec2-user

cd /home/ec2-user
wget https://bootstrap.pypa.io/get-pip.py
su -c "python3.7 get-pip.py --user" -s /bin/sh ec2-user
su -c "/home/ec2-user/.local/bin/pip3 install boto3 --user" -s /bin/sh ec2-user
su -c "/home/ec2-user/.local/bin/pip3 install awscli --user" -s /bin/sh ec2-user
su -c "/home/ec2-user/.local/bin/pip3 install kafka-python --user" -s /bin/sh ec2-user

# install AWS CLI 2 - access with aws2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install -b /usr/local/bin/aws2
su -c "ln -s /usr/local/bin/aws2/aws ~/.local/bin/aws2" -s /bin/sh ec2-user

# Create dirs, get Apache Kafka 2.3.1, 2.4.1 and unpack it
su -c "mkdir -p kafka231 kafka241 confluent" -s /bin/sh ec2-user
cd kafka231
su -c "wget https://archive.apache.org/dist/kafka/2.3.1/kafka_2.12-2.3.1.tgz" -s /bin/sh ec2-user
su -c "tar -xzf kafka_2.12-2.3.1.tgz --strip 1" -s /bin/sh ec2-user

cd /home/ec2-user
ln -s /home/ec2-user/kafka241 /home/ec2-user/kafka
cd kafka241
su -c "wget http://archive.apache.org/dist/kafka/2.4.1/kafka_2.12-2.4.1.tgz" -s /bin/sh ec2-user
su -c "tar -xzf kafka_2.12-2.4.1.tgz --strip 1" -s /bin/sh ec2-user

# Get Confluent Community and unpack it
cd /home/ec2-user
cd confluent
su -c "wget http://packages.confluent.io/archive/5.4/confluent-community-5.4.1-2.12.tar.gz" -s /bin/sh ec2-user
su -c "tar -xzf confluent-community-5.4.1-2.12.tar.gz --strip 1" -s /bin/sh ec2-user

# Initialize the Kafka cert trust store
su -c 'find /usr/lib/jvm/ -name "cacerts" -exec cp {} /tmp/kafka.client.truststore.jks \;' -s /bin/sh ec2-user

cd /tmp
su -c "mkdir -p kafka" -s /bin/sh ec2-user
su -c "aws s3 cp s3://reinvent2019-msk-liftandshift/producer.properties_msk /tmp/kafka" -l ec2-user
su -c "aws s3 cp s3://reinvent2019-msk-liftandshift/consumer.properties /tmp/kafka" -l ec2-user
su -c "aws s3 cp s3://reinvent2019-msk-liftandshift/schema-registry.properties /tmp/kafka" -l ec2-user
su -c "aws s3 cp s3://reinvent2019-msk-liftandshift/setup-env-sasl.py /tmp/kafka" -l ec2-user
su -c "aws s3 cp s3://reinvent2019-msk-liftandshift/connect-distributed_no_security.properties /tmp/kafka" -l ec2-user
su -c "git -C /tmp/kafka clone https://github.com/aws-samples/sasl-scram-secrets-manager-client-for-msk.git" -l ec2-user
su -c "cd /tmp/kafka/sasl-scram-secrets-manager-client-for-msk/ && mvn clean install -f pom.xml && cp target/SaslScramSecretsManagerClient-1.0-SNAPSHOT.jar /tmp/kafka" -l ec2-user
su -c "cd /tmp/kafka && rm -rf sasl-scram-secrets-manager-client-for-msk" -l ec2-user
su -c "git -C /tmp/kafka clone https://github.com/aws-samples/clickstream-producer-for-apache-kafka.git" -l ec2-user
su -c "cd /tmp/kafka/clickstream-producer-for-apache-kafka/ && mvn clean package -f pom.xml && cp target/KafkaClickstreamClient-1.0-SNAPSHOT.jar /tmp/kafka" -l ec2-user
su -c "cd /tmp/kafka && rm -rf clickstream-producer-for-apache-kafka" -l ec2-user

# Setup unit in systemd for Schema Registry
echo -n "
[Unit]
Description=Confluent Schema Registry
After=network.target

[Service]
Type=simple
User=ec2-user
ExecStart=/bin/sh -c '/home/ec2-user/confluent/bin/schema-registry-start /tmp/kafka/schema-registry.properties > /tmp/kafka/schema-registry.log 2>&1'
ExecStop=/home/ec2-user/confluent/bin/schema-registry-stop
Restart=on-abnormal

[Install]
WantedBy=multi-user.target" > /etc/systemd/system/confluent-schema-registry.service

#setup bash env
su -c "echo 'export PS1=\"KafkaClientEC2Instance [\u@\h \W\\]$ \"' >> /home/ec2-user/.bash_profile" -s /bin/sh ec2-user
su -c "echo '[ -f /tmp/kafka/setup_env ] && . /tmp/kafka/setup_env' >> /home/ec2-user/.bash_profile" -s /bin/sh ec2-user

#setup aws Region
su -c "mkdir -p /home/ec2-user/.aws" -s /bin/sh ec2-user
su -c "cat > /home/ec2-user/.aws/config<<EOF
[default]
region = us-east-1
EOF" -s /bin/sh ec2-user

