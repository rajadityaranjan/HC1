provider aws {
  region = "ap-south-1"
  profile = "default"
}

##Creating a valid key-pair##
resource "aws_key_pair" "productn_key" {
  key_name = "tk2"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAABJQAAAgEAi1s72hPHIW+DuRUZK9Ymj7NjsEZUVnxWJVQ2QjmNosG2SeZkCbNYE+m46kj3L0AVnHCxixjjExV3JvzYvafAmy0FVbtg5ce0l5PV9bdq/ztrH8snR634j/Xu2bhXQ1H4Hyz2YBEQU6lj4dbAjkJT51nAGOg8sTxIXZYEhbBRbAanILlAQ2FBLGEBcNWDcHfJUs85pX9REM9Xd1yIEZTl0KN12932w5tyhbqJAiaPUl0HZ0GpUxYJeAUfDlWRYHK8gU3OCQCZwgk+QAMwOm9Zglzgx533BTJTZ0ItFSuloKfV4J84eAlWeSBbOgr/jRUnRzZhn3CPUcUfRwnQ70vK21buzW3Nhb2hhdq7B2SeSyFTl88zlrjg18suFeH4QLhpp5ys9c/qtqjnCdTpO9p+BAYN1alSsPlqWoXlxpk7Zeu1TijdM0FCKYQcVr6QEvPW+TBHXStRiQmRwvATFdxftCqxSjq8IWfVA/1FmRd7JkAUaI7FI3v1Ag/M9IvyDdlbK42mm9vDT0eDe1dtigCt4+cbvnYum+A48WhZ579ZwQZNKzNqnAP3D+sJ+GE5RZIM7f3zw8CkWVNWiiR7a2y4aaQDxGgVMEgfOg4m+EB7qoCOhUhiQyzZQpALeEpISDov1Eizo17q+3rS7a8yD6OiosZZKxjigL/kkJ7zJY1P5Is= rsa-key-20200612"
}
##Getting the output for the key created##
output "opkey" {
  value = aws_key_pair.productn_key 
}

##creating the security groups##
resource "aws_security_group" "security_group1" {
  name        = "allow_tls"
  description = "Allow TCP and SSH inbound traffic"
  vpc_id      = "vpc-fb0d1193"

 ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

 ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

 ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

 egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "sg123"
  }
}

output "op_sg" {
  value = aws_security_group.security_group1
}

##setting variable for the key##
variable "insert_key_var" {
     type = string
//   default = "tk2"
}

##launching the instance##
resource "aws_instance" "inst1" {
  ami = "ami-08f12e0082bdc6479"
  instance_type = "t2.micro"
  key_name = var.insert_key_var
  security_groups = [ "allow_tls" ]
  tags = {
    Name = "server1"
  }
}

##outputs of the instances##
output "op_inst_ip" {
  value = aws_instance.inst1.public_ip
}

output "op_inst_az" {
  value = aws_instance.inst1.availability_zone
}

##creating the EBS volumes##
resource "aws_ebs_volume" "ebs_volume" {
  availability_zone = aws_instance.inst1.availability_zone
  size = 1 
  
  tags = {
    Name = "tvol1"
  }
}

##checking the op of the ebs volume for the volume id##
output "ebs_volume" {
  value = aws_ebs_volume.ebs_volume
}

##attaching the ebs volume to the running instance##
resource "aws_volume_attachment" "disc_attach" {
  device_name = "/dev/sdf"
  volume_id = aws_ebs_volume.ebs_volume.id
  instance_id = aws_instance.inst1.id
}

####CREATING THE BUCKET FOR THE ABOVE INSTANCE TO STORE THE DATA####

resource "aws_s3_bucket" "bucket" {
  bucket = "tk1-bucket826"
  acl    = "public-read"

  tags = {
    Name        = "Mybucket7858789"
  }
}

output "ops3" {
  value = aws_s3_bucket.bucket
}

locals {
  s3_origin_id = "S3-Mybucket7858789"
}

resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name = "${aws_s3_bucket.bucket.bucket_regional_domain_name}"
    origin_id   = "${local.s3_origin_id}"
  }
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "Some-comment"
  
  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "${local.s3_origin_id}"
    forwarded_values {
    query_string = false

      cookies {
        forward = "none"
      }
    }
    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  # Cache behavior with precedence 0
  ordered_cache_behavior {
    path_pattern     = "/content/immutable/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = "${local.s3_origin_id}"

    forwarded_values {
      query_string = false
      headers      = ["Origin"]

      cookies {
        forward = "none"
      }
    }

    min_ttl                = 0
    default_ttl            = 86400
    max_ttl                = 31536000
    compress               = true
    viewer_protocol_policy = "allow-all"
  }

  # Cache behavior with precedence 1
  ordered_cache_behavior {
    path_pattern     = "/content/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "${local.s3_origin_id}"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
    compress               = true
    viewer_protocol_policy = "allow-all"
  }

  price_class = "PriceClass_200"

  restrictions {
    geo_restriction {
      restriction_type = "blacklist"
      locations        = ["CN"]
    }
  }
  
  tags = {
    Environment = "production"
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

output "opcdn" {
  value = aws_cloudfront_distribution.s3_distribution
}
