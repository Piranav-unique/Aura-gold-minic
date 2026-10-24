from fastapi import APIRouter, HTTPException, status

from app.core.config import settings
from app.schemas.app_release import AndroidAppReleaseResponse

router = APIRouter()


@router.get(
    "/android-release",
    response_model=AndroidAppReleaseResponse,
    status_code=status.HTTP_200_OK,
)
async def get_android_release() -> AndroidAppReleaseResponse:
    """Public endpoint used by the mobile app to check for updates.

    Play builds only need APP_ANDROID_VERSION_CODE; the app opens the Play Store
    listing. APP_ANDROID_APK_URL is kept for older sideloaded builds.
    """
    if settings.APP_ANDROID_VERSION_CODE <= 0 and not settings.APP_ANDROID_APK_URL.strip():
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Android release is not configured.",
        )

    return AndroidAppReleaseResponse(
        version_name=settings.APP_ANDROID_VERSION_NAME.strip() or "0.0.0",
        version_code=settings.APP_ANDROID_VERSION_CODE,
        apk_url=settings.APP_ANDROID_APK_URL.strip(),
        release_notes=settings.APP_ANDROID_RELEASE_NOTES.strip(),
        force_update=settings.APP_ANDROID_FORCE_UPDATE,
    )
