#!/bin/bash
#For your reference, you can find the AMI ID and Hosted Zone ID in your AWS account. Replace <AMI-ID> and <ROUTE-53-HOSTED-ZONE-ID> with the actual values before running the script.
#ami_id="ami-0055977a6e828a4f4"
#instance_type="t3.micro"
#domain_name="saikiranaws.store"
#hosted_zone_id="Z05137096J70EBGPV01Y"

ami_id="<AMI-ID>"       #Replace with your actual AMI ID
instance_type="t3.micro"
domain_name="example.com" #Replace with your actual domain name
hosted_zone_id="<ROUTE-53-HOSTED-ZONE-ID>" #Replace with your actual Route 53 Hosted Zone ID



for instance in $@
do
    echo "Creating instance: $instance"

    instance_id=$(aws ec2 run-instances \
            --image-id $ami_id \
            --instance-type $instance_type \
            --security-groups "roboshop-common" "roboshop-$instance" \
            --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=roboshop-$instance}]" \
            --query 'Instances[0].InstanceId' \
            --output text
    )

    echo "$instance instance ID: $instance_id"

    if [ $instance != "frontend" ]; then
        IP=$( aws ec2 describe-instances --instance-ids $instance_id \
             --query 'Reservations[].Instances[].PrivateIpAddress' --output text
        )
        r53_record="${instance}.${domain_name}"
    else
        IP=$( aws ec2 describe-instances --instance-ids $instance_id \
             --query 'Reservations[].Instances[].PublicIpAddress' --output text
        )
        r53_record="${instance}.${domain_name}"
    fi

    # update R53 record
    echo "Record: ${r53_record}"
    aws route53 change-resource-record-sets \
    --hosted-zone-id $hosted_zone_id \
    --change-batch '{
        "Changes": [
            {
                "Action": "UPSERT",
                "ResourceRecordSet": {
                    "Name": "'$r53_record'",
                    "Type": "A",
                    "TTL": 1,
                    "ResourceRecords": [{"Value": "'$IP'"}]
                }
            }
        ]
    }'

    echo "Updated R53 record for $instance"
done