resource "aws_instance" "web" {
  ami           = "ami-006dcf34c09e50022"
  instance_type = "t3.micro"
  vpc_security_group_ids = [
    "sg-0a2b6d85e4c64d7fa"
  ]
    tags = {
      "Name" = "Moniteringinstance"

    }
    provisioner "file" {
    source      = "/root/project/nginx"
    destination = "/tmp/nginx.sh"
  }
    provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/nginx.sh"
      "sudo /root/project/nginx.sh"
    ]
  }
connection {
    type        = "ssh"
    host        = self.public_ip
    user        = "ubuntu"
    private_key = "/local/privatekey"
  }
}