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
