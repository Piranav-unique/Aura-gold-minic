from fastapi.testclient import TestClient

from app.core.config import settings
from app.main import app


def test_android_release_not_configured(monkeypatch):
    monkeypatch.setattr(settings, "APP_ANDROID_APK_URL", "")
    monkeypatch.setattr(settings, "APP_ANDROID_VERSION_CODE", 0)
    client = TestClient(app)
    response = client.get("/api/v1/app/android-release")
    assert response.status_code == 404


def test_android_release_returns_metadata(monkeypatch):
    monkeypatch.setattr(settings, "APP_ANDROID_VERSION_NAME", "0.2.0")
    monkeypatch.setattr(settings, "APP_ANDROID_VERSION_CODE", 12)
    monkeypatch.setattr(
        settings,
        "APP_ANDROID_APK_URL",
        "https://example.com/app-release.apk",
    )
    monkeypatch.setattr(
        settings,
        "APP_ANDROID_RELEASE_NOTES",
        "Bug fixes and performance improvements.",
    )
    monkeypatch.setattr(settings, "APP_ANDROID_FORCE_UPDATE", True)

    client = TestClient(app)
    response = client.get("/api/v1/app/android-release")
    assert response.status_code == 200
    payload = response.json()
    assert payload["version_name"] == "0.2.0"
    assert payload["version_code"] == 12
    assert payload["apk_url"] == "https://example.com/app-release.apk"
    assert payload["release_notes"] == "Bug fixes and performance improvements."
    assert payload["force_update"] is True


def test_android_release_for_play_builds_needs_only_version_code(monkeypatch):
    monkeypatch.setattr(settings, "APP_ANDROID_APK_URL", "")
    monkeypatch.setattr(settings, "APP_ANDROID_VERSION_NAME", "0.2.1")
    monkeypatch.setattr(settings, "APP_ANDROID_VERSION_CODE", 27)

    response = TestClient(app).get("/api/v1/app/android-release")
    assert response.status_code == 200
    assert response.json()["version_code"] == 27
    assert response.json()["apk_url"] == ""
