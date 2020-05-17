To create TLS secret: 
kubectl create secret tls websecret --key=/Users/sonaikar/Documents/Devops/vagrantJenkins/private.key   --cert=/Users/sonaikar/Documents/Devops/vagrantJenkins/certificate.crt


To create generic secret: 
kubectl create secret generic mysecret --from-file=./username.txt --from-file=./password.txt
