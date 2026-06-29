# syntax=docker/dockerfile:1

# ---- builder ----
FROM python:3.12-slim@sha256:86d3e4424d5e963e60594a3a6b4d597cc4d41f5152fe67a97a40dca9ea092475 AS builder

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

WORKDIR /app

# Build the dependency venv in an isolated stage so build tools never reach runtime.
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

COPY app/requirements.txt ./requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

# ---- runtime ----
FROM python:3.12-slim@sha256:86d3e4424d5e963e60594a3a6b4d597cc4d41f5152fe67a97a40dca9ea092475 AS runtime

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    APP_VERSION=0.0.0 \
    PATH="/opt/venv/bin:$PATH"

# Non-root uid/gid.
RUN groupadd --gid 10001 app && \
    useradd --uid 10001 --gid 10001 --no-create-home --shell /usr/sbin/nologin app

WORKDIR /app

# Copy only the prebuilt venv and the application source — no build tools.
COPY --from=builder /opt/venv /opt/venv
COPY app/ ./app/

USER 10001:10001

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD ["python", "-c", "import urllib.request,sys; sys.exit(0) if urllib.request.urlopen('http://127.0.0.1:8000/healthz').status==200 else sys.exit(1)"]

ENTRYPOINT ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
