# Python FastMCP Demo Server Deployment

A guide to deploy mcp server on different clouds using terraform. current implementation deploy the mcp server of AWS using terraform and deployment using docker compose. 

---

## Requirements

- Docker
- Terraform

---

## Docker

Build image:

```bash
docker build -t mcp-demo .
```

Run container:

```bash
docker-compose up -f deployments/composer/docker-compose.yml
```

---

## K8s Deployment
If you are using kubernetes cluster on local like me on docker desktop. You need to configure 
`kubectl config get-contexts && kubectl config use-context docker-desktop`

Create deployment
```bash
kubectl apply -f deployments/k8s/deployment.yaml 
```
Create Service
```bash
kubectl apply -f deployments/k8s/service.yaml 
```
Create Horizontal Pod Autoscaler
```bash
kubectl apply -f deployments/k8s/hpa.yaml 
```
Create Pod Disruption Budget
```bash
kubectl apply -f deployments/k8s/pdb.yaml 
```

## AWS Deployment

```bash
cd deployments/terraform/aws/
```

```bash
terraform plan
```

```bash
terraform apply
```

--- 

## Future Enhancements

- Add k8s scripts
- Add script to deploy on other clouds 

---

## License

[MIT License](LICENSE)
