FROM python:3.14-alpine AS builder
WORKDIR /install
RUN apk add uv
RUN --mount=type=bind,source=requirements.txt,target=/tmp/requirements.txt \
    uv pip install --system --trusted-host pypi.python.org  \
    --prefix=/install -r \
    /tmp/requirements.txt

# ===========================
# Stage 2: Security Scanner
# ===========================
FROM aquasec/trivy:latest AS scanner
COPY --from=builder /install /usr/local
RUN trivy fs --exit-code 1 --severity HIGH,CRITICAL /

# ===========================
# Stage 3: Runtime Environment
# ===========================
FROM python:3.14-alpine
ENV MCP_ALLOWED_HOSTS="*"
ENV MCP_ALLOWED_ORIGINS="*"
COPY --from=builder /install /usr/local

WORKDIR /app
COPY src $WORKDIR

EXPOSE 8000

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
