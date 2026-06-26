import pytest
from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_healthz():
    response = client.get("/healthz")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


def test_version_default():
    response = client.get("/version")
    assert response.status_code == 200
    assert response.json()["version"] == "0.0.0"


def test_version_env(monkeypatch):
    monkeypatch.setenv("APP_VERSION", "1.2.3")
    response = client.get("/version")
    assert response.status_code == 200
    assert response.json()["version"] == "1.2.3"
