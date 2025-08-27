# Comandos para lanzar un EC2

## Resumen

A continuación, se presentan un listado de comandos que le permitirá crear un EC2 desde la configuración del VPC hasta el lanzamiento del EC2

### Crear VPC

```bash
aws ec2 create-vpc \
    --cidr-block "10.0.0.0/16" \
    --region "region-1" \
    --query 'Vpc.VpcId' \
    --output text \
    --tag-specifications '{"ResourceType":"vpc","Tags":[{"Key":"Name","Value":"vpc"}]}'
```

### Crear subredes

```bash
aws ec2 create-subnet \
    --vpc-id "vpc-xxxxxxxxxxx" \
    --cidr-block "10.0.1.0/24" \
    --availability-zone "region-1a" \
    --query 'Subnet.SubnetId' \
    --output text \
    --tag-specifications '{"ResourceType":"subnet","Tags":[{"Key":"Name","Value":"subnet-1"}]}'
```

### Gateway de internet

```bash
aws ec2 create-internet-gateway \
    --region "region-1" \
    --query 'InternetGateway.InternetGatewayId' \
    --output text \
    --tag-specifications '{"ResourceType":"internet-gateway","Tags":[{"Key":"Name","Value":"igw"}]}'
```

### Asociar el gateway de internet a la VPC

```bash
aws ec2 attach-internet-gateway \
    --internet-gateway-id "" \
    --vpc-id "vpc-xxxxxxxxxxx" \
    --region "region-1"
```

### Crear una tabla de rutas

```bash
aws ec2 create-route-table \
    --vpc-id "vpc-xxxxxxxxxxx" \
    --region "region-1" \
    --query 'RouteTable.RouteTableId' \
    --output text
```

### Crear una ruta

```bash
aws ec2 create-route \
    --route-table-id "" \
    --destination-cidr-block "0.0.0.0/0" \
    --gateway-id "" \
    --region "region-1"
```

### Asociar tabla de rutas a la subred

```bash
aws ec2 associate-route-table \
    --subnet-id "" \
    --route-table-id "" \
    --region "region-1"
```

### Habilita asignación automática de IP pública en la subred (para que la EC2 tenga IP pública)

```bash
aws ec2 modify-subnet-attribute \
    --subnet-id $SUBNET_ID \
    --map-public-ip-on-launch \
    --region "region-1"
```

### Crear un grupo de seguridad

```bash
aws ec2 create-security-group \
    --group-name "sg-private" \
    --description "Security group for private cloud" \
    --vpc-id "vpc-xxxxxxxxxxx" 
```

### Crear reglas de ingreso

```bash
aws ec2 authorize-security-group-ingress \
    --group-id "" \
    --ip-permissions '{"IpProtocol":"tcp","FromPort":22,"ToPort":22,"IpRanges":[{"CidrIp":"xxx.xxx.xxx.xxx/yy","Description":"SSH"}]}'\ 
        '{"IpProtocol":"tcp","FromPort":80,"ToPort":80,"IpRanges":[{"CidrIp":"xxx.xxx.xxx.xxx/yy","Description":"HTTP"}]}'\ 
```

**Nota:** Reemplace `xxx.xxx.xxx.xxx/yy` por su IP pública. 

### Lanzar instancias

```bash
aws ec2 run-instances \
    --image-id "ami-xxxxxxxxxxxxxxxxxxxx" \
    --instance-type "m5.xlarge" \
    --key-name "key-pair-ed" \
    --block-device-mappings '{"DeviceName":"/dev/sda1","Ebs":{"Encrypted":false,"DeleteOnTermination":true,"Iops":3000,"VolumeSize":500,"VolumeType":"gp3","Throughput":125}}'\
    --network-interfaces '{"SubnetId":"subnet-xxxxxxxxxxxxxxxxxxx","AssociatePublicIpAddress":true,"DeviceIndex":0,"Groups":["sg-xxxxxxxxxxxxx"]}' \
    --tag-specifications '{"ResourceType":"instance","Tags":[{"Key":"Name","Value":"Mi-maquina"}]}' \
    --private-dns-name-options '{"HostnameType":"ip-name","EnableResourceNameDnsARecord":false,"EnableResourceNameDnsAAAARecord":false}' \
    --count "x"
```

**Nota:** El argumento `--count "x"` indica la cantidad de maquinas que quiere lanzar con la misma configuración