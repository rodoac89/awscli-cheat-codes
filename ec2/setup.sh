#!/bin/bash

# Variables (ajusta si es necesario)
REGION=""  # Tu región AWS
VPC_CIDR="10.0.0.0/16"
SUBNET_CIDR="10.0.1.0/24"
AVAILABILITY_ZONE="${REGION}a"
KEY_NAME=""  # Nombre de tu clave SSH
AMI_ID="ami-xxxxxxxxxxxxx"  # Reemplaza con un AMI válido
INSTANCE_TYPE="m5.xlarge"

# Paso 1: Crea la VPC
VPC_ID=$(aws ec2 create-vpc --cidr-block $VPC_CIDR --region $REGION --query "Vpc.VpcId" --output text --tag-specifications '{"ResourceType":"vpc","Tags":[{"Key":"Name","Value":"rodo-vpc"}]}')
echo "VPC creada: $VPC_ID"

# Paso 2: Crea la subred pública
SUBNET_ID=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block $SUBNET_CIDR --availability-zone $AVAILABILITY_ZONE --region $REGION --query "Subnet.SubnetId" --output text --tag-specifications '{"ResourceType":"subnet","Tags":[{"Key":"Name","Value":"rodo-subnet-1"}]}')
echo "Subred creada: $SUBNET_ID"

# Paso 3: Crea el Internet Gateway y adjúntalo a la VPC
IGW_ID=$(aws ec2 create-internet-gateway --region $REGION --query "InternetGateway.InternetGatewayId" --output text --tag-specifications '{"ResourceType":"internet-gateway","Tags":[{"Key":"Name","Value":"rodo-igw"}]}')
aws ec2 attach-internet-gateway --vpc-id $VPC_ID --internet-gateway-id $IGW_ID --region $REGION
echo "Internet Gateway creado y adjuntado: $IGW_ID"

# Paso 4: Crea la tabla de rutas y agrega ruta a IGW
ROUTE_TABLE_ID=$(aws ec2 create-route-table --vpc-id $VPC_ID --region $REGION --query "RouteTable.RouteTableId" --output text)
aws ec2 create-route --route-table-id $ROUTE_TABLE_ID --destination-cidr-block 0.0.0.0/0 --gateway-id $IGW_ID --region $REGION
echo "Tabla de rutas creada: $ROUTE_TABLE_ID"

# Paso 5: Asocia la tabla de rutas a la subred
aws ec2 associate-route-table --subnet-id $SUBNET_ID --route-table-id $ROUTE_TABLE_ID --region $REGION
echo "Tabla de rutas asociada a la subred"

# Paso 6: Habilita asignación automática de IP pública en la subred (para que la EC2 tenga IP pública)
aws ec2 modify-subnet-attribute --subnet-id $SUBNET_ID --map-public-ip-on-launch --region $REGION
echo "IP pública automática habilitada en la subred"

# Paso 7: Crea el grupo de seguridad en la VPC
SG_ID=$(aws ec2 create-security-group --group-name "rodo-sg-private" --description "Grupo para SSH y servicios" --vpc-id $VPC_ID --region $REGION --query "GroupId" --output text)
echo "Grupo de seguridad creado: $SG_ID"

# Paso 8: Agrega las reglas de ingress (corrigiendo tu comando: debe ser un array JSON único)
aws ec2 authorize-security-group-ingress \
    --group-id $SG_ID \
    --ip-permissions '[
        {"IpProtocol":"tcp","FromPort":22,"ToPort":22,"IpRanges":[{"CidrIp":"0.0.0.0/0","Description":"SSH"}]},
        {"IpProtocol":"tcp","FromPort":7180,"ToPort":7180,"IpRanges":[{"CidrIp":"0.0.0.0/0","Description":"Cloudera Manager UI"}]},
        {"IpProtocol":"tcp","FromPort":7183,"ToPort":7183,"IpRanges":[{"CidrIp":"0.0.0.0/0","Description":"Cloudera Manager UI HTTPS"}]},
        {"IpProtocol":"tcp","FromPort":88,"ToPort":88,"IpRanges":[{"CidrIp":"0.0.0.0/0","Description":"Kerberos KDC TCP"}]},
        {"IpProtocol":"udp","FromPort":88,"ToPort":88,"IpRanges":[{"CidrIp":"0.0.0.0/0","Description":"Kerberos KDC UDP"}]},
        {"IpProtocol":"tcp","FromPort":389,"ToPort":389,"IpRanges":[{"CidrIp":"0.0.0.0/0","Description":"LDAP"}]},
        {"IpProtocol":"tcp","FromPort":636,"ToPort":636,"IpRanges":[{"CidrIp":"0.0.0.0/0","Description":"LDAPS"}]}
    ]' \
    --region $REGION
echo "Reglas de ingress agregadas"

# Opcional: Agrega regla de egress (salida) para todo el tráfico (por default ya permite, pero para confirmar)
aws ec2 authorize-security-group-egress \
    --group-id $SG_ID \
    --ip-permissions '[{"IpProtocol":"-1","IpRanges":[{"CidrIp":"0.0.0.0/0"}]}]' \
    --region $REGION
echo "Regla de egress agregada (todo el tráfico saliente)"

# Paso 9: Crea una clave SSH si no existe (descárgala y chmod 400 MyKeyPair.pem)
if ! aws ec2 describe-key-pairs --key-names $KEY_NAME --region $REGION > /dev/null 2>&1; then
    aws ec2 create-key-pair --key-name $KEY_NAME --query "KeyMaterial" --output text > $KEY_NAME.pem
    chmod 400 $KEY_NAME.pem
    echo "Clave SSH creada: $KEY_NAME.pem"
else
    echo "Clave SSH ya existe: $KEY_NAME"
fi

# Paso 10: Lanza la instancia EC2
INSTANCE_ID=$(aws ec2 run-instances \
    --image-id $AMI_ID \
    --instance-type $INSTANCE_TYPE \
    --subnet-id $SUBNET_ID \
    --security-group-ids $SG_ID \
    --key-name $KEY_NAME \
    --associate-public-ip-address \
    --region $REGION \
    --query "Instances[0].InstanceId" --output text)
echo "Instancia EC2 lanzada: $INSTANCE_ID"

# Espera a que la instancia esté running y obtén la IP pública
aws ec2 wait instance-running --instance-ids $INSTANCE_ID --region $REGION
PUBLIC_IP=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID --region $REGION --query "Reservations[0].Instances[0].PublicIpAddress" --output text)
echo "IP pública de la instancia: $PUBLIC_IP"
echo "Conéctate con: ssh -i \"$KEY_NAME.pem\" ec2-user@$PUBLIC_IP"